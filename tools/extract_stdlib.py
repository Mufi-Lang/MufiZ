#!/usr/bin/env python3
"""
Extract standard library function information from MufiZ Zig source code.
This script parses the stdlib modules and generates a JSON file containing
function names and their parameter counts for use in data generation.
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def extract_function_from_define(content: str) -> List[Tuple[str, int, str]]:
    """
    Extract function definitions from DefineFunction declarations.
    Returns list of (function_name, param_count, module_name) tuples.
    """
    functions = []

    # Pattern to match DefineFunction declarations
    # pub const function_name = DefineFunction(
    #     "function_name",
    #     "module",
    #     "description",
    #     params,
    #     ...
    pattern = r'pub\s+const\s+(\w+)\s*=\s*DefineFunction\(\s*"(\w+)",\s*"(\w+)",'

    for match in re.finditer(pattern, content):
        const_name = match.group(1)
        func_name = match.group(2)
        module_name = match.group(3)

        # Find the parameter specification
        # Look for the 4th argument to DefineFunction
        start_pos = match.end()

        # Find the params argument - could be NoParams, OneNumber, TwoNumbers, or an array
        remaining = content[start_pos : start_pos + 1000]

        param_count = 0

        # Check for common patterns
        if "NoParams" in remaining[:200]:
            param_count = 0
        elif "OneNumber" in remaining[:200]:
            param_count = 1
        elif "TwoNumbers" in remaining[:200]:
            param_count = 2
        elif "ThreeNumbers" in remaining[:200]:
            param_count = 3
        else:
            # Look for parameter array specification
            # &[_]ParamSpec{ ... }
            param_array_match = re.search(
                r"&\[_\]ParamSpec\s*{([^}]+)}", remaining[:500]
            )
            if param_array_match:
                # Count the number of ParamSpec entries
                param_specs = param_array_match.group(1)
                # Count occurrences of .name =
                param_count = len(re.findall(r"\.name\s*=", param_specs))

        functions.append((func_name, param_count, module_name))

    return functions


def extract_from_module_file(filepath: Path) -> List[Tuple[str, int, str]]:
    """Extract all functions from a single module file."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        return extract_function_from_define(content)
    except Exception as e:
        print(f"Warning: Could not process {filepath}: {e}", file=sys.stderr)
        return []


def scan_stdlib_directory(stdlib_path: Path) -> Dict[str, Dict[str, int]]:
    """
    Scan the stdlib directory and extract all function information.
    Returns a nested dict: {module_name: {function_name: param_count}}
    """
    all_functions = {}

    if not stdlib_path.exists():
        print(f"Error: stdlib directory not found at {stdlib_path}", file=sys.stderr)
        return all_functions

    # Scan all .zig files in the stdlib directory
    for zig_file in stdlib_path.glob("*.zig"):
        if zig_file.name == "README.md":
            continue

        functions = extract_from_module_file(zig_file)

        for func_name, param_count, module_name in functions:
            if module_name not in all_functions:
                all_functions[module_name] = {}
            all_functions[module_name][func_name] = param_count

    return all_functions


def extract_from_main_stdlib(main_file: Path) -> Dict[str, int]:
    """
    Extract additional functions from stdlib_main.zig that might not be in modules.
    Returns flat dict of {function_name: param_count}
    """
    functions = {}

    try:
        with open(main_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Look for DefineFunction in main file
        extracted = extract_function_from_define(content)
        for func_name, param_count, _ in extracted:
            functions[func_name] = param_count

    except Exception as e:
        print(f"Warning: Could not process {main_file}: {e}", file=sys.stderr)

    return functions


def flatten_functions(nested: Dict[str, Dict[str, int]]) -> Dict[str, int]:
    """Flatten nested function dict to simple {function_name: param_count}."""
    flat = {}
    for module_name, module_funcs in nested.items():
        for func_name, param_count in module_funcs.items():
            flat[func_name] = param_count
    return flat


def main():
    # Determine project root
    script_path = Path(__file__).resolve()
    project_root = script_path.parent.parent

    stdlib_dir = project_root / "src" / "stdlib"
    stdlib_main = project_root / "src" / "stdlib_main.zig"
    output_file = project_root / "tools" / "stdlib_functions.json"

    print(f"Scanning stdlib directory: {stdlib_dir}")
    print(f"Scanning main file: {stdlib_main}")

    # Extract from module files
    module_functions = scan_stdlib_directory(stdlib_dir)

    # Extract from main file
    main_functions = extract_from_main_stdlib(stdlib_main)

    # Combine and flatten
    all_functions = flatten_functions(module_functions)
    all_functions.update(main_functions)

    # Create output structure
    output = {
        "functions": all_functions,
        "by_module": module_functions,
        "total_count": len(all_functions),
    }

    # Write to JSON
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, sort_keys=True)

    print(
        f"\nExtracted {len(all_functions)} functions from {len(module_functions)} modules"
    )
    print(f"Output written to: {output_file}")

    # Print summary by module
    print("\nFunctions by module:")
    for module_name in sorted(module_functions.keys()):
        count = len(module_functions[module_name])
        print(f"  {module_name}: {count} functions")


if __name__ == "__main__":
    main()
