# Implementation Plan - Grammar, Automation Tools, and WebAssembly

This plan follows the TDD approach and phase completion verification protocol defined in the project workflow.

## Phase 1: Formal Grammar and CLI Infrastructure [checkpoint: fdb8c4d]

- [x] **Task: Create Formal PEG Grammar** [f9f232c]
    - [x] Research and document all current Mufi-Lang syntax rules.
    - [x] Create `docs/grammar.peg` based on the research.
    - [x] Validate the PEG grammar against existing files in `test_suite/`.

- [x] **Task: Extend CLI with Sub-commands** [f9f232c]
    - [x] Update `src/main.zig` to support `fmt` and `test-gen` sub-commands using `clap`.
    - [x] Create stub implementations for the new sub-commands.
    - [x] Verify `mufiz --help` displays the new commands.

- [x] **Task: Conductor - User Manual Verification 'Phase 1: Formal Grammar and CLI Infrastructure' (Protocol in workflow.md)**

## Phase 2: WebAssembly Library Functional Validation [checkpoint: bbf4cf1]

- [x] **Task: Audit and Fix Wasm Build** [bbf4cf1]
    - [x] Execute `scripts/build-wasm.sh` and identify any build errors with Zig v0.15.2.
    - [x] Update `build.zig` and the build script to ensure a valid `libmufiz.wasm` is produced.
    - [x] Verify that core functions (`init`, `deinit`, `interpret`) are correctly exported.

- [x] **Task: Create Wasm Browser Demo** [bbf4cf1]
    - [x] Create `index.html` and `mufiz_wasm_demo.js` in the project root.
    - [x] Implement code to load `libmufiz.wasm` and run a simple "Hello World" Mufi script.
    - [x] Verify the demo works in a modern web browser.

- [x] **Task: Conductor - User Manual Verification 'Phase 2: WebAssembly Library Functional Validation' (Protocol in workflow.md)**

## Phase 3: Automation Tools Implementation

- [ ] **Task: Implement MufiZ Formatter (`fmt`)**
    - [ ] Write unit tests for formatting logic (e.g., indentation, spacing).
    - [ ] Implement the PEG-based parser for the formatter.
    - [ ] Implement the code re-writing logic in `src/system.zig` or a new module.
    - [ ] Verify `mufiz fmt` correctly formats files from the `test_suite/`.

- [ ] **Task: Implement Synthetic Test Generator (`test-gen`)**
    - [ ] Implement a recursive-descent generator based on `grammar.peg`.
    - [ ] Add logic to generate random valid expression trees.
    - [ ] Verify generated scripts execute without runtime errors in the VM.

- [ ] **Task: Conductor - User Manual Verification 'Phase 3: Automation Tools Implementation' (Protocol in workflow.md)**
