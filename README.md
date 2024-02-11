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

        --repl
            Runs Mufi Repl system (Windows uses C bindings)
```

---

> Windows still uses `pre.c` to run Mufi-Lang as there is current issues with Zig's `std.io.getStdin().reader()`. 

## Debug vs Release Modes 

Now when building under the `Debug` optimize mode, MufiZ will contain the debugging macros
that shows GC tracing, and chunk disassembly. These will be turned off when built under any of
the other `Release*` optimize modes with command `zig build -Doptimize=`. 

> Note: The following components are built under a specific optimize mode:
>
> - `libmufiz_scanner`: `ReleaseFast`
>   - Since this library doesn't involve memory management on the Zig side, we can prioritize performance.
> - `clap`: `ReleaseSafe`
>   - Since this library involves components that require allocations, we prioritize safety.

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

---

## Ziggified

- **Scanner**
  - The scanner which is responsible for tokenizing a string is now completely written in Zig, and exported to C.
  - Is built as a shared library `libmufiz_scanner` and linked before the C files.
  - The reason this was moved first, as its the least dependent part of the compiler, so there is not
  too much breakage when moving it (only had to care about `compiler.c`).
  - Any function that would interfere with another function, was prefixed with `__scanner__`
    - Might consider prefixing all functions of scanner with this.

---

## Releases

| Version | Codename                                                                 | Status      |
| ------- | ------------------------------------------------------------------------ | ----------- |
| 0.1.0   | Baloo                                                                    | Archived    |
| 0.2.0   | [Zula](https://github.com/Mustafif/MufiZ/releases/tag/v0.2.0)            | Released    |
| 0.3.0   | [Iris](https://github.com/Mustafif/MufiZ/releases/tag/v0.3.0)            | Released    |
| 0.4.0   | [Voxl](https://github.com/Mustafif/MufiZ/releases/tag/next-experimental) | In Progress |

---


## Supported Platforms

| Targets            |
| ------------------ |
| aarch64-macos      |
| x86_64-macos       |
| aarch64-linux-gnu  |
| aarch64-linux-musl |
| x86_64-linux-gnu   |
| x86_64-linux-musl  |
| x86_64-windows     |
| aarch64-windows    |