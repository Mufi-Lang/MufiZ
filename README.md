# MufiZ

> This project uses the Zig `v0.11.0`

This project aims to integrate the Mufi-Lang compiler with the Zig language by using the 
Zig Build system. We hope to integrate more features with this language and see how nicely 
we can utilize both languages in unity. The advantage of Zig's Build system is easy cross-compatibility and caching, and as we integrate more, 
we can ensure more memory safety. 


## Usage: 

```shell
$ zig build run # for repl 
$ zig build run -- version # for version 
$ zig build run -- <path> # to run script 
```

---

> Windows still uses `pre.c` to run Mufi-Lang as there is current issues with Zig's `std.io.getStdin().reader()`. 

## Goal 

- [X] Replace `pre` with Zig so we can perform `repl/scripts` with guaranteed memory safety. 
    - Such cases as avoiding buffer overflow
- [X] Optional standard library (ability to be ran with `nostd`)
  - Use the option: `-Dnostd`
- [ ] Standard Libary with following: 
  - [ ] Write/Read file in cwd 
  - [ ] Type Conversions
  - [ ] Run process commands 

---

## Ziggified 
- **Scanner**
  - The scanner which is responsible for tokenizing a string is now completely written in Zig, and exported to C. 
  - Is built as a shared library `libMufiZ_scanner` and linked before the C files. 
  - The reason this was moved first, as its the least dependent part of the compiler, so there is not 
  too much breakage when moving it (only had to care about `compiler.c`). 
  - Any function that would interfere with another function, was prefixed with `__scanner__`
    - Might consider prefixing all functions of scanner with this. 

---


