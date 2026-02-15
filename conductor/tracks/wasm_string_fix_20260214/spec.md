# Specification: WASM String Fix

## Overview
This track addresses reported memory corruption issues related to string handling in the WebAssembly (WASM) build of MufiZ. Additionally, it addresses a UI bug in the web demo where raw `<script>` tags are displayed instead of being correctly escaped or processed.

## Objectives
- Identify the root cause of memory corruption when handling strings in the WASM environment.
- Implement robust string passing between the Zig VM and the JavaScript host.
- Fix the UI escaping issue in the React-based web demo.

## Success Criteria
- Strings are correctly passed and retrieved from the WASM module without corruption.
- The web demo correctly displays output without raw `<script>` tags appearing unexpectedly.
- All WASM-specific tests pass.
