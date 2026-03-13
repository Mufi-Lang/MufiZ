# Implementation Plan: Neural LSP Engine

## Phase 1: Infrastructure & Environment Setup
- [x] **Initialize Rust Project:** Create a new Rust workspace or crate (e.g., `mufi-neural`) for the ML components.
- [x] **Dependency Management:** Add `candle-core`, `candle-nn`, `candle-transformers`, `tokenizers`, and `anyhow` to `Cargo.toml`.
- [x] **Metal/MPS Verification:** Ensure `candle` can access the MacBook's GPU (Metal) for training.

## Phase 2: Data Generation & Tokenization
- [ ] **Grammar Extraction:** Extract the formal grammar from `docs/grammar.ebnf` or `src/parser.zig`.
- [ ] **Synthetic Code Generator:**
    -   Develop a generator (in Rust or Python) that produces valid Mufi code structures (functions, loops, conditionals).
    -   Integrate with `mufi_stdlib.json` to ensure correct standard library usage.
- [ ] **Compiler Validation Loop:**
    -   Script to feed generated code to `zig-out/bin/mufi` (or equivalent) to verify syntax correctness.
    -   Filter out invalid code to create a "Clean Corpus".
- [ ] **Tokenizer Training:**
    -   Train a BPE tokenizer on the Clean Corpus + existing `examples/` and `tests/`.
    -   Save `tokenizer.json`.

## Phase 3: Model Architecture & Training
- [ ] **Model Definition:**
    -   Implement a small Transformer model (Config: ~4-6 layers, ~256-512 hidden dim, ~4-8 heads).
    -   Define the `Config` struct and model layers in Rust.
- [ ] **Training Loop:**
    -   Implement the data loader for the tokenized dataset.
    -   Implement the training loop with `AdamW` optimizer.
    -   Add support for saving checkpoints.
- [ ] **Initial Training Run:**
    -   Train on the MacBook and monitor loss.
    -   Tune hyperparameters for stability.

## Phase 4: Inference & LSP Integration
- [ ] **Inference CLI:**
    -   Create a simple CLI (`mufi-neural-cli`) that takes a code snippet and returns completions/predictions.
- [ ] **LSP Integration Strategy:**
    -   Define the interface between the existing/planned LSP and this neural component.
    -   (Optional) Compile the inference engine to WASM if the LSP runs in a constrained environment, or keep as a native sidecar.

## Phase 5: Evaluation & Refinement
- [ ] **Evaluation:** Test prediction accuracy on held-out Mufi code.
- [ ] **Optimization:** Quantization (if needed for size/speed).
