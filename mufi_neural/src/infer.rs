//! Inference: IntelliSense completion + error diagnostics.
//!
//! Two primary entry points:
//!   `complete`  — top-N next-token candidates at the cursor (for LSP completionItems)
//!   `diagnose`  — per-token perplexity → error/warning spans   (for LSP diagnostics)
//!
//! A third entry point `generate` does free-form autoregressive completion,
//! useful for debugging or ghost-text suggestions.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use candle_core::{DType, Device, Tensor, D};
use candle_nn::VarBuilder;
use serde::Serialize;

use crate::data::MufiTokenizer;
use crate::model::{Config, MufiLM};

// ------------------------------------------------------------------ //
// Shared model handle
// ------------------------------------------------------------------ //

pub struct LoadedModel {
    pub model: MufiLM,
    pub tok: MufiTokenizer,
    pub device: Device,
    pub cfg: Config,
}

impl LoadedModel {
    pub fn load(tokenizer: &Path, checkpoint: &Path, cpu: bool) -> Result<Self> {
        let device = pick_device(cpu)?;
        let tok = MufiTokenizer::from_file(tokenizer)?;
        let cfg = Config::small(tok.vocab_size);

        let weights = candle_core::safetensors::load(checkpoint, &device)
            .with_context(|| format!("Cannot load checkpoint: {}", checkpoint.display()))?;
        let vb = VarBuilder::from_tensors(weights, DType::F32, &device);
        let model = MufiLM::new(&cfg, vb)?;

        Ok(Self { model, tok, device, cfg })
    }

    /// Run a forward pass on `ids` and return logits for the final position.
    /// Shape: (vocab_size,)
    fn last_logits(&self, ids: &[u32]) -> Result<Tensor> {
        let t = ids.len().min(self.cfg.max_seq_len);
        let ctx = &ids[ids.len() - t..];
        let input = Tensor::from_slice(ctx, (1, t), &self.device)?;
        let logits = self.model.forward(&input)?; // (1, t, vocab)
        Ok(logits.squeeze(0)?.get(t - 1)?) // (vocab,)
    }
}

// ------------------------------------------------------------------ //
// Completion  (IntelliSense)
// ------------------------------------------------------------------ //

#[derive(Debug, Serialize)]
pub struct CompletionItem {
    /// Decoded text of the candidate token
    pub text: String,
    /// Softmax probability [0, 1] — higher is more confident
    pub score: f32,
    /// Raw token id
    pub token_id: u32,
}

/// Given source code up to the cursor, return the top-N most likely
/// next tokens with their probabilities.
///
/// Output is sorted descending by score.
pub fn complete(m: &LoadedModel, source_before_cursor: &str, top_n: usize) -> Result<Vec<CompletionItem>> {
    // Encode: <sos> + prompt tokens
    let mut ids = vec![m.tok.sos_id];
    ids.extend(m.tok.encode(source_before_cursor)?);

    let logits = m.last_logits(&ids)?; // (vocab,)

    // Softmax probabilities
    let probs: Vec<f32> = candle_nn::ops::softmax(
        &logits.to_device(&Device::Cpu)?.unsqueeze(0)?,
        D::Minus1,
    )?
    .squeeze(0)?
    .to_vec1()?;

    // Sort by probability descending, take top-N
    let mut indexed: Vec<(u32, f32)> = probs
        .iter()
        .copied()
        .enumerate()
        .map(|(i, p)| (i as u32, p))
        .collect();
    indexed.sort_unstable_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    let items = indexed
        .into_iter()
        .take(top_n)
        // Skip special tokens in completions
        .filter(|(id, _)| {
            *id != m.tok.pad_id && *id != m.tok.sos_id && *id != m.tok.eos_id
        })
        .take(top_n)
        .filter_map(|(id, score)| {
            m.tok.id_to_token(id).map(|text| CompletionItem {
                text: clean_token(&text),
                score,
                token_id: id,
            })
        })
        .collect();

    Ok(items)
}

// ------------------------------------------------------------------ //
// Diagnostics  (error prediction)
// ------------------------------------------------------------------ //

#[derive(Debug, Serialize)]
pub struct DiagnosticItem {
    /// Byte offset of the surprising token (start, inclusive)
    pub start_byte: usize,
    /// Byte offset (end, exclusive)
    pub end_byte: usize,
    /// The token text the model found surprising
    pub token: String,
    /// Per-token perplexity (e^cross_entropy).  Higher = more surprising.
    pub perplexity: f32,
    /// "warning" | "error"
    pub severity: &'static str,
    pub message: String,
}

