use std::path::Path;
use std::io::Read;

use anyhow::{Context, Result};
use candle_core::{Device, Tensor};
use tokenizers::Tokenizer;

// ------------------------------------------------------------------ //
// Tokenizer wrapper
// ------------------------------------------------------------------ //

pub struct MufiTokenizer {
    inner: Tokenizer,
    pub vocab_size: usize,
    pub sos_id: u32,
    pub eos_id: u32,
    pub pad_id: u32,
}

impl MufiTokenizer {
    pub fn from_file(path: impl AsRef<Path>) -> Result<Self> {
        let inner = Tokenizer::from_file(path.as_ref())
            .map_err(|e| anyhow::anyhow!("Failed to load tokenizer: {e}"))?;

        let vocab_size = inner.get_vocab_size(true);
        let sos_id = inner
            .token_to_id("<sos>")
            .context("<sos> token not in tokenizer vocab")?;
        let eos_id = inner
            .token_to_id("<eos>")
            .context("<eos> token not in tokenizer vocab")?;
        let pad_id = inner
            .token_to_id("<pad>")
            .context("<pad> token not in tokenizer vocab")?;

        Ok(Self {
            inner,
            vocab_size,
            sos_id,
            eos_id,
            pad_id,
        })
    }

    pub fn encode(&self, text: &str) -> Result<Vec<u32>> {
        let enc = self
            .inner
            .encode(text, false)
            .map_err(|e| anyhow::anyhow!("Encoding error: {e}"))?;
        Ok(enc.get_ids().to_vec())
    }

    /// Returns (token_ids, byte_offsets) for each token in `text`.
    pub fn encode_with_offsets(&self, text: &str) -> Result<(Vec<u32>, Vec<(usize, usize)>)> {
        let enc = self
            .inner
            .encode(text, false)
            .map_err(|e| anyhow::anyhow!("Encoding error: {e}"))?;
        let ids = enc.get_ids().to_vec();
        let offsets = enc.get_offsets().to_vec();
        Ok((ids, offsets))
    }

    pub fn id_to_token(&self, id: u32) -> Option<String> {
        self.inner.id_to_token(id)
    }

    pub fn decode(&self, ids: &[u32]) -> Result<String> {
        self.inner
            .decode(ids, true)
            .map_err(|e| anyhow::anyhow!("Decoding error: {e}"))
    }
}

// ------------------------------------------------------------------ //
// Corpus loading
// ------------------------------------------------------------------ //

/// Read corpus file (optionally gzipped) and split into individual programs.
/// If the path ends with .gz, decompresses on the fly.
pub fn load_programs(path: impl AsRef<Path>) -> Result<Vec<String>> {
    let path = path.as_ref();
    let raw = if path.to_string_lossy().ends_with(".gz") {
        let file = std::fs::File::open(path)
            .with_context(|| format!("Cannot open corpus: {}", path.display()))?;
        let mut decoder = flate2::read::GzDecoder::new(file);
        let mut bytes = Vec::new();
        decoder
            .read_to_end(&mut bytes)
            .with_context(|| format!("Cannot decompress corpus: {}", path.display()))?;
        String::from_utf8(bytes)
            .with_context(|| format!("Decompressed corpus contains invalid UTF-8: {}", path.display()))?
    } else {
        std::fs::read_to_string(path)
            .with_context(|| format!("Cannot read corpus: {}", path.display()))?
    };

    let programs: Vec<String> = raw
        .split("# ---")
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    Ok(programs)
}

/// Tokenize all programs, wrap each with <sos>/<eos>, and flatten into
/// one contiguous token stream.
pub fn build_token_stream(
    programs: &[String],
    tokenizer: &MufiTokenizer,
) -> Result<Vec<u32>> {
    let mut stream: Vec<u32> = Vec::new();

    for prog in programs {
        let ids = tokenizer.encode(prog)?;
        stream.push(tokenizer.sos_id);
        stream.extend_from_slice(&ids);
        stream.push(tokenizer.eos_id);
    }

    Ok(stream)
}

// ------------------------------------------------------------------ //
// Batching
// ------------------------------------------------------------------ //

pub struct Dataset {
    /// All (input, target) pairs as flat vecs of length seq_len.
    inputs: Vec<Vec<u32>>,
    targets: Vec<Vec<u32>>,
    pub seq_len: usize,
}

impl Dataset {
    /// Build dataset from a flat token stream using non-overlapping windows
    /// of size `seq_len + 1` (input = first seq_len tokens, target = last seq_len).
    pub fn from_stream(stream: &[u32], seq_len: usize) -> Self {
        let window = seq_len + 1;
        let n = stream.len() / window;

        let mut inputs = Vec::with_capacity(n);
        let mut targets = Vec::with_capacity(n);

        for i in 0..n {
            let chunk = &stream[i * window..(i + 1) * window];
            inputs.push(chunk[..seq_len].to_vec());
            targets.push(chunk[1..].to_vec());
        }

        Self {
            inputs,
            targets,
            seq_len,
        }
    }

    pub fn len(&self) -> usize {
        self.inputs.len()
    }

    pub fn is_empty(&self) -> bool {
        self.inputs.is_empty()
    }

    /// Shuffle indices in place using a simple Fisher-Yates shuffle.
    pub fn shuffled_indices(&self) -> Vec<usize> {
        use rand::seq::SliceRandom;
        let mut rng = rand::thread_rng();
        let mut idx: Vec<usize> = (0..self.len()).collect();
        idx.shuffle(&mut rng);
        idx
    }

    /// Yield (input_tensor, target_tensor) batches. Shape: (batch, seq_len).
    pub fn batches<'a>(
        &'a self,
        indices: &'a [usize],
        batch_size: usize,
        device: &'a Device,
    ) -> impl Iterator<Item = Result<(Tensor, Tensor)>> + 'a {
        indices.chunks(batch_size).map(move |chunk| {
            let b = chunk.len();
            let seq = self.seq_len;

            let inp_flat: Vec<u32> = chunk
                .iter()
                .flat_map(|&i| self.inputs[i].iter().copied())
                .collect();
            let tgt_flat: Vec<u32> = chunk
                .iter()
                .flat_map(|&i| self.targets[i].iter().copied())
                .collect();

            let inp = Tensor::from_vec(inp_flat, (b, seq), device)?;
            let tgt = Tensor::from_vec(tgt_flat, (b, seq), device)?;
            Ok((inp, tgt))
        })
    }
}

// ------------------------------------------------------------------ //
// End-to-end loader
// ------------------------------------------------------------------ //

pub fn prepare_dataset(
    corpus_path: impl AsRef<Path>,
    tokenizer: &MufiTokenizer,
    seq_len: usize,
) -> Result<Dataset> {
    let programs = load_programs(&corpus_path)?;
    println!(
        "  Loaded {} programs from {}",
        programs.len(),
        corpus_path.as_ref().display()
    );

    let stream = build_token_stream(&programs, tokenizer)?;
    println!("  Token stream length: {}", stream.len());

    let dataset = Dataset::from_stream(&stream, seq_len);
    println!(
        "  Sequences: {} × {} tokens",
        dataset.len(),
        dataset.seq_len
    );

    Ok(dataset)
}
