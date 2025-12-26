#!/usr/bin/env python3
"""
Script to find unused files in the src/ directory of a Zig project.
Analyzes @import statements to build a dependency graph and identifies orphaned files.
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set


class ZigDependencyAnalyzer:
    def __init__(self, src_dir: str):
        self.src_dir = Path(src_dir).resolve()
        self.all_files: Set[Path] = set()
        self.imports: Dict[Path, Set[str]] = {}
        self.used_files: Set[Path] = set()

    def scan_zig_files(self) -> None:
        """Recursively scan for all .zig files in src directory."""
        for zig_file in self.src_dir.rglob("*.zig"):
            if zig_file.is_file():
                self.all_files.add(zig_file.resolve())

        print(f"Found {len(self.all_files)} .zig files in {self.src_dir}")

    def extract_imports(self, file_path: Path) -> Set[str]:
        """Extract all @import statements from a Zig file."""
        imports = set()

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()

            # Match only @import("filename") patterns - be more restrictive
            # This regex looks for @import followed by parentheses with a quoted string
            import_pattern = r'@import\s*\(\s*"([^"]+)"\s*\)'
            matches = re.findall(import_pattern, content)

            for match in matches:
                # Filter out built-in imports and external dependencies
                if (
                    not match.startswith("std.")
                    and not match == "std"
                    and match
                    not in [
                        "builtin",
                        "clap",
                        "features",
                        "debug",
                    ]
                ):
                    imports.add(match)

        except (IOError, UnicodeDecodeError) as e:
            print(f"Warning: Could not read {file_path}: {e}")

        return imports

    def resolve_import_path(
        self, import_name: str, current_file: Path
    ) -> Optional[Path]:
        """Resolve an import name to an actual file path."""
        current_dir = current_file.parent

        # Handle relative imports
        if import_name.endswith(".zig"):
            # Direct .zig file import
            potential_path = current_dir / import_name
            if potential_path.exists():
                return potential_path.resolve()
        else:
            # Import without .zig extension - add it
            potential_path = current_dir / f"{import_name}.zig"
            if potential_path.exists():
                return potential_path.resolve()

        # Try from src root
        potential_path = self.src_dir / import_name
        if potential_path.exists():
            return potential_path.resolve()

        potential_path = self.src_dir / f"{import_name}.zig"
        if potential_path.exists():
            return potential_path.resolve()

        # Try in subdirectories
        for root, dirs, files in os.walk(self.src_dir):
            root_path = Path(root)

            # Try exact match
            potential_path = root_path / import_name
            if potential_path.exists():
                return potential_path.resolve()

            # Try with .zig extension
            potential_path = root_path / f"{import_name}.zig"
            if potential_path.exists():
                return potential_path.resolve()

        return None

    def build_import_graph(self) -> None:
        """Build a graph of all imports for each file."""
        print("Analyzing imports...")
        for file_path in self.all_files:
            imports = self.extract_imports(file_path)
            self.imports[file_path] = imports

            if imports:
                rel_path = file_path.relative_to(self.src_dir)
                print(f"  {rel_path}: imports {sorted(imports)}")

    def find_used_files(
        self, entry_point: Path, visited: Optional[Set[Path]] = None
    ) -> None:
        """Recursively find all files used starting from entry point."""
        if visited is None:
            visited = set()

        if entry_point in visited:
            return

        visited.add(entry_point)
        self.used_files.add(entry_point)

        # Get imports for this file
        imports = self.imports.get(entry_point, set())

        for import_name in imports:
            resolved_path = self.resolve_import_path(import_name, entry_point)

            if resolved_path and resolved_path in self.all_files:
                self.find_used_files(resolved_path, visited)
            elif not resolved_path:
                rel_entry = entry_point.relative_to(self.src_dir)
                print(
                    f"  Warning: Could not resolve import '{import_name}' in {rel_entry}"
                )

    def find_unused_files(self) -> Set[Path]:
        """Find files that are not used by the main entry point."""
        return self.all_files - self.used_files

    def analyze(self, entry_points: List[str]) -> None:
        """Main analysis function."""
        print("=== Zig Dependency Analysis ===\n")

        # Scan all files
        self.scan_zig_files()
        print()

        # Build import graph
        self.build_import_graph()
        print()

        # Find entry points
        found_entry_points = []
        for entry_point_name in entry_points:
            entry_path = self.src_dir / entry_point_name
            if entry_path.exists():
                found_entry_points.append(entry_path)
                print(f"Found entry point: {entry_path.relative_to(self.src_dir)}")
            else:
                print(f"Warning: Entry point {entry_point_name} not found")

        if not found_entry_points:
            print("No valid entry points found!")
            return

        print()

        # Trace dependencies from entry points
        print("Tracing dependencies from entry points...")
        for entry_point in found_entry_points:
            self.find_used_files(entry_point)

        print(f"\nFound {len(self.used_files)} used files")
        print()

        # Find unused files
        unused_files = self.find_unused_files()

        print("=== RESULTS ===")
        print(f"Total files: {len(self.all_files)}")
        print(f"Used files: {len(self.used_files)}")
        print(f"Unused files: {len(unused_files)}")
        print()

        if unused_files:
            print("🔍 Potentially unused files:")
            for unused_file in sorted(unused_files):
                rel_path = unused_file.relative_to(self.src_dir)
                print(f"  ❌ {rel_path}")

            print("\n⚠️  Note: These files might still be used through:")
            print("   - Dynamic imports or string-based file loading")
            print("   - Conditional compilation")
            print("   - Test files or build scripts")
            print("   - External tools or scripts")
            print("   Please review before deleting!")
        else:
            print("✅ No unused files found!")

        print()
        print("📁 Files in dependency tree:")
        for used_file in sorted(self.used_files):
            rel_path = used_file.relative_to(self.src_dir)
            print(f"  ✅ {rel_path}")


def main():
    # Configuration
    src_dir = "src"
    entry_points = ["main.zig"]  # Can add more entry points if needed

    # Check if src directory exists
    if not os.path.exists(src_dir):
        print(f"❌ Error: {src_dir} directory not found!")
        print("Please run this script from the project root directory.")
        sys.exit(1)

    # Run analysis
    analyzer = ZigDependencyAnalyzer(src_dir)
    analyzer.analyze(entry_points)


if __name__ == "__main__":
    main()
