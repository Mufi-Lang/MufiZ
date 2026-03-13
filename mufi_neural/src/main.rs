// Modules shared with the lib crate — re-use via lib.
use mufi_neural::infer;
use mufi_neural::model;
use mufi_neural::data;

mod bench;
mod lsp;
mod train;

use std::path::PathBuf;

use anyhow::Result;
use candle_core::Device;
use clap::{Parser, Subcommand};

use infer::GenerateConfig;
use model::Config;
use train::TrainConfig;

// ------------------------------------------------------------------ //
// CLI
// ------------------------------------------------------------------ //

#[derive(Parser)]
#[command(name = "mufi-neural", about = "MufiZ Neural LSP Engine")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Train the language model on a MufiZ corpus
    Train {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        #[arg(long, default_value = "corpus/smart_corpus.txt")]
        corpus: PathBuf,

        #[arg(long, default_value_t = 10)]
        epochs: usize,

        #[arg(long, default_value_t = 32)]
        batch_size: usize,

        #[arg(long, default_value_t = 3e-4)]
        lr: f64,

        #[arg(long, default_value_t = 128)]
        seq_len: usize,

        #[arg(long, default_value = "checkpoints")]
        output: PathBuf,

        #[arg(long)]
        cpu: bool,
    },

    /// Print model and tokenizer statistics
    Info {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,
    },

    /// IntelliSense: return top-N next-token candidates at the cursor as JSON.
    /// Feed this into LSP textDocument/completion.
    Complete {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        /// Safetensors checkpoint
        #[arg(long)]
        checkpoint: PathBuf,

        /// Source code up to (and including) the cursor position
        #[arg(long)]
        source: String,

        /// Number of candidates to return
        #[arg(long, default_value_t = 10)]
        top_n: usize,

        #[arg(long)]
        cpu: bool,
    },

    /// Error prediction: return high-perplexity token spans as JSON.
    /// Feed this into LSP textDocument/diagnostic.
    Diagnose {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        /// Safetensors checkpoint
        #[arg(long)]
        checkpoint: PathBuf,

        /// Full source code to analyse
        #[arg(long)]
        source: String,

        #[arg(long)]
        cpu: bool,
    },

    /// Free-form autoregressive generation (ghost text / debug)
    Generate {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        #[arg(long)]
        checkpoint: PathBuf,

        #[arg(long)]
        prompt: String,

        #[arg(long, default_value_t = 128)]
        max_new_tokens: usize,

        #[arg(long, default_value_t = 0.8)]
        temperature: f64,

        #[arg(long, default_value_t = 40)]
        top_k: usize,

        #[arg(long)]
        cpu: bool,
    },

    /// Start the Neural LSP server (stdin/stdout JSON-RPC).
    /// Point your editor's LSP client at this process.
    Lsp {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        /// Checkpoint to load (defaults to latest epoch_020)
        #[arg(long, default_value = "checkpoints/epoch_020.safetensors")]
        checkpoint: PathBuf,

        #[arg(long)]
        cpu: bool,
    },

    /// Benchmark completion accuracy, diagnostic precision/recall, and latency.
    Bench {
        #[arg(long, default_value = "tokenizer.json")]
        tokenizer: PathBuf,

        #[arg(long, default_value = "checkpoints/epoch_020.safetensors")]
        checkpoint: PathBuf,

        #[arg(long, default_value = "corpus/smart_corpus.txt")]
        corpus: PathBuf,

        /// Fraction of programs to hold out for evaluation (0.0–1.0)
        #[arg(long, default_value_t = 0.10)]
        test_split: f64,

        /// Maximum number of programs to evaluate
        #[arg(long, default_value_t = 100)]
        max_programs: usize,

        /// Output raw JSON instead of formatted table
        #[arg(long)]
        json: bool,

        #[arg(long)]
        cpu: bool,
    },
}

// ------------------------------------------------------------------ //
// Benchmark pretty-printer
// ------------------------------------------------------------------ //

