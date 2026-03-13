//! Benchmark suite for the MufiZ Neural LSP Engine.
//!
//! Metrics reported:
//!   Completion  — top-1 / top-3 / top-5 accuracy on held-out token sequences
//!   Diagnostics — false-positive rate on valid programs
//!                 true-positive rate on programs with injected keyword errors
//!   Latency     — median and p95 wall-clock time (µs) for complete + diagnose

use std::path::PathBuf;
use std::time::Instant;
use std::io::Read;

use anyhow::Result;
use serde::Serialize;
use crate::infer::{complete, diagnose, LoadedModel};

// ------------------------------------------------------------------ //
// Public config
// ------------------------------------------------------------------ //

pub struct BenchConfig {
    pub tokenizer: PathBuf,
    pub checkpoint: PathBuf,
    pub corpus: PathBuf,
    /// Fraction of programs to hold out for evaluation (default 0.10).
    pub test_split: f64,
    /// Max programs to evaluate (caps wall-clock time).
    pub max_programs: usize,
    pub cpu: bool,
}

// ------------------------------------------------------------------ //
// Output report (serialised to JSON)
// ------------------------------------------------------------------ //

#[derive(Debug, Serialize)]
pub struct BenchReport {
    pub model_checkpoint: String,
    pub corpus: String,
    pub programs_evaluated: usize,

    pub completion: CompletionMetrics,
    pub diagnostics: DiagnosticMetrics,
    pub latency: LatencyMetrics,
}

#[derive(Debug, Serialize)]
pub struct CompletionMetrics {
    /// Number of structural-token prediction trials.
    pub trials: usize,
    pub top1_accuracy: f64,
    pub top3_accuracy: f64,
    pub top5_accuracy: f64,
    /// Mean entropy (bits) of the prediction distribution — lower = more confident.
    pub mean_entropy_bits: f64,
}

#[derive(Debug, Serialize)]
pub struct DiagnosticMetrics {
    /// Valid-program false positive rate (structural tokens flagged / total structural tokens).
    pub false_positive_rate: f64,
    /// Programs with ≥1 false positive diagnostic / total valid programs.
    pub programs_with_false_positive: f64,
    /// Injected-error detection rate (errors caught / errors injected).
    pub true_positive_rate: f64,
    pub errors_injected: usize,
    pub errors_detected: usize,
}

#[derive(Debug, Serialize)]
pub struct LatencyMetrics {
    pub complete_median_us: u64,
    pub complete_p95_us: u64,
    pub diagnose_median_us: u64,
    pub diagnose_p95_us: u64,
    pub complete_samples: usize,
    pub diagnose_samples: usize,
}

// ------------------------------------------------------------------ //
// Entry point
// ------------------------------------------------------------------ //

pub fn run(cfg: &BenchConfig) -> Result<BenchReport> {
    eprintln!("Loading model…");
    let m = LoadedModel::load(&cfg.tokenizer, &cfg.checkpoint, cfg.cpu)?;

    eprintln!("Loading corpus…");
    let programs = load_programs(&cfg.corpus)?;
    let n_total = programs.len();

    // Hold-out split: last `test_split` fraction
    let n_test = ((n_total as f64 * cfg.test_split).ceil() as usize)
        .max(1)
        .min(cfg.max_programs)
        .min(n_total);
    let test_programs = &programs[n_total - n_test..];
    eprintln!("  corpus: {n_total} programs, evaluating {n_test} held-out programs");

    let completion  = bench_completion(&m, test_programs)?;
    let diagnostics = bench_diagnostics(&m, test_programs)?;
    let latency     = bench_latency(&m, test_programs)?;

    Ok(BenchReport {
        model_checkpoint: cfg.checkpoint.display().to_string(),
        corpus: cfg.corpus.display().to_string(),
        programs_evaluated: n_test,
        completion,
        diagnostics,
        latency,
    })
}

// ------------------------------------------------------------------ //
// Completion accuracy
// ------------------------------------------------------------------ //

/// MufiZ structural tokens — we only evaluate prediction accuracy on these
/// (identifiers are inherently unpredictable per-program).
const STRUCTURAL: &[&str] = &[
    "var", "fun", "if", "else", "while", "for", "foreach", "return",
    "print", "println", "true", "false", "nil", "in", "and", "or", "not",
    "import", "break", "continue",
    "(", ")", "{", "}", "[", "]", ";", ",", ".",
    "=", "==", "!=", "<", ">", "<=", ">=",
    "+", "-", "*", "/", "%", "->",
];

