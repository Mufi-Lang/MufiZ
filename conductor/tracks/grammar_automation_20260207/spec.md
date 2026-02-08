# Specification - Formal Grammar, Automation Tools, and WebAssembly Library

## Overview
This track introduces a formal Parsing Expression Grammar (PEG) for Mufi-Lang, a suite of integrated automation tools (`fmt` and `test-gen`), and ensures a fully functional WebAssembly library (`libmufiz.wasm`). These enhancements aim to standardize the language syntax, improve developer experience, and enable portable execution in web environments.

## Functional Requirements

### 1. Formal Grammar Specification
- **Format:** Parsing Expression Grammar (PEG), modeled after the Zig language specification.
- **Location:** `docs/grammar.peg`.
- **Content:** A complete and unambiguous description of Mufi-Lang's syntax, covering all expressions, statements, control flow, and data structures (vectors, matrices, hash tables).

### 2. MufiZ Code Formatter (`mufiz fmt`)
- **Action:** Reads a `.mufi` source file and outputs a version that adheres to official style guidelines (e.g., standard indentation, naming conventions).
- **Error Handling:** If a syntax error is encountered, the tool must halt immediately and report the precise line and column. It must not modify the file on failure.
- **Integration:** Integrated as a sub-command: `mufiz fmt <file.mufi>`.

### 3. Synthetic Test Generator (`mufiz test-gen`)
- **Action:** Automatically generates valid (and optionally invalid) `.mufi` code snippets derived from the PEG grammar.
- **Purpose:** To provide a comprehensive suite of test cases for fuzzing the compiler and VM, ensuring robustness.
- **Integration:** Integrated as a sub-command: `mufiz test-gen`.

### 4. WebAssembly Library (`libmufiz.wasm`)
- **Action:** Ensure the build system produces a functional, self-contained `.wasm` module.
- **Exports:** The module must export core functions: `init`, `deinit`, and `interpret`.
- **Deliverable:** A functional `libmufiz.wasm` accompanied by a simple HTML/JS boilerplate demonstrating its usage in a browser environment.

## Technical Requirements
- **Language:** Implementation in Zig (v0.15.2).
- **CLI:** Tools must be integrated into the `mufiz` binary using the `clap` library.
- **Build System:** Leverage `build.zig` and potentially `scripts/build-wasm.sh` for Wasm production.

## Acceptance Criteria
- [ ] A validated `grammar.peg` file exists in `docs/`.
- [ ] `mufiz fmt` successfully reformats valid `.mufi` files without changing execution logic.
- [ ] `mufiz test-gen` generates syntactically correct code that the VM can execute.
- [ ] A browser-based demo successfully loads `libmufiz.wasm` and interprets Mufi-Lang code.
- [ ] All new sub-commands are discoverable via `mufiz --help`.

## Out of Scope
- A standalone web-based editor for Mufi-Lang.
- Semantic analysis or type checking within the formatter.