// MufiZ structural token set: the model has strong priors on these.
// Pure identifiers are excluded — they are inherently unpredictable.
const STRUCTURAL_TOKENS: &[&str] = &[
    "var", "fun", "if", "else", "while", "for", "foreach", "return",
    "print", "println", "true", "false", "nil", "in", "and", "or", "not",
    "import", "break", "continue",
    "(", ")", "{", "}", "[", "]", ";", ",", ".",
    "=", "==", "!=", "<", ">", "<=", ">=",
    "+", "-", "*", "/", "%",
    "->",
];

fn is_structural(token: &str) -> bool {
    let t = token.trim_matches(|c: char| c == 'Ġ' || c == 'Ċ' || c == '▁' || c == ' ');
    STRUCTURAL_TOKENS.contains(&t)
}

/// Given a full source snippet, compute per-token perplexity and return
/// structural tokens that are statistical outliers (>2σ above the mean
/// of *structural* token perplexities in this file).
///
/// Using relative/adaptive thresholds avoids false positives from
/// user-defined identifiers that are inherently unpredictable.
pub fn diagnose(m: &LoadedModel, source: &str) -> Result<Vec<DiagnosticItem>> {
    let (token_ids, offsets) = m.tok.encode_with_offsets(source)?;
    if token_ids.is_empty() {
        return Ok(vec![]);
    }

    // Teacher-forcing: prepend <sos>
    let mut full_ids: Vec<u32> = vec![m.tok.sos_id];
    full_ids.extend(&token_ids);

    let max_ctx = m.cfg.max_seq_len;
    let full_ids = if full_ids.len() > max_ctx {
        &full_ids[..max_ctx]
    } else {
        &full_ids[..]
    };

    let t = full_ids.len();
    let input = Tensor::from_slice(full_ids, (1, t), &m.device)?;
    let logits = m.model.forward(&input)?.squeeze(0)?; // (t, vocab)

    // --- Collect per-structural-token neg-log-prob ---
    struct TokenRecord {
        start_byte: usize,
        end_byte: usize,
        token_text: String,
        neg_log_p: f32,
    }

    let mut records: Vec<TokenRecord> = Vec::new();

    for (i, (&actual_id, &(start_byte, end_byte))) in
        token_ids.iter().zip(offsets.iter()).enumerate()
    {
        let pred_pos = i;
        if pred_pos >= t - 1 {
            break;
        }

        let raw_text = m.tok.id_to_token(actual_id).unwrap_or_default();
        if !is_structural(&raw_text) {
            continue; // skip identifiers / literals — too noisy
        }

        let pos_logits = logits.get(pred_pos)?;
        let log_probs: Vec<f32> =
            candle_nn::ops::log_softmax(
                &pos_logits.to_device(&Device::Cpu)?.unsqueeze(0)?,
                D::Minus1,
            )?
            .squeeze(0)?
            .to_vec1()?;

        let neg_log_p = -log_probs
            .get(actual_id as usize)
            .copied()
            .unwrap_or(f32::INFINITY);

        records.push(TokenRecord {
            start_byte,
            end_byte,
            token_text: clean_token(&raw_text),
            neg_log_p,
        });
    }

    if records.is_empty() {
        return Ok(vec![]);
    }

    // --- Adaptive threshold: mean + k*stddev of neg-log-probs ---
    let n = records.len() as f32;
    let mean = records.iter().map(|r| r.neg_log_p).sum::<f32>() / n;
    let variance = records.iter().map(|r| (r.neg_log_p - mean).powi(2)).sum::<f32>() / n;
    let stddev = variance.sqrt();

    // 3σ → warning, 4.5σ → error.
    // Absolute floors (ppl≥100 for warnings, ppl≥500 for errors) prevent
    // near-mean statistical outliers from firing on valid code.
    let warn_thresh = (mean + 3.0 * stddev).max((100.0_f32).ln());
    let err_thresh  = (mean + 4.5 * stddev).max((500.0_f32).ln());

    // Collect all candidate items.
    let candidates: Vec<DiagnosticItem> = records
        .iter()
        .filter(|r| r.neg_log_p >= warn_thresh)
        .map(|r| {
            let ppl = r.neg_log_p.exp();
            let severity = if r.neg_log_p >= err_thresh { "error" } else { "warning" };
            DiagnosticItem {
                start_byte: r.start_byte,
                end_byte: r.end_byte,
                token: r.token_text.clone(),
                perplexity: ppl,
                severity,
                message: format!(
                    "Unexpected `{}` here (perplexity {:.1}). \
                     Check surrounding syntax — the model finds this \
                     token unlikely in this context.",
                    r.token_text, ppl
                ),
            }
        })
        .collect();

    // Suppress isolated warnings: a single token above warn_thresh but below
    // err_thresh is statistical noise in long programs.  Only keep warnings
    // that are adjacent to another flagged token, OR have ppl ≥ 1000.
    // Errors (ppl ≥ err_thresh) always pass through.
    let flagged_bytes: std::collections::HashSet<usize> =
        candidates.iter().map(|d| d.start_byte).collect();

    let items: Vec<DiagnosticItem> = candidates
        .into_iter()
        .filter(|d| {
            if d.severity == "error" || d.perplexity >= 1000.0 {
                return true;
            }
            // Keep warning only if a neighbouring structural token is also flagged.
            // We look within ±40 bytes of this token.
            flagged_bytes
                .iter()
                .any(|&b| b != d.start_byte && b.abs_diff(d.start_byte) <= 40)
        })
        .collect();

    Ok(items)
}