fn print_bench_report(r: &bench::BenchReport) {
    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║           MufiZ Neural LSP — Benchmark Report           ║");
    println!("╠══════════════════════════════════════════════════════════╣");
    println!("║  Checkpoint : {:<44}║", truncate(&r.model_checkpoint, 44));
    println!("║  Programs   : {:<44}║", r.programs_evaluated);
    println!("╠══════════════════════════════════════════════════════════╣");
    println!("║  COMPLETION ACCURACY  ({} structural-token trials)", r.completion.trials);
    println!("║  ─────────────────────────────────────────────────────  ║");
    println!("║  Top-1 : {:>6.1}%                                       ║", r.completion.top1_accuracy * 100.0);
    println!("║  Top-3 : {:>6.1}%                                       ║", r.completion.top3_accuracy * 100.0);
    println!("║  Top-5 : {:>6.1}%                                       ║", r.completion.top5_accuracy * 100.0);
    println!("║  Entropy (mean) : {:.3} bits                            ║", r.completion.mean_entropy_bits);
    println!("╠══════════════════════════════════════════════════════════╣");
    println!("║  DIAGNOSTICS");
    println!("║  ─────────────────────────────────────────────────────  ║");
    println!("║  False-positive rate    : {:>6.2}% (token-level)        ║", r.diagnostics.false_positive_rate * 100.0);
    println!("║  Programs w/ false pos  : {:>6.2}%                      ║", r.diagnostics.programs_with_false_positive * 100.0);
    println!("║  Error detection rate   : {:>6.2}% ({}/{} injected)     ║",
        r.diagnostics.true_positive_rate * 100.0,
        r.diagnostics.errors_detected, r.diagnostics.errors_injected);
    println!("╠══════════════════════════════════════════════════════════╣");
    println!("║  LATENCY");
    println!("║  ─────────────────────────────────────────────────────  ║");
    println!("║  complete  median {:>6} µs   p95 {:>6} µs  (n={})    ║",
        r.latency.complete_median_us, r.latency.complete_p95_us, r.latency.complete_samples);
    println!("║  diagnose  median {:>6} µs   p95 {:>6} µs  (n={})    ║",
        r.latency.diagnose_median_us, r.latency.diagnose_p95_us, r.latency.diagnose_samples);
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
}

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("…{}", &s[s.len().saturating_sub(max - 1)..])
    }
}

fn select_device(force_cpu: bool) -> Result<Device> {
    if force_cpu {
        println!("Device: CPU (forced)");
        return Ok(Device::Cpu);
    }
    if candle_core::utils::metal_is_available() {
        println!("Device: Metal (Apple GPU)");
        return Ok(Device::new_metal(0)?);
    }
    if candle_core::utils::cuda_is_available() {
        println!("Device: CUDA");
        return Ok(Device::new_cuda(0)?);
    }
    println!("Device: CPU");
    Ok(Device::Cpu)
}

// ------------------------------------------------------------------ //
// Entry point
// ------------------------------------------------------------------ //

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Train { tokenizer, corpus, epochs, batch_size, lr, seq_len, output, cpu } => {
            let device = select_device(cpu)?;
            let train_cfg = TrainConfig {
                epochs,
                batch_size,
                learning_rate: lr,
                seq_len,
                checkpoint_dir: output,
                ..Default::default()
            };
            train::train(tokenizer, corpus, &train_cfg, &device)?;
        }

        Commands::Info { tokenizer } => {
            let tok = data::MufiTokenizer::from_file(&tokenizer)?;
            println!("Tokenizer: {}", tokenizer.display());
            println!("  vocab_size = {}", tok.vocab_size);
            println!("  <pad>      = {}", tok.pad_id);
            println!("  <sos>      = {}", tok.sos_id);
            println!("  <eos>      = {}", tok.eos_id);

            let cfg = Config::small(tok.vocab_size);
            println!("\nModel config (small):");
            println!("  layers     = {}", cfg.n_layers);
            println!("  heads      = {}", cfg.n_heads);
            println!("  d_model    = {}", cfg.d_model);
            println!("  d_ff       = {}", cfg.d_ff);
            println!("  max_seq    = {}", cfg.max_seq_len);
            println!("  ~params    = {}K", cfg.param_count() / 1000);
        }

        Commands::Complete { tokenizer, checkpoint, source, top_n, cpu } => {
            let m = infer::LoadedModel::load(&tokenizer, &checkpoint, cpu)?;
            let items = infer::complete(&m, &source, top_n)?;
            println!("{}", serde_json::to_string_pretty(&items)?);
        }

        Commands::Diagnose { tokenizer, checkpoint, source, cpu } => {
            let m = infer::LoadedModel::load(&tokenizer, &checkpoint, cpu)?;
            let items = infer::diagnose(&m, &source)?;
            println!("{}", serde_json::to_string_pretty(&items)?);
        }

        Commands::Generate { tokenizer, checkpoint, prompt, max_new_tokens, temperature, top_k, cpu } => {
            let cfg = GenerateConfig { tokenizer, checkpoint, prompt: prompt.clone(),
                max_new_tokens, temperature, top_k, cpu };
            let completion = infer::generate(&cfg)?;
            println!("{}{}", prompt, completion);
        }

        Commands::Lsp { tokenizer, checkpoint, cpu } => {
            lsp::run_lsp(tokenizer, checkpoint, cpu).await?;
        }

        Commands::Bench { tokenizer, checkpoint, corpus, test_split, max_programs, json, cpu } => {
            let cfg = bench::BenchConfig { tokenizer, checkpoint, corpus, test_split, max_programs, cpu };
            let report = bench::run(&cfg)?;
            if json {
                println!("{}", serde_json::to_string_pretty(&report)?);
            } else {
                print_bench_report(&report);
            }
        }
    }

    Ok(())
}
