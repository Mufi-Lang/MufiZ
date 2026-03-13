# Neural LSP Engine for Mufi-Lang

## Objective
Develop a small language model (SLM) based on a neural network architecture (likely a small Transformer) using the Rust `candle` framework. This model will power the Language Server Protocol (LSP) for Mufi-Lang, providing error prediction, intelligent code completion (intellisense), and context-aware suggestions.

## Key Goals
1.  **Small Language Model (SLM):** Designed to run and be trained on consumer hardware (MacBook Pro, M-series chips leveraging Metal/MPS).
2.  **LSP Integration:** The primary consumer is the LSP, requiring low latency inference.
3.  **High-Quality Synthetic Dataset:**
    -   Must be syntactically valid and compile successfully.
    -   Must be semantically meaningful (not random tokens).
    -   Must cover:
        -   Core grammar rules (EBNF/PEG).
        -   Standard Library functions and types.
        -   Keywords and control structures.
4.  **Framework:** Rust `candle` (for ML) integrated with the ecosystem.

## Constraints
-   **Training Environment:** Local MacBook (utilizing `candle-core` with Metal backend).
-   **Dataset Size:** Compressed but rich in structure to maximize learning efficiency on a small model.
-   **Model Size:** < 100M parameters (target: ~10-50M for real-time LSP usage).

## Architecture Components
1.  **Data Generation Pipeline:**
    -   Tooling to generate synthetic Mufi code based on formal grammar.
    -   Validation step using the Mufi compiler (`mufi` CLI or library) to ensure compilability.
2.  **Tokenizer:**
    -   Custom BPE (Byte-Pair Encoding) or Unigram tokenizer trained on Mufi source code + synthetic corpus.
3.  **Model Architecture:**
    -   Decoder-only Transformer (GPT-style).
    -   Optimized for code (e.g., rotary embeddings, GQA if needed).
4.  **Training Loop:**
    -   Implemented in Rust using `candle`.
    -   Supports checkpointing and evaluation.
5.  **Inference Engine:**
    -   Standalone binary or library to be called by the LSP.
