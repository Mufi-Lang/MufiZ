# MufiZ

> This project uses the Zig `v0.11.0`

This project aims to integrate the Mufi-Lang compiler with the Zig language by using the 
Zig Build system. We hope to integrate more features with this language and see how nicely 
we can utilize both languages in unity. The advantage of Zig's Build system is easy cross-compatibility and caching, and as we integrate more,
we can ensure more memory safety.

[MufiZ Standard Library Plans](stdlib.md)

## Usage:

```shell
$ mufiz --help 
    -h, --help
            Displays this help and exit.

    -v, --version
            Prints the version and codename.

    -r, --run <str>
            Runs a Mufi Script

    -l, --link <str>
            Link another Mufi Script when interpreting

        --repl
            Runs Mufi Repl system
```

---

## Debug vs Release Modes

Now when building under the `Debug` optimize mode, MufiZ will contain the debugging macros
that shows GC tracing, and chunk disassembly. These will be turned off when built under any of
the other `Release*` optimize modes with command `zig build -Doptimize=`.

> Note: The following components are built under a specific optimize mode:
>
> - `libmufiz_scanner`: `ReleaseFast`
>   - Since this library doesn't involve memory management on the Zig side, we can prioritize performance.
> - `libmufiz_table`: `ReleaseFast`
>   - Since this library doesn't involve memory management on the Zig side, we can prioritize performance.
> - `libmufiz_core`: `ReleaseFast`
>   - Since this library contains all of the C code, we can prioritize performance.
> - `clap`: `ReleaseSafe`
>   - Since this library involves components that require allocations, we prioritize safety.

## Installation

- To install MufiZ, you can get the latest release from the Github releases page with your appropriate toolchain.
- Then you may run the binary when you unzip the Zip file.
- We also provide a deb and rpm package for Linux users.

## Goal

- [X] Replace `pre` with Zig so we can perform `repl/scripts` with guaranteed memory safety.
  - Such cases as avoiding buffer overflow
- [X] Optional standard library (ability to be ran with `nostd`)
  - Use the option: `-Dnostd`
- [ ] Standard Libary
- [ ] Documentation
  - [ ] Standard Library documentation
  - [ ] Language reference
- [ ] Website: `mufiz.mustafif.com`
- [ ] Installation Guide

---

## Ziggified

- **Scanner**
  - The scanner which is responsible for tokenizing a string is now completely written in Zig, and exported to C.
  - Is built as a shared library `libmufiz_scanner` and linked before the C files.
  - The reason this was moved first, as its the least dependent part of the compiler, so there is not
  too much breakage when moving it (only had to care about `compiler.c`).
  - Any function that would interfere with another function, was prefixed with `__scanner__`
    - Might consider prefixing all functions of scanner with this.

- **Table**  
  - The table is the hashtable implementation that is used in Mufi-Lang. It is now completely written in Zig, and exported to C.

---

## Releases

| Version | Codename                                                      | Status   |
| ------- | ------------------------------------------------------------- | -------- |
| 0.1.0   | Baloo                                                         | Archived |
| 0.2.0   | [Zula](https://github.com/Mustafif/MufiZ/releases/tag/v0.2.0) | Released |
| 0.3.0   | [Iris](https://github.com/Mustafif/MufiZ/releases/tag/v0.3.0) | Released |
| 0.4.0   | [Voxl](https://github.com/Mustafif/MufiZ/releases/tag/v0.4.0) | Released |

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/mufiz)
---

## Supported Platforms

| Target                 | Deb Package        | RPM Package        | Snap Package       |
| ---------------------- | ------------------ | ------------------ | ------------------ |
| aarch64-linux-gnu      | :white_check_mark: | :white_check_mark: | :x:                |
| aarch64-linux-musl     | :white_check_mark: | :white_check_mark: | :x:                |
| aarch64-macos          | :x:                | :x:                | :x:                |
| aarch64-windows        | :x:                | :x:                | :x:                |
| aarch64-windows-gnu    | :x:                | :x:                | :x:                |
| arm-linux-gnueabi      | :white_check_mark: | :white_check_mark: | :x:                |
| arm-linux-gnueabihf    | :white_check_mark: | :white_check_mark: | :x:                |
| arm-linux-musleabi     | :white_check_mark: | :white_check_mark: | :x:                |
| arm-linux-musleabihf   | :white_check_mark: | :white_check_mark: | :x:                |
| mips64-linux-musl      | :white_check_mark: | :white_check_mark: | :x:                |
| mips64el-linux-musl    | :white_check_mark: | :white_check_mark: | :x:                |
| mipsel-linux-musl      | :white_check_mark: | :white_check_mark: | :x:                |
| mips-linux-musl        | :white_check_mark: | :white_check_mark: | :x:                |
| powerpc64-linux-gnu    | :white_check_mark: | :white_check_mark: | :x:                |
| powerpc64-linux-musl   | :white_check_mark: | :white_check_mark: | :x:                |
| powerpc-linux-musl     | :white_check_mark: | :white_check_mark: | :x:                |
| powerpc64le-linux-gnu  | :white_check_mark: | :white_check_mark: | :x:                |
| powerpc64le-linux-musl | :white_check_mark: | :white_check_mark: | :x:                |
| riscv64-linux-musl     | :white_check_mark: | :white_check_mark: | :x:                |
| wasm32-wasi            | :x:                | :x:                | :x:                |
| x86_64-linux-gnu       | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| x86_64-linux-musl      | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| x86_64-macos           | :x:                | :x:                | :x:                |
| x86_64-windows         | :x:                | :x:                | :x:                |
| x86_64-windows-gnu     | :x:                | :x:                | :x:                |

> Currently `v0.4.0` is available as a `snap` package for `x86_64-linux-gnu` and `x86_64-linux-musl` targets. I hope to expand this to more targets for the next release using the `snapcraft` automatic build system.