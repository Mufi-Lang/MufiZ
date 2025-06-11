# MufiZ

> This project uses the Zig `v0.13.0`

🌐 [mufi-lang.mokareads.org](https://mufi-lang.mokareads.org)

This project aims to integrate the Mufi-Lang compiler with the Zig language by using the
Zig Build system. We hope to integrate more features with this language and see how nicely
we can utilize both languages in unity. The advantage of Zig's Build system is easy cross-compatibility and caching, and as we integrate more,
we can ensure more memory safety.

## Recent Updates

- **Improved REPL Experience**: The interactive shell now provides a cleaner experience by not echoing characters while typing
- **Simplified Input Handling**: Input is shown after command execution for better readability

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
| 0.6.0   | [Mars](https://github.com/Mustafif/MufiZ/releases/tag/v0.6.0)            | Released    |
| 0.7.0   | [Jade](https://github.com/Mustafif/MufiZ/releases/tag/v0.7.0)            | Released    |
| 0.8.0   | [Ruby](https://github.com/Mustafif/MufiZ/releases/tag/v0.8.0)            | Released    |
| 0.9.0   | [Kova](https://github.com/Mustafif/MufiZ/releases/tag/next-experimental) | In Progress |
| 0.10.0  | [Echo](https://github.com/Mustafif/MufiZ/releases/tag/next-experimental) | In Progress |

---

## Features

To support various toolchains, we have added the following features to the project, which can be enabled or disabled using the `zig build` command:

- `-Denable_net` - Enables the `net` module for the MufiZ standard library.
- `-Denable_fs` - Enables the `fs` module for the MufiZ standard library.
- `-Dsandbox` - Enables sandbox mode which limits execution to REPL only.

### Echo Release Features (v0.10.0)

- **Enhanced REPL Input**: The interactive shell now features improved input handling with non-echoing input for a cleaner experience
- **Input Visibility**: Commands are displayed after execution to maintain clarity and aid debugging
- **Disabled Echo**: Input characters are no longer echoed back while typing in the REPL, improving readability
- **Simplified Implementation**: Streamlined code for better maintainability and performance
- **Terminal Handling**: Groundwork for native Zig termios operations without C dependencies

## Related Repositories

- [homebrew-mufi](https://github.com/Mustafif/homebrew-mufi): The official Homebrew Tap for MufiZ.
- [mufi-bucket](https://github.com/Mustafif/mufi-bucket): The official Scoop bucket for MufiZ.
