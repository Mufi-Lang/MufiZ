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

---

## Installation

### Deb Package

```shell
$ sudo dpkg -i mufiz_{version}_{target}.deb
```

## APT

We host our official APT repository on Github on the [MufiZ-APT](https://github.com/Mustafif/MufiZ-APT) repository. To install using `apt` follow the instructions below:

```bash
$ echo "deb [arch= {arch}, trusted=yes] https://mustafif.github.io/Mufi-APT mufiz main" | sudo tee /etc/apt/sources.list.d/mufiz.list
$ sudo apt update && sudo apt upgrade
$ sudo apt install mufiz
```

Where `{arch}` is the architecture of your system.

Supported architectures are:

- amd64
- arm64
- mipsel
- mips64el
- mips64
- mips
- powerpc
- powerpc64
- powerpc64le
- riscv64

### RPM Package

```shell
$ sudo rpm -i mufiz_{version}_{target}.rpm
```

### Linux/MacOS Zip

```shell
$ unzip mufiz_{version}_{target}.zip
$ mv mufiz /usr/local/bin
```

### Windows

- Download the `mufiz_{version}_{target}.zip` file from the releases page.
- Extract the zip file to a directory of your choice.
- Add the directory to your PATH environment variable.
- Open a new terminal and run `mufiz --version` to verify the installation.

---

## Goal

> View [MufiZ Project Roadmap](https://github.com/users/Mustafif/projects/1) to see current goals I am currently working on or planning to implement for the current or next versions. 

---

## Releases

| Version | Codename                                                                 | Status      |
| ------- | ------------------------------------------------------------------------ | ----------- |
| 0.1.0   | Baloo                                                                    | Archived    |
| 0.2.0   | [Zula](https://github.com/Mustafif/MufiZ/releases/tag/v0.2.0)            | Released    |
| 0.3.0   | [Iris](https://github.com/Mustafif/MufiZ/releases/tag/v0.3.0)            | Released    |
| 0.4.0   | [Voxl](https://github.com/Mustafif/MufiZ/releases/tag/v0.4.0)            | Released    |
| 0.5.0   | [Luna](https://github.com/Mustafif/MufiZ/releases/tag/v0.5.0)            | Released    |
| 0.6.0   | [Mars](https://github.com/Mustafif/MufiZ/releases/tag/next-experimental) | In Progress |

---

## Features

To support various toolchains, we have added the following features to the project, which can be enabled or disabled using the `zig build` command:

- `-Denable_net` - Enables the `net` module for the MufiZ standard library.
- `-Denable_fs` - Enables the `fs` module for the MufiZ standard library.
