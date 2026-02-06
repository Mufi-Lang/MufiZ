# Technology Stack

## Core Language & Runtime
*   **Primary Language:** Zig (v0.15.2) - Used for the core compiler, virtual machine, and library implementation.
*   **Build System:** Zig Build System - Handles compilation, cross-targeting, and dependency management.

## Dependencies & Integrations
*   **CLI Argument Parsing:** `clap` - Used for processing command-line options in the `mufiz` executable.
*   **Interoperability:** C ABI - The project exposes a stable C API (`src/c_api.zig`) to allow integration with C, Swift, and other languages.

## Target Platforms
*   **Native:** Optimized builds for major operating systems (Linux, macOS, Windows).
*   **WebAssembly:** Support for WASM targets to enable browser-based execution of Mufi-Lang.