fn is_structural_text(t: &str) -> bool {
    let clean = t.trim_matches(|c: char| c == 'Ġ' || c == 'Ċ' || c == '▁' || c == ' ');
    STRUCTURAL.contains(&clean)
}

fn bench_completion(m: &LoadedModel, programs: &[String]) -> Result<CompletionMetrics> {
    let mut top1 = 0usize;
    let mut top3 = 0usize;
    let mut top5 = 0usize;
    let mut trials = 0usize;
    let mut entropy_sum = 0.0f64;

    for prog in programs {
        let ids = m.tok.encode(prog)?;
        if ids.len() < 4 {
            continue;
        }

        // Walk each prefix that ends just before a structural token.
        let mut prefix_ids: Vec<u32> = vec![m.tok.sos_id];
        for (idx, &actual_id) in ids.iter().enumerate() {
            if idx == 0 {
                prefix_ids.push(actual_id);
                continue;
            }
            let raw = m.tok.id_to_token(actual_id).unwrap_or_default();
            if !is_structural_text(&raw) {
                prefix_ids.push(actual_id);
                continue;
            }

            // We have a structural token to predict — reconstruct source prefix
            if let Ok(prefix_text) = m.tok.decode(&prefix_ids[1..]) {
                if let Ok(candidates) = complete(m, &prefix_text, 5) {
                    let actual_clean = raw
                        .trim_matches(|c: char| c == 'Ġ' || c == 'Ċ' || c == '▁' || c == ' ')
                        .to_string();
                    let texts: Vec<String> = candidates
                        .iter()
                        .map(|c| c.text.trim().to_string())
                        .collect();

                    if texts.first().map_or(false, |t| t == &actual_clean) { top1 += 1; }
                    if texts.iter().take(3).any(|t| t == &actual_clean) { top3 += 1; }
                    if texts.iter().take(5).any(|t| t == &actual_clean) { top5 += 1; }

                    // Entropy of top-5 distribution
                    let mass: f32 = candidates.iter().map(|c| c.score).sum();
                    if mass > 0.0 {
                        let entropy: f64 = candidates
                            .iter()
                            .filter(|c| c.score > 0.0)
                            .map(|c| {
                                let p = (c.score / mass) as f64;
                                -p * p.log2()
                            })
                            .sum();
                        entropy_sum += entropy;
                    }
                    trials += 1;
                }
            }
            prefix_ids.push(actual_id);
        }
    }

    let t = trials.max(1) as f64;
    Ok(CompletionMetrics {
        trials,
        top1_accuracy: top1 as f64 / t,
        top3_accuracy: top3 as f64 / t,
        top5_accuracy: top5 as f64 / t,
        mean_entropy_bits: entropy_sum / t,
    })
}

// ------------------------------------------------------------------ //
// Diagnostic precision / recall
// ------------------------------------------------------------------ //

fn bench_diagnostics(m: &LoadedModel, programs: &[String]) -> Result<DiagnosticMetrics> {
    let mut fp_tokens = 0usize;
    let mut total_structural_tokens = 0usize;
    let mut programs_with_fp = 0usize;
    let mut errors_injected = 0usize;
    let mut errors_detected = 0usize;

    // Keywords that can be injected as errors (unexpected in most positions)
    const INJECT_TOKENS: &[&str] = &["else", "return", "break", "continue", "foreach"];

    for prog in programs {
        // --- False positive rate: run diagnose on the valid program ---
        if let Ok(diags) = diagnose(m, prog) {
            let structural_count = count_structural_tokens(m, prog);
            total_structural_tokens += structural_count;
            if !diags.is_empty() {
                fp_tokens += diags.len();
                programs_with_fp += 1;
            }
        }

        // --- True positive rate: inject a random error and check detection ---
        let injected = inject_error(prog, INJECT_TOKENS);
        if let Some(broken) = injected {
            errors_injected += 1;
            if let Ok(diags) = diagnose(m, &broken) {
                if !diags.is_empty() {
                    errors_detected += 1;
                }
            }
        }
    }

    let fp_rate = if total_structural_tokens > 0 {
        fp_tokens as f64 / total_structural_tokens as f64
    } else {
        0.0
    };
    let prog_fp_rate = if !programs.is_empty() {
        programs_with_fp as f64 / programs.len() as f64
    } else {
        0.0
    };
    let tp_rate = if errors_injected > 0 {
        errors_detected as f64 / errors_injected as f64
    } else {
        0.0
    };

    Ok(DiagnosticMetrics {
        false_positive_rate: fp_rate,
        programs_with_false_positive: prog_fp_rate,
        true_positive_rate: tp_rate,
        errors_injected,
        errors_detected,
    })
}

