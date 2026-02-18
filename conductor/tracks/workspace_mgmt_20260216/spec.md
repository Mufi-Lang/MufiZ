# Specification: Workspace Management (MATLAB-style)

## Overview
Introduce a workspace management system to Mufi-Lang, allowing users to inspect, modify, and clear global variables during an interactive session or within scripts. This feature aims to provide a "MATLAB-like" experience for managing the global environment.

## Functional Requirements
- **Global Variable Inspection:**
    - Implement a `whos()` built-in function that returns or displays a detailed list of all user-defined global variables.
    - The output must include the variable name, its current type, and a representation of its value.
- **Variable Removal (Clear):**
    - Implement a `clear()` built-in function.
    - `clear()` (no arguments) should remove all unprotected user-defined global variables.
    - `clear("name1", "name2", ...)` should remove specific variables by name.
- **Protection Mechanism:**
    - **Automatic Protection:** Variables originating from the standard library or imported modules must be protected from `clear()` by default.
    - **Naming Convention:** Variables starting with an underscore (`_`) are considered "internal" or "system" variables and should be excluded from `clear()` and `whos()` by default unless specifically targeted.
- **Programmatic Access:**
    - Ensure these functions are accessible as global built-ins within the Mufi-Lang runtime.

## Non-Functional Requirements
- **Performance:** `whos()` should be efficient even with a large number of global variables.
- **Stability:** Clearing variables must correctly handle garbage collection and ensure no dangling references remain in the VM.

## Acceptance Criteria
- [ ] Calling `whos()` in the REPL displays a formatted table of user variables.
- [ ] Calling `clear()` removes user variables but leaves imports/stdlib intact.
- [ ] Calling `clear("x")` removes only `x`.
- [ ] Variables starting with `_` are not removed by a generic `clear()`.
- [ ] The VM remains stable after multiple `clear()` and `whos()` calls.

## Out of Scope
- Persisting workspace variables to disk (Save/Load workspace).
- GUI-based workspace browser (this is CLI/Runtime focused).
