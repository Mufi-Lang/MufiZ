use std::path::{Path, PathBuf};

use anyhow::Result;
use candle_core::{DType, Device, Tensor, D};
use candle_nn::{self as nn, optim::Optimizer, VarBuilder, VarMap};

use crate::{
    data::{prepare_dataset, MufiTokenizer},
    model::{Config, MufiLM},
};

// ------------------------------------------------------------------ //
// Training configuration
// ------------------------------------------------------------------ //

#[derive(Debug, Clone)]
pub struct TrainConfig {
    pub epochs: usize,
    pub batch_size: usize,
    pub learning_rate: f64,
    pub weight_decay: f64,
    pub seq_len: usize,
    pub checkpoint_dir: PathBuf,
    pub log_every: usize, // log loss every N batches
}

impl Default for TrainConfig {
    fn default() -> Self {
        Self {
            epochs: 10,
            batch_size: 32,
            learning_rate: 3e-4,
            weight_decay: 0.1,
            seq_len: 128,
            checkpoint_dir: PathBuf::from("checkpoints"),
            log_every: 50,
        }
    }
}

// ------------------------------------------------------------------ //
// Loss
// ------------------------------------------------------------------ //

/// Cross-entropy loss over (batch, seq_len, vocab) logits and (batch, seq_len) targets.
/// Ignores pad tokens (id == pad_id).
fn cross_entropy_loss(
    logits: &Tensor,
    targets: &Tensor,
    pad_id: u32,
    vocab_size: usize,
) -> Result<Tensor> {
    let (b, t, v) = logits.dims3()?;

    // Flatten to (b*t, vocab) and (b*t,)
    let logits_flat = logits.reshape((b * t, v))?;
    let targets_flat = targets.reshape((b * t,))?;

    // Log-softmax then NLL
    let log_probs = candle_nn::ops::log_softmax(&logits_flat, D::Minus1)?;

    // Gather log-prob of correct class: shape (b*t, 1) → (b*t,)
    let target_ids = targets_flat.to_dtype(DType::I64)?;
    let gathered = log_probs.gather(&target_ids.unsqueeze(1)?, 1)?.squeeze(1)?;

    // Mask out pad positions
    let pad_mask = targets_flat
        .ne(pad_id)?
        .to_dtype(DType::F32)?;

    // Mean loss over non-pad tokens
    let n_tokens = pad_mask.sum_all()?;
    let loss = (gathered.neg()? * &pad_mask)?.sum_all()?.div(&n_tokens)?;
    Ok(loss)
}

// ------------------------------------------------------------------ //
// Training loop
// ------------------------------------------------------------------ //

pub fn train(
    tokenizer_path: impl AsRef<Path>,
    corpus_path: impl AsRef<Path>,
    train_cfg: &TrainConfig,
    device: &Device,
) -> Result<()> {
    std::fs::create_dir_all(&train_cfg.checkpoint_dir)?;

    // ---------------------------------------------------------------- //
    // 1. Load tokenizer and dataset
    // ---------------------------------------------------------------- //
    println!("Loading tokenizer...");
    let tokenizer = MufiTokenizer::from_file(&tokenizer_path)?;
    println!("  vocab_size = {}", tokenizer.vocab_size);

    println!("Preparing dataset...");
    let dataset = prepare_dataset(&corpus_path, &tokenizer, train_cfg.seq_len)?;
    if dataset.is_empty() {
        anyhow::bail!("Dataset is empty — check corpus path.");
    }

    // ---------------------------------------------------------------- //
    // 2. Build model
    // ---------------------------------------------------------------- //
    let cfg = Config::small(tokenizer.vocab_size);
    println!("\nModel config: {cfg:?}");
    println!("Estimated parameters: ~{}K", cfg.param_count() / 1000);

    let var_map = VarMap::new();
    let vb = VarBuilder::from_varmap(&var_map, DType::F32, device);
    let model = MufiLM::new(&cfg, vb)?;

    // ---------------------------------------------------------------- //
    // 3. Optimizer (AdamW)
    // ---------------------------------------------------------------- //
    let adamw_params = nn::optim::ParamsAdamW {
        lr: train_cfg.learning_rate,
        weight_decay: train_cfg.weight_decay,
        beta1: 0.9,
        beta2: 0.95,
        eps: 1e-8,
    };
    let mut optimizer = nn::optim::AdamW::new(var_map.all_vars(), adamw_params)?;

    // ---------------------------------------------------------------- //
    // 4. Training loop
    // ---------------------------------------------------------------- //
    println!("\nStarting training on device: {device:?}");
    println!(
        "  epochs={}, batch_size={}, lr={}, seq_len={}",
        train_cfg.epochs,
        train_cfg.batch_size,
        train_cfg.learning_rate,
        train_cfg.seq_len
    );
    println!("  batches/epoch ≈ {}\n", dataset.len() / train_cfg.batch_size);

    for epoch in 1..=train_cfg.epochs {
        let indices = dataset.shuffled_indices();
        let mut epoch_loss = 0f64;
        let mut batch_count = 0usize;

        for (step, batch) in dataset
            .batches(&indices, train_cfg.batch_size, device)
            .enumerate()
        {
            let (inputs, targets) = batch?;

            // Forward
            let logits = model.forward(&inputs)?;

            // Loss
            let loss = cross_entropy_loss(
                &logits,
                &targets,
                tokenizer.pad_id,
                tokenizer.vocab_size,
            )?;

            // Backward
            optimizer.backward_step(&loss)?;

            let loss_val = loss.to_scalar::<f32>()? as f64;
            epoch_loss += loss_val;
            batch_count += 1;

            if (step + 1) % train_cfg.log_every == 0 {
                println!(
                    "  epoch {epoch}/{} | step {:>5} | loss {:.4} | ppl {:.2}",
                    train_cfg.epochs,
                    step + 1,
                    loss_val,
                    loss_val.exp()
                );
            }
        }

        let avg_loss = epoch_loss / batch_count as f64;
        let ppl = avg_loss.exp();
        println!(
            "── epoch {epoch}/{} complete: avg_loss={avg_loss:.4}  ppl={ppl:.2}",
            train_cfg.epochs
        );

        // Save checkpoint
        let ckpt_path = train_cfg
            .checkpoint_dir
            .join(format!("epoch_{epoch:03}.safetensors"));
        var_map.save(&ckpt_path)?;
        println!("  Checkpoint → {}", ckpt_path.display());
    }

    println!("\nTraining complete.");
    Ok(())
}
