# Tech Stack: MufiZ

## Core Compiler & VM
- **Primary Language:** Zig (v0.15.2)
- **Build System:** Zig Build System (`build.zig`, `build.zig.zon`)
- **Architecture:** Custom VM, Bytecode Compiler, and Garbage Collector (GC).
- **External Dependencies:** `clap` (Command Line Argument Parser).

## Web & Frontend (Web Demo)
- **Framework:** React with TypeScript.
- **Styling:** Tailwind CSS with Ant Design components.
- **Target:** WebAssembly (WASI/WASM32) compiled from Zig.

## Integration & APIs
- **C API:** Shared library support for FFI with generated `mufiz.h` headers.
- **WASM API:** WebAssembly exports for browser-side execution.
- **Zig API:** Native package support for other Zig projects.

## Infrastructure & Tooling
- **Package Management:** Built-in PM using ZON (Zig Object Notation).
- **Cross-Platform:** Support for macOS (ARM/Intel), Linux, Windows, and Browser (WASM).
