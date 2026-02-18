# Implementation Plan: Workspace Management (MATLAB-style)

This plan outlines the steps to introduce MATLAB-style workspace management functions (`whos`, `clear`) and a variable protection mechanism to Mufi-Lang.

## Phase 1: Core Infrastructure & Variable Tagging

Focus on updating the variable storage mechanism to distinguish between "clearable" user variables and protected system/module variables.

- [x] Task: Define "Protected" status in variable metadata.
    - [x] Update the global variable table structure to track whether a variable is "protected" (e.g., via a flag in the symbol table).
    - [x] Implement logic to automatically flag standard library and module imports as protected during initialization.
- [x] Task: Implement internal visibility logic.
    - [x] Add a utility function to check if a variable name follows the "internal" convention (starts with `_`).
- [x] Task: Conductor - User Manual Verification 'Phase 1: Core Infrastructure' (Protocol in workflow.md)

## Phase 2: Built-in Function Implementation

Implement the user-facing functions in the Mufi-Lang runtime.

- [~] Task: Implement `whos()` built-in function.
    - [ ] Write tests for `whos()` output formatting and filtering (excluding `_` variables by default).
    - [ ] Implement the `whos()` logic: iterate through the global table, filter protected/internal entries, and format the results.
- [ ] Task: Implement `clear()` built-in function.
    - [ ] Write tests for `clear()` with no arguments (clears all non-protected).
    - [ ] Write tests for `clear("name")` with specific arguments.
    - [ ] Write tests ensuring protected variables (imports, stdlib, `_` names) are NOT cleared.
    - [ ] Implement the `clear()` logic: remove entries from the global symbol table and ensure values are available for GC.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Built-in Functions' (Protocol in workflow.md)

## Phase 3: Integration & Polish

Ensure the functions are correctly registered and behave well in the REPL.

- [ ] Task: Register functions as global built-ins.
    - [ ] Add `whos` and `clear` to the default global scope initialized by the VM.
- [ ] Task: Final stability and GC verification.
    - [ ] Run memory leak tests after repeated `clear()` calls to ensure the GC is reclaiming memory correctly.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Integration' (Protocol in workflow.md)
