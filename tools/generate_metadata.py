#!/usr/bin/env python3
import json
import os
import re


def extract_keywords(scanner_path):
    keywords = []
    try:
        with open(scanner_path, "r") as f:
            content = f.read()
            # Look for the keywords array definition
            # const keywords = [_]struct { str: []const u8, tok: TokenType }{
            #     .{ .str = "and", .tok = .TOKEN_AND },
            #     ...
            # };

            # Regex to match the struct entries
            # matches lines like: .{ .str = "and", .tok = .TOKEN_AND },
            pattern = r'\.str\s*=\s*"([^"]+)"\s*,\s*\.tok\s*='
            matches = re.findall(pattern, content)

            if matches:
                keywords = sorted(matches)
                print(f"Found {len(keywords)} keywords")
            else:
                print("Warning: No keywords found in scanner file")

    except FileNotFoundError:
        print(f"Error: Scanner file not found at {scanner_path}")

    return keywords


def extract_stdlib_modules(stdlib_dir):
    modules = {}

    if not os.path.exists(stdlib_dir):
        print(f"Error: Stdlib directory not found at {stdlib_dir}")
        return modules

    for filename in os.listdir(stdlib_dir):
        if not filename.endswith(".zig"):
            continue

        filepath = os.path.join(stdlib_dir, filename)
        module_name = filename[:-4]  # remove .zig

        # We'll rely on the DefineFunction calls to grouping them by the actual reported module name
        # rather than the filename, although they usually match.

        with open(filepath, "r") as f:
            content = f.read()

            # Pattern for DefineFunction
            # pub const ln = DefineFunction(
            #     "ln",
            #     "math",
            #     ...

            # Regex to capture function name and module name from DefineFunction call
            # We look for: DefineFunction(\s*"func_name",\s*"module_name"
            pattern = r'DefineFunction\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"'
            matches = re.findall(pattern, content)

            for func_name, mod_name in matches:
                if mod_name not in modules:
                    modules[mod_name] = []
                modules[mod_name].append(func_name)

    # Sort functions in each module
    for mod in modules:
        modules[mod].sort()

    print(
        f"Found {len(modules)} stdlib modules with {sum(len(f) for f in modules.values())} functions"
    )
    return modules


def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    scanner_path = os.path.join(root_dir, "src", "scanner_optimized.zig")
    stdlib_dir = os.path.join(root_dir, "src", "stdlib")

    # Extract Data
    keywords = extract_keywords(scanner_path)
    stdlib_data = extract_stdlib_modules(stdlib_dir)

    # Write mufiz_keywords.json
    keywords_json_path = os.path.join(root_dir, "mufiz_keywords.json")
    with open(keywords_json_path, "w") as f:
        json.dump({"keywords": keywords}, f, indent=2)
        print(f"Generated {keywords_json_path}")

    # Write mufiz_stdlib.json
    stdlib_json_path = os.path.join(root_dir, "mufiz_stdlib.json")
    with open(stdlib_json_path, "w") as f:
        json.dump({"stdlib": stdlib_data}, f, indent=2)
        print(f"Generated {stdlib_json_path}")


if __name__ == "__main__":
    main()