fn count_structural_tokens(m: &LoadedModel, text: &str) -> usize {
    m.tok
        .encode(text)
        .unwrap_or_default()
        .iter()
        .filter(|&&id| {
            m.tok
                .id_to_token(id)
                .map_or(false, |t| is_structural_text(&t))
        })
        .count()
}

/// Prepend a surprising keyword to the source to create an injected error.
fn inject_error(prog: &str, tokens: &[&str]) -> Option<String> {
    // Find a line with actual code (not blank, not a comment).
    let lines: Vec<&str> = prog.lines().collect();
    let code_line = lines
        .iter()
        .position(|l| !l.trim().is_empty() && !l.trim_start().starts_with("//"))?;
    let inject = tokens[code_line % tokens.len()];
    let mut result = prog.to_string();
    // Prepend the surprising token on column 0 of the chosen line.
    let byte_pos = lines[..code_line].iter().map(|l| l.len() + 1).sum::<usize>();
    result.insert_str(byte_pos, &format!("{inject} "));
    Some(result)
}

// ------------------------------------------------------------------ //
// Latency
// ------------------------------------------------------------------ //

fn bench_latency(m: &LoadedModel, programs: &[String]) -> Result<LatencyMetrics> {
    let mut complete_times: Vec<u64> = Vec::new();
    let mut diagnose_times: Vec<u64> = Vec::new();

    // Sample ~50 short snippets from the programs for latency measurement.
    let snippets: Vec<String> = programs
        .iter()
        .flat_map(|p| {
            // Take first 3 lines as a snippet.
            let snippet: String = p.lines().take(3).collect::<Vec<_>>().join("\n");
            if snippet.trim().is_empty() { None } else { Some(snippet) }
        })
        .take(50)
        .collect();

    for snippet in &snippets {
        let t0 = Instant::now();
        let _ = complete(m, snippet, 5);
        complete_times.push(t0.elapsed().as_micros() as u64);

        let t0 = Instant::now();
        let _ = diagnose(m, snippet);
        diagnose_times.push(t0.elapsed().as_micros() as u64);
    }

    complete_times.sort_unstable();
    diagnose_times.sort_unstable();

    fn median(v: &[u64]) -> u64 {
        if v.is_empty() { return 0; }
        v[v.len() / 2]
    }
    fn p95(v: &[u64]) -> u64 {
        if v.is_empty() { return 0; }
        v[(v.len() as f64 * 0.95) as usize]
    }

    Ok(LatencyMetrics {
        complete_median_us: median(&complete_times),
        complete_p95_us: p95(&complete_times),
        diagnose_median_us: median(&diagnose_times),
        diagnose_p95_us: p95(&diagnose_times),
        complete_samples: complete_times.len(),
        diagnose_samples: diagnose_times.len(),
    })
}

// ------------------------------------------------------------------ //
// Corpus loader
// ------------------------------------------------------------------ //

fn load_programs(corpus: &PathBuf) -> Result<Vec<String>> {
    let raw = if corpus.to_string_lossy().ends_with(".gz") {
        let file = std::fs::File::open(corpus)?;
        let mut decoder = flate2::read::GzDecoder::new(file);
        let mut bytes = Vec::new();
        decoder.read_to_end(&mut bytes)?;
        String::from_utf8(bytes)?
    } else {
        std::fs::read_to_string(corpus)?
    };
    
    // Corpus uses two separators:
    //   synthetic programs → "# ---"
    //   real .mufi files   → "// ===PROGRAM==="
    let mut result: Vec<String> = Vec::new();
    let mut current = String::new();
    for line in raw.lines() {
        if line.trim() == "# ---" || line.trim() == "// ===PROGRAM===" {
            let prog = current.trim().to_string();
            if prog.len() > 20 {
                result.push(prog);
            }
            current.clear();
        } else {
            current.push_str(line);
            current.push('\n');
        }
    }
    let prog = current.trim().to_string();
    if prog.len() > 20 {
        result.push(prog);
    }
    Ok(result)
}
