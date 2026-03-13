# MufiZ Neural LSP Engine

A ~5M parameter Transformer model (Rust + [Candle](https://github.com/huggingface/candle) ML framework) providing **IntelliSense code completion** and **error diagnostics** for the [MufiZ programming language](https://github.com/mustafif/MufiZ).

## Quick Start

### Prerequisites

- **Rust 1.70+** — [install](https://rustup.rs/)
- **Python 3.8+** — for corpus/tokenizer generation (optional if you just want to run inference)
- **macOS 12+** with Metal GPU support (optional; falls back to CPU)

### Build & Test

```bash
# Release build (dylib + binary)
make all

# Run the benchmark
./target/release/mufi_neural bench --max-programs 100

# Run the LSP server
./target/release/mufi_neural lsp

# Run Swift FFI integration test
make smoke
```

## Commands Reference

### `mufi_neural bench`

Evaluates the model on a held-out test set from the corpus.

```bash
./target/release/mufi_neural bench [OPTIONS]

Options:
  --tokenizer <PATH>              [default: tokenizer.json]
  --checkpoint <PATH>             [default: checkpoints/epoch_020.safetensors]
  --corpus <PATH>                 [default: corpus/smart_corpus.txt]
  --test-split <FRACTION>         Hold-out fraction (0.0–1.0) [default: 0.1]
  --max-programs <N>              Max programs to evaluate [default: 100]
  --json                          Output raw JSON
  --cpu                           Force CPU inference (default: Metal GPU if available)
```

**Example output** (50 programs):
```
╔══════════════════════════════════════════════════════════╗
║           MufiZ Neural LSP — Benchmark Report           ║
╠══════════════════════════════════════════════════════════╣
║  Checkpoint : checkpoints/epoch_020.safetensors           ║
║  Programs   : 50                                          ║
╠══════════════════════════════════════════════════════════╣
║  COMPLETION ACCURACY  (7830 structural-token trials)
║  Top-1 :   45.4%   Top-3 :   66.1%   Top-5 :   75.0%  ║
║  Entropy (mean) : 0.960 bits                            ║
╠══════════════════════════════════════════════════════════╣
║  DIAGNOSTICS
║  False-positive rate    :   0.85% (token-level)        ║
║  Programs w/ false pos  :  66.00%                      ║
║  Error detection rate   :  70.00% (35/50 injected)     ║
╠══════════════════════════════════════════════════════════╣
║  LATENCY
║  complete  median   1949 µs   p95   2364 µs  (n=50)    ║
║  diagnose  median   3573 µs   p95   6003 µs  (n=50)    ║
╚══════════════════════════════════════════════════════════╝
```

**Metrics:**
- **Top-N**: Completion accuracy — whether the true next token appears in top N predictions
- **Entropy**: Bits per token (lower = more confident predictions)
- **Token-level FP**: False-positive rate (error reported where none exists)
- **Error detection**: TP / (TP + FN) — how many injected errors were caught
- **Latency**: `complete` vs `diagnose` end-to-end time (includes tokenization + inference)

### `mufi_neural lsp`

Starts a tower-lsp server on `stdio` for editor integration.

```bash
./target/release/mufi_neural lsp [OPTIONS]

Options:
  --tokenizer <PATH>              [default: tokenizer.json]
  --checkpoint <PATH>             [default: checkpoints/epoch_020.safetensors]
  --cpu                           Force CPU inference
```

**Usage in an editor** (e.g., VSCode):

1. Configure the launch command in your editor's LSP client settings:
   ```json
   "command": "/path/to/target/release/mufi_neural",
   "args": ["lsp", "--tokenizer", "tokenizer.json", "--checkpoint", "checkpoints/epoch_020.safetensors"]
   ```
2. On file open/change, the server publishes:
   - `textDocument/publishDiagnostics` — errors (high confidence only; ppl ≥ 4.5σ or ≥ 500)
   - `textDocument/completion` — suggestions when you call `completion` (usually Ctrl+Space)

**Filtering:**
- Only **error** severity diagnostics are published (warnings are suppressed to reduce noise)
- Isolated low-confidence warnings (ppl < 1000, no adjacent errors) are filtered out

### `mufi_neural train`

Trains or fine-tunes the model on the corpus.

```bash
./target/release/mufi_neural train [OPTIONS]

Options:
  --tokenizer <PATH>              [default: tokenizer.json]
  --corpus <PATH>                 [default: corpus/smart_corpus.txt]
  --checkpoint <PATH>             Existing checkpoint to fine-tune from
  --epochs <N>                    Number of training epochs [default: 20]
  --batch-size <N>                [default: 32]
  --learning-rate <F>             [default: 0.0005]
  --output <PATH>                 Output checkpoint path [default: checkpoints/epoch_XXX.safetensors]
  --cpu                           Force CPU training
```

**Example:**
```bash
# Train from scratch for 20 epochs (saves to checkpoints/epoch_020.safetensors)
./target/release/mufi_neural train

# Fine-tune an existing checkpoint for 5 more epochs
./target/release/mufi_neural train \
  --checkpoint checkpoints/epoch_020.safetensors \
  --epochs 5 \
  --output checkpoints/epoch_025.safetensors
```

---

## Corpus & Tokenizer

### Generating a Synthetic Corpus

The `generate_type_aware.py` script creates a large, diverse corpus of MufiZ programs with proper type annotations.

```bash
# Generate 2000 programs (takes ~30-60 seconds)
python3 generate_type_aware.py --output corpus/smart_corpus.txt --num-programs 2000
```

**Command-line options:**
- `--output PATH` — Output file path (default: `corpus/smart_corpus.txt`)
- `--num-programs N` — Number of programs to generate (default: 100)

**Features:**
- Type-aware variable declarations
- Control flow (if/else, while, for, foreach)
- Function definitions with arguments
- Proper scoping and variable usage
- Collections (vectors, arrays)
- Full standard library coverage (math, type conversion, type predicates, I/O)
- Injected errors for diagnostic training

### Corpus Compression (Optional)

To save disk space, you can compress the corpus with gzip:

```bash
gzip corpus/smart_corpus.txt
# Creates corpus/smart_corpus.txt.gz (~25% of original size)
```

All tools automatically detect and decompress `.gz` files on the fly:

```bash
# Works with compressed corpus — no decompression needed upfront
./target/release/mufi_neural bench --corpus corpus/smart_corpus.txt.gz
./target/release/mufi_neural train --corpus corpus/smart_corpus.txt.gz
```

**Compression ratio:** ~75% savings (2.2MB → 546KB for smart_corpus)

### Training a Tokenizer

The `train_tokenizer.py` script builds a BPE tokenizer from the corpus.

```bash
python3 train_tokenizer.py --corpus corpus/smart_corpus.txt --output tokenizer.json
```

Produces `tokenizer.json` (vocabulary for model input/output).

### Validating the Corpus

Use `validate_corpus.py` to check program validity and coverage:

```bash
python3 validate_corpus.py --corpus corpus/smart_corpus.txt --tokenizer tokenizer.json
```

---

## Swift FFI

### Building the dylib

```bash
make swift
```

This builds the release binary and copies the dylib + C header to `swift-pkg/Sources/MufiNeural/`.

### Using in Swift

1. **Add the bridging header** in your Swift package's `Bridging-Header.h`:
   ```c
   #include "mufi_neural.h"
   ```

2. **Link the dylib** in `Package.swift`:
   ```swift
   .binaryTarget(
       name: "MufiNeural",
       path: "Sources/MufiNeural/libmufi_neural.dylib"
   )
   ```

3. **Call the FFI functions**:
   ```swift
   import Foundation

   // Completion
   let json = mufi_complete(
       "path/to/tokenizer.json",
       "path/to/checkpoints/epoch_020.safetensors",
       "var x = 10;\nvar y = ",
       topN: 5
   )!
   let result = String(cString: json)
   // result = [{"text":"nil","score":0.44,...}, ...]
   mufi_free_string(json)

   // Diagnostics
   let diagJson = mufi_diagnose(
       "path/to/tokenizer.json",
       "path/to/checkpoints/epoch_020.safetensors",
       "var x = 10; var y = 20\n"
   )!
   let diagnostics = String(cString: diagJson)
   mufi_free_string(diagJson)
   ```

### FFI Functions

All three functions are thread-safe (each call loads the model independently).

#### `mufi_complete`

```c
/// Generates top-N completion suggestions for code.
///
/// @param tokenizer_path  Path to tokenizer.json
/// @param checkpoint_path Path to .safetensors checkpoint
/// @param source_before_cursor Source code up to the cursor
/// @param top_n           Number of suggestions (max 10)
/// @return JSON string (heap-allocated; caller must free with mufi_free_string)
///
/// JSON shape:
///   [
///     {"text": "nil", "score": 0.44},
///     {"text": "true", "score": 0.31},
///     ...
///   ]
const char *mufi_complete(
    const char *tokenizer_path,
    const char *checkpoint_path,
    const char *source_before_cursor,
    size_t top_n
);
```

#### `mufi_diagnose`

```c
/// Reports syntax/semantic errors in source code.
///
/// @param tokenizer_path  Path to tokenizer.json
/// @param checkpoint_path Path to .safetensors checkpoint
/// @param source          Full source code
/// @return JSON string (heap-allocated; caller must free with mufi_free_string)
///
/// JSON shape (empty array if no errors detected):
///   [
///     {
///       "line": 1,
///       "column": 5,
///       "message": "unexpected type: expected Bool",
///       "severity": "error"
///     },
///     ...
///   ]
const char *mufi_diagnose(
    const char *tokenizer_path,
    const char *checkpoint_path,
    const char *source
);
```

#### `mufi_free_string`

```c
/// Deallocates a string returned by mufi_complete or mufi_diagnose.
///
/// @param ptr Pointer returned by mufi_complete/mufi_diagnose
void mufi_free_string(const char *ptr);
```

### C Smoke Test

A minimal C integration test is provided in `tests/smoke.c`. Run it with:

```bash
make smoke
```

---

## Project Structure

```
mufi_neural/
├── Cargo.toml              # Rust dependencies; [lib] crate-type = ["cdylib", "rlib"]
├── Makefile                # Build & test targets
├── README.md               # This file
├── src/
│   ├── lib.rs              # Crate root; exposes data, infer, model, ffi
│   ├── main.rs             # CLI entry point; delegates to bench, lsp, train
│   ├── model.rs            # Model architecture (Transformer)
│   ├── data.rs             # Corpus loading & tokenization
│   ├── infer.rs            # Inference pipeline; LoadedModel, complete(), diagnose()
│   ├── ffi.rs              # C FFI wrappers (mufi_complete, mufi_diagnose, mufi_free_string)
│   ├── bench.rs            # Benchmark subcommand (accuracy, latency, diagnostics)
│   ├── lsp.rs              # tower-lsp server implementation
│   └── train.rs            # Training loop & checkpoint saving
├── include/
│   └── mufi_neural.h       # C header for Swift FFI
├── tests/
│   └── smoke.c             # Minimal C integration test
├── swift-pkg/              # Swift package stub (generated by `make swift`)
│   ├── Package.swift       # Add .binaryTarget("MufiNeural", ...) here
│   └── Sources/MufiNeural/
│       ├── libmufi_neural.dylib
│       └── include/mufi_neural.h
├── corpus/
│   └── smart_corpus.txt    # Training & evaluation data (generated)
├── checkpoints/
│   └── epoch_020.safetensors  # Pre-trained model weights
├── tokenizer.json          # BPE tokenizer vocabulary
├── generate_type_aware.py  # Synthetic corpus generator
├── generate_synthetic_data.py
├── train_tokenizer.py      # Tokenizer training script
└── validate_corpus.py      # Corpus validation script
```

---

## Model Details

### Architecture

- **Type**: Transformer decoder-only (GPT-style)
- **Parameters**: ~5M (configurable in `src/model.rs`)
- **Context window**: 1024 tokens
- **Vocabulary size**: ~1500 (tokenizer-dependent)
- **Training**: Causal language modeling + synthetic error labels

### Checkpoints

Pre-trained checkpoints are stored as `.safetensors` files in `checkpoints/`:

- `epoch_020.safetensors` — 20 epochs, ~2GB corpus
- Additional checkpoints can be trained with `mufi_neural train --epochs N`

### Hardware

- **GPU**: Metal (macOS) — automatic on Apple Silicon/Intel Macs with Metal support
- **CPU**: Falls back automatically if Metal unavailable, or with `--cpu` flag
- **Inference**: ~2ms per completion (Metal), ~20ms per completion (CPU)

---

## Diagnostics Tuning

The model flags tokens with **perplexity ≥ 4.5σ** (error severity) or **≥ 500 (absolute)**:

```rust
// src/infer.rs, ~line 238–290
const WARN_THRESHOLD_SIGMA: f32 = 3.0;      // 3σ = ~99.7% confidence
const ERROR_THRESHOLD_SIGMA: f32 = 4.5;     // 4.5σ = ~99.9993% confidence
const WARN_PPL_FLOOR: f32 = 100.0;
const ERROR_PPL_FLOOR: f32 = 500.0;
```

**False-positive suppression:**
- Isolated warnings (no adjacent flagged token within ±40 bytes) are filtered if ppl < 1000
- This reduces noise in the editor while preserving true errors

**Example:**
```rust
// Good error detection:
let x = 10
var y = true;    // ← Caught (unexpected type, ppl ≈ 600)

// Suppressed as noise:
let x = 10; var y
     ↑ Isolated low-confidence warning (ppl ≈ 150); not published to editor
```

---

## Performance

**Benchmark results** (50 programs, epoch_020):
- **Completion Top-5**: 75.0%
- **Error detection**: 70.0%
- **Token-level false positives**: 0.85%
- **Completion latency**: ~2ms (p95: 2.4ms)
- **Diagnostic latency**: ~3.6ms (p95: 6ms)

See `mufi_neural bench --json` for full results including per-program breakdowns.

---

## Development

### Adding a New Subcommand

1. Create a new module in `src/` (e.g., `src/export.rs`)
2. Declare it in `src/main.rs`:
   ```rust
   mod export;
   ```
3. Add a struct in `src/main.rs`:
   ```rust
   #[derive(Subcommand)]
   enum Commands {
       Export(ExportArgs),
       // ...
   }
   ```
4. Wire it in the `main()` function

### Adding a New Metric to the Benchmark

Edit `src/bench.rs` and add the computation in the eval loop. The benchmark will display it in the formatted table.

### Running Tests

The project doesn't have a formal test suite yet. Use:
```bash
make smoke       # C FFI integration test
./target/release/mufi_neural bench --max-programs 10  # Quick smoke bench
```

---

## Known Limitations

1. **No persistent model handle in FFI**: Each `mufi_complete`/`mufi_diagnose` call reloads the model (~200ms). For high-frequency calls (e.g., LSP on every keystroke), consider caching the loaded model on the Swift side.
2. **Single-file analysis**: The model operates on individual files; no cross-file type information.
3. **No WASM support**: The `tokenizers` crate depends on `onig_sys` (C regex), which cannot cross-compile to `wasm32`. For browser support, export to ONNX + use `onnxruntime-web`.

---

## Troubleshooting

### Build fails with Metal errors
```bash
# Fall back to CPU
./target/release/mufi_neural train --cpu
./target/release/mufi_neural bench --cpu
```

### `tokenizer.json` not found
```bash
python3 train_tokenizer.py --corpus corpus/smart_corpus.txt --output tokenizer.json
```

### Benchmark shows `[0 / 0 programs]`
The corpus parser expects `# ---` or `// ===PROGRAM===` separators. Regenerate:
```bash
python3 generate_type_aware.py --output corpus/smart_corpus.txt --num-programs 2000
```

### LSP server unresponsive
Check stderr for model loading errors:
```bash
./target/release/mufi_neural lsp 2>&1 | head -50
```

---

## Contributing

Improvements welcome! Common areas:
- Improving synthetic corpus generation (more realistic error patterns)
- Fine-tuning diagnostic thresholds
- Adding new analysis passes (e.g., unused variable detection)
- Performance optimizations (batch inference, model quantization)

---

## License

[TBD — same as MufiZ]
