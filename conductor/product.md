# Initial Concept
can we make a plan to fix issues with wasm strings, there seems to be a corruption issues, and in the web demo it says <script> all the time

# Product Definition: MufiZ

## Vision & Goals
MufiZ is a high-performance, modular compiler and interpreter for Mufi-Lang, built with Zig. It aims to provide a seamless bridge between a high-level scripting language and the safety and efficiency of the Zig ecosystem.

### Primary Goals
- **Stability and Performance:** Maintaining a robust core by focusing on bug fixes, optimizing the VM/compiler, and ensuring memory safety.
- **Feature Expansion:** Growing the language through new features, a broader standard library (Net, FS, etc.), and a mature built-in package manager.
- **Ecosystem Integration:** Providing top-tier support for library consumers via a stable C API (FFI), enhanced WebAssembly integration, and comprehensive documentation.

## Target Audience
- **Zig Developers:** Those seeking a lightweight, embeddable scripting language for Zig-native projects.
- **Mufi-Lang Developers:** Programmers building applications directly in Mufi-Lang.
- **Language Contributors:** Developers interested in evolving the MufiZ compiler, VM, and standard library.
- **Web & Scripting Users:** Developers using Mufi-Lang for general-purpose scripting or client-side logic via WASM.

## Key Features & Value Propositions
- **Deep Zig Synergy:** Leverages Zig's build system for easy cross-compilation and caching, with a focus on memory safety and easy embedding.
- **Modern Data Structures:** Native, first-class support for Float Vectors `{}` and Hash Tables `#{}`.
- **Flexible Deployment:** Available as a standalone CLI, a Zig library, a shared C library, or a WebAssembly module.
- **Built-in Tooling:** Includes an interactive REPL with enhanced input handling and a native package manager (ZON-based).
