# Implementation Plan: WASM String Fix

## Phase 1: Investigation & Reproduction
- [ ] Task: Create a reproduction script in MufiZ that triggers string corruption in the WASM environment.
- [ ] Task: Audit `src/c_api.zig` and WASM-specific glue code for improper memory management of strings.
- [ ] Task: Conductor - User Manual Verification 'Phase 1' (Protocol in workflow.md)

## Phase 2: Implementation & Fix
- [ ] Task: Fix string memory allocation/deallocation logic for WASM.
    - [ ] Write Tests: Add regression tests for WASM string handling.
    - [ ] Implement: Update Zig source code to handle WASM strings safely.
- [ ] Task: Correct UI escaping in the web demo (React/TypeScript).
    - [ ] Write Tests: Add frontend tests for string rendering.
    - [ ] Implement: Update React components to escape or correctly handle string output.
- [ ] Task: Conductor - User Manual Verification 'Phase 2' (Protocol in workflow.md)

## Phase 3: Verification
- [ ] Task: Verify fix in the web demo environment.
- [ ] Task: Ensure all existing tests pass for native and WASM targets.
- [ ] Task: Conductor - User Manual Verification 'Phase 3' (Protocol in workflow.md)