// ------------------------------------------------------------------ //
// Free-form generation  (ghost text / debug)
// ------------------------------------------------------------------ //

pub struct GenerateConfig {
    pub tokenizer: PathBuf,
    pub checkpoint: PathBuf,
    pub prompt: String,
    pub max_new_tokens: usize,
    pub temperature: f64,
    pub top_k: usize,
    pub cpu: bool,
}

pub fn generate(cfg: &GenerateConfig) -> Result<String> {
    let m = LoadedModel::load(&cfg.tokenizer, &cfg.checkpoint, cfg.cpu)?;

    let mut ids: Vec<u32> = vec![m.tok.sos_id];
    ids.extend(m.tok.encode(&cfg.prompt)?);

    for _ in 0..cfg.max_new_tokens {
        let last_logits = m.last_logits(&ids)?;
        let next_id = sample_top_k(&last_logits, cfg.temperature, cfg.top_k)?;
        if next_id == m.tok.eos_id {
            break;
        }
        ids.push(next_id);
    }

    let prompt_len = m.tok.encode(&cfg.prompt)?.len();
    let new_ids = &ids[1 + prompt_len..];
    m.tok.decode(new_ids)
}

// ------------------------------------------------------------------ //
// Internal helpers
// ------------------------------------------------------------------ //

fn pick_device(cpu: bool) -> Result<Device> {
    if cpu {
        return Ok(Device::Cpu);
    }
    if candle_core::utils::metal_is_available() {
        return Ok(Device::new_metal(0)?);
    }
    if candle_core::utils::cuda_is_available() {
        return Ok(Device::new_cuda(0)?);
    }
    Ok(Device::Cpu)
}

/// Strip HuggingFace BPE byte-level prefix (Ġ = space, Ċ = newline).
fn clean_token(t: &str) -> String {
    t.replace('Ġ', " ").replace('Ċ', "\n").replace('▁', " ")
}

/// Multinomial sample from logits with temperature + top-k.
fn sample_top_k(logits: &Tensor, temperature: f64, top_k: usize) -> Result<u32> {
    let logits = logits.to_device(&Device::Cpu)?.to_dtype(DType::F32)?;
    let vocab = logits.dims1()?;

    let logits = if (temperature - 1.0).abs() > 1e-6 {
        (logits / temperature)?
    } else {
        logits
    };

    let probs: Vec<f32> =
        candle_nn::ops::softmax(&logits.unsqueeze(0)?, D::Minus1)?
            .squeeze(0)?
            .to_vec1()?;

    let k = top_k.min(vocab);
    let mut indexed: Vec<(usize, f32)> = probs.iter().copied().enumerate().collect();
    indexed.sort_unstable_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    let threshold = indexed[k - 1].1;

    let mut mass = 0.0f32;
    let kept: Vec<(usize, f32)> = indexed
        .into_iter()
        .filter(|(_, p)| *p >= threshold)
        .map(|(i, p)| { mass += p; (i, p) })
        .collect();

    let mut r = rand::random::<f32>() * mass;
    for (idx, p) in &kept {
        r -= p;
        if r <= 0.0 {
            return Ok(*idx as u32);
        }
    }
    Ok(kept.last().unwrap().0 as u32)
}
