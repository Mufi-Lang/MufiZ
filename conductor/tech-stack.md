# Technology Stack - MufiZ

## Core Languages & Runtimes
- **Zig (v0.15.2):** The primary language for the compiler, virtual machine, and standard library implementation.
- **Mufi-Lang:** The custom interpreted language implemented by this project.

## Build & Dependency Management
- **Zig Build System:** Used for compiling the library, executable, running tests, and managing cross-compilation targets.
- **Zig Package Manager:** Utilized for managing external dependencies (e.g., `clap`).

## Key Dependencies
- **clap:** A Zig-native command-line argument parser used for the `mufiz` CLI.

## Architectural Components
- **Compiler:** Translates Mufi-Lang source code into custom bytecode.
- **Virtual Machine (VM):** A high-performance, stack-based VM for executing Mufi-Lang bytecode, optimized for memory safety and speed.
- **Standard Library:** Built-in modules for data serialization (JSON, TOML, YAML), numerical methods (Linear Algebra, Calculus, Optimization), and system I/O.

## Deployment & Integration Targets
- **Standalone CLI:** The `mufiz` executable for running scripts and interactive REPL sessions.
- **Static/Dynamic Library:** `libmufiz` for embedding into other Zig or C projects.
- **WebAssembly (Wasm):** Targets for browser-based execution and portable integration.
