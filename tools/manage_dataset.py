#!/usr/bin/env python3
"""
MuFi Dataset Manager
====================
Tool for generating, managing, and archiving large-scale MuFi datasets.

Features:
- Efficient 100K+ dataset generation
- Separate git repository management
- Automatic archiving and compression
- Progress tracking and resumption
- Metadata and statistics
"""

import argparse
import json
import multiprocessing
import os
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile
from datetime import datetime
from pathlib import Path

# Import the generator
sys.path.insert(0, os.path.dirname(__file__))
from mufiz_dataset_gen import MufiGenerator, validate_script


class DatasetManager:
    """Manages dataset generation, versioning, and archiving."""

    def __init__(self, dataset_dir, mufiz_bin):
        self.dataset_dir = Path(dataset_dir)
        self.mufiz_bin = mufiz_bin
        self.metadata_file = self.dataset_dir / "metadata.json"
        self.programs_dir = self.dataset_dir / "programs"

    def initialize_repo(self, target_count):
        """Initialize a new dataset repository."""
        print(f"Initializing dataset repository at {self.dataset_dir}...")

        # Create directory structure
        self.dataset_dir.mkdir(parents=True, exist_ok=True)
        self.programs_dir.mkdir(exist_ok=True)

        # Initialize git
        if not (self.dataset_dir / ".git").exists():
            self._run_git(["init"])
            print("✓ Git repository initialized")

        # Create .gitignore
        gitignore_content = """# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info/
dist/
build/

# Dataset archives
*.tar.gz
*.tar.bz2
*.tar.xz
*.zip

# Temporary files
*.tmp
temp_*
.DS_Store
"""
        with open(self.dataset_dir / ".gitignore", "w") as f:
            f.write(gitignore_content)

        # Create README
        readme_content = f"""# MuFi-Lang Synthetic Dataset

A large-scale dataset of valid MuFi programs for neural network training and compiler testing.

## Dataset Information

- **Target Size**: {target_count:,} programs
- **Generated**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
- **Format**: `.mufi` source files
- **Validation**: All programs are syntactically and semantically valid

## Structure

```
.
├── programs/          # All generated .mufi files
│   ├── prog_0.mufi
│   ├── prog_1.mufi
│   └── ...
├── metadata.json      # Dataset statistics and metadata
├── README.md          # This file
└── .gitignore        # Git ignore rules
```

## Usage

### Loading Programs

```python
from pathlib import Path

dataset_dir = Path(".")
programs = list((dataset_dir / "programs").glob("*.mufi"))

for prog_file in programs:
    with open(prog_file) as f:
        code = f.read()
    # Process code...
```

### Running Programs

```bash
# Run a single program
mufiz -r programs/prog_0.mufi

# Run all programs
for f in programs/*.mufi; do
    mufiz -r "$f"
done
```

## Statistics

See `metadata.json` for detailed statistics including:
- Total program count
- Generation time and rate
- Feature distribution
- Complexity metrics

## Archiving

To create compressed archives:

```bash
# Create tar.gz archive
tar -czf mufiz-dataset.tar.gz programs/

# Create zip archive
zip -r mufiz-dataset.zip programs/
```

Or use the provided management tool:

```bash
python3 manage_dataset.py archive --format all
```

## Quality Assurance

All programs in this dataset:
- ✅ Parse successfully (no syntax errors)
- ✅ Type-check correctly (no type errors)
- ✅ Execute without runtime errors
- ✅ Terminate properly (no infinite loops)
- ✅ Follow the official MuFi PEG grammar

## License

This dataset is part of the MufiZ project.

## Citation

If you use this dataset in your research, please cite:

```bibtex
@dataset{{mufiz_synthetic_dataset,
  title={{MuFi-Lang Synthetic Dataset}},
  author={{MufiZ Project}},
  year={{{datetime.now().year}}},
  url={{https://github.com/mustafif/MufiZ}}
}}
```
"""
        with open(self.dataset_dir / "README.md", "w") as f:
            f.write(readme_content)

        # Initialize metadata
        metadata = {
            "target_count": target_count,
            "current_count": 0,
            "created_at": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "generation_sessions": [],
            "total_generation_time": 0,
            "statistics": {
                "total_functions": 0,
                "total_statements": 0,
                "avg_program_size": 0,
            },
        }
        self._save_metadata(metadata)

        # Initial commit
        self._run_git(["add", ".gitignore", "README.md", "metadata.json"])
        self._run_git(["commit", "-m", "Initial commit: Initialize dataset repository"])

        print(f"✓ Repository initialized at {self.dataset_dir}")

    def generate(self, count, cores, batch_size, resume=False):
        """Generate programs for the dataset."""
        metadata = self._load_metadata()
        current_count = metadata["current_count"]

        if resume and current_count > 0:
            print(f"Resuming generation from {current_count} programs...")
            remaining = count - current_count
            if remaining <= 0:
                print(f"✓ Target already reached ({current_count}/{count})")
                return
            count = remaining
            start_idx = current_count
        else:
            start_idx = 0
            if current_count > 0 and not resume:
                print(
                    f"Warning: Dataset already has {current_count} programs. Use --resume to continue."
                )
                response = input(
                    "Start fresh? This will delete existing programs. [y/N]: "
                )
                if response.lower() != "y":
                    print("Aborted.")
                    return
                # Clean programs directory
                for f in self.programs_dir.glob("*.mufi"):
                    f.unlink()
                metadata["current_count"] = 0
                metadata["generation_sessions"] = []
                start_idx = 0

        session_start = time.time()
        session_id = datetime.now().isoformat()

        print(f"\nGenerating {count:,} programs...")
        print(f"Using {cores} cores in batches of {batch_size}")
        print(f"Output: {self.programs_dir}\n")

        total_generated = 0
        num_batches = (count + batch_size - 1) // batch_size

        pool = multiprocessing.Pool(cores)

        try:
            for b in range(num_batches):
                batch_start = time.time()
                current_batch_target = min(batch_size, count - total_generated)
                per_worker = current_batch_target // cores
                remainder = current_batch_target % cores

                worker_args = []
                curr_idx = start_idx + total_generated
                for i in range(cores):
                    worker_count = per_worker + (1 if i < remainder else 0)
                    if worker_count > 0:
                        worker_args.append(
                            (
                                worker_count,
                                self.mufiz_bin,
                                str(self.programs_dir),
                                curr_idx,
                                False,
                            )
                        )
                        curr_idx += worker_count

                results = pool.map(self._worker_wrapper, worker_args)
                batch_generated = sum(results)
                total_generated += batch_generated

                # Update metadata
                metadata["current_count"] = start_idx + total_generated
                metadata["last_updated"] = datetime.now().isoformat()
                self._save_metadata(metadata)

                # Git commit
                self._run_git(["add", "programs/"])
                self._run_git(
                    [
                        "commit",
                        "-m",
                        f"Add batch {b + 1}/{num_batches}: {metadata['current_count']:,} total programs",
                    ]
                )

                batch_time = time.time() - batch_start
                elapsed = time.time() - session_start
                rate = total_generated / elapsed if elapsed > 0 else 0
                eta = (count - total_generated) / rate if rate > 0 else 0

                print(f"\nBatch {b + 1}/{num_batches} completed in {batch_time:.1f}s")
                print(
                    f"Progress: {metadata['current_count']:,}/{metadata['target_count']:,} "
                    f"({(metadata['current_count'] / metadata['target_count']) * 100:.1f}%)"
                )
                print(f"Rate: {rate:.1f} files/sec | ETA: {eta / 60:.1f} minutes\n")

        finally:
            pool.close()
            pool.join()

        session_time = time.time() - session_start

        # Update final metadata
        metadata["generation_sessions"].append(
            {
                "session_id": session_id,
                "programs_generated": total_generated,
                "duration_seconds": session_time,
                "rate": total_generated / session_time if session_time > 0 else 0,
            }
        )
        metadata["total_generation_time"] += session_time
        metadata["last_updated"] = datetime.now().isoformat()

        # Calculate statistics
        self._update_statistics(metadata)
        self._save_metadata(metadata)

        # Final commit
        self._run_git(["add", "metadata.json"])
        self._run_git(
            [
                "commit",
                "-m",
                f"Update metadata: {metadata['current_count']:,} total programs",
            ]
        )

        print(f"\n{'=' * 60}")
        print(f"Generation session complete!")
        print(f"{'=' * 60}")
        print(f"Programs generated: {total_generated:,}")
        print(f"Total in dataset: {metadata['current_count']:,}")
        print(f"Session time: {session_time / 60:.1f} minutes")
        print(f"Average rate: {total_generated / session_time:.1f} files/sec")
        print(f"{'=' * 60}\n")

    def archive(self, format_type="all", output_dir=None):
        """Create compressed archives of the dataset."""
        if output_dir is None:
            output_dir = self.dataset_dir.parent
        else:
            output_dir = Path(output_dir)
            output_dir.mkdir(parents=True, exist_ok=True)

        metadata = self._load_metadata()
        dataset_name = f"mufiz-dataset-{metadata['current_count']}"
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        archives_created = []

        # Create tar.gz
        if format_type in ["tar.gz", "all"]:
            print("Creating tar.gz archive...")
            archive_path = output_dir / f"{dataset_name}_{timestamp}.tar.gz"
            with tarfile.open(archive_path, "w:gz") as tar:
                tar.add(self.programs_dir, arcname="programs")
                tar.add(self.metadata_file, arcname="metadata.json")
                tar.add(self.dataset_dir / "README.md", arcname="README.md")
            archives_created.append(archive_path)
            print(
                f"✓ Created: {archive_path} ({self._format_size(archive_path.stat().st_size)})"
            )

        # Create tar.xz (better compression)
        if format_type in ["tar.xz", "all"]:
            print("Creating tar.xz archive (maximum compression)...")
            archive_path = output_dir / f"{dataset_name}_{timestamp}.tar.xz"
            with tarfile.open(archive_path, "w:xz") as tar:
                tar.add(self.programs_dir, arcname="programs")
                tar.add(self.metadata_file, arcname="metadata.json")
                tar.add(self.dataset_dir / "README.md", arcname="README.md")
            archives_created.append(archive_path)
            print(
                f"✓ Created: {archive_path} ({self._format_size(archive_path.stat().st_size)})"
            )

        # Create zip
        if format_type in ["zip", "all"]:
            print("Creating zip archive...")
            archive_path = output_dir / f"{dataset_name}_{timestamp}.zip"
            with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as zipf:
                for file in self.programs_dir.glob("*.mufi"):
                    zipf.write(file, arcname=f"programs/{file.name}")
                zipf.write(self.metadata_file, arcname="metadata.json")
                zipf.write(self.dataset_dir / "README.md", arcname="README.md")
            archives_created.append(archive_path)
            print(
                f"✓ Created: {archive_path} ({self._format_size(archive_path.stat().st_size)})"
            )

        print(f"\n{'=' * 60}")
        print(f"Archive Summary")
        print(f"{'=' * 60}")
        for archive in archives_created:
            print(f"  {archive.name}")
            print(f"  Size: {self._format_size(archive.stat().st_size)}")
            print()
        print(f"Total archives: {len(archives_created)}")
        print(f"Output directory: {output_dir}")
        print(f"{'=' * 60}\n")

        return archives_created

    def status(self):
        """Show dataset status and statistics."""
        if not self.metadata_file.exists():
            print("No dataset found. Use 'init' to create one.")
            return

        metadata = self._load_metadata()

        print(f"\n{'=' * 60}")
        print(f"Dataset Status")
        print(f"{'=' * 60}")
        print(f"Location: {self.dataset_dir}")
        print(f"Programs: {metadata['current_count']:,} / {metadata['target_count']:,}")
        print(
            f"Progress: {(metadata['current_count'] / metadata['target_count']) * 100:.1f}%"
        )
        print(f"Created: {metadata['created_at']}")
        print(f"Last Updated: {metadata['last_updated']}")
        print(
            f"\nTotal Generation Time: {metadata['total_generation_time'] / 60:.1f} minutes"
        )

        if metadata["generation_sessions"]:
            print(f"\nGeneration Sessions: {len(metadata['generation_sessions'])}")
            for i, session in enumerate(metadata["generation_sessions"][-5:], 1):
                print(
                    f"  Session {i}: {session['programs_generated']:,} programs "
                    f"@ {session['rate']:.1f} files/sec"
                )

        stats = metadata.get("statistics", {})
        if stats:
            print(f"\nStatistics:")
            print(f"  Total Functions: {stats.get('total_functions', 0):,}")
            print(f"  Total Statements: {stats.get('total_statements', 0):,}")
            print(f"  Avg Program Size: {stats.get('avg_program_size', 0):.1f} lines")

        # Disk usage
        total_size = sum(f.stat().st_size for f in self.programs_dir.glob("*.mufi"))
        print(f"\nDisk Usage: {self._format_size(total_size)}")
        print(f"{'=' * 60}\n")

    def validate(self, sample_size=None):
        """Validate programs in the dataset."""
        programs = list(self.programs_dir.glob("*.mufi"))
        total = len(programs)

        if sample_size:
            import random

            programs = random.sample(programs, min(sample_size, total))
            print(f"Validating {len(programs)} random programs (sample)...")
        else:
            print(f"Validating all {total:,} programs...")

        valid = 0
        invalid = []

        for i, prog_file in enumerate(programs, 1):
            with open(prog_file) as f:
                code = f.read()

            if validate_script(self.mufiz_bin, code, debug=False):
                valid += 1
            else:
                invalid.append(prog_file.name)

            if i % 100 == 0:
                print(f"  Validated {i}/{len(programs)} ({valid}/{i} valid)")

        print(f"\n{'=' * 60}")
        print(f"Validation Results")
        print(f"{'=' * 60}")
        print(f"Total: {len(programs):,}")
        print(f"Valid: {valid:,} ({(valid / len(programs)) * 100:.1f}%)")
        print(f"Invalid: {len(invalid):,}")

        if invalid:
            print(f"\nInvalid programs:")
            for name in invalid[:10]:
                print(f"  - {name}")
            if len(invalid) > 10:
                print(f"  ... and {len(invalid) - 10} more")

        print(f"{'=' * 60}\n")

        return valid == len(programs)

    def _worker_wrapper(self, args):
        """Wrapper for worker function."""
        from mufiz_dataset_gen import worker

        return worker(args)

    def _run_git(self, cmd):
        """Run a git command."""
        subprocess.run(
            ["git"] + cmd, cwd=self.dataset_dir, capture_output=True, check=False
        )

    def _load_metadata(self):
        """Load metadata from JSON file."""
        if self.metadata_file.exists():
            with open(self.metadata_file) as f:
                return json.load(f)
        return {}

    def _save_metadata(self, metadata):
        """Save metadata to JSON file."""
        with open(self.metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)

    def _update_statistics(self, metadata):
        """Update dataset statistics."""
        programs = list(self.programs_dir.glob("*.mufi"))
        if not programs:
            return

        total_lines = 0
        total_functions = 0
        total_statements = 0

        # Sample programs for statistics (to avoid reading all 100K files)
        sample_size = min(1000, len(programs))
        import random

        sample = random.sample(programs, sample_size)

        for prog_file in sample:
            with open(prog_file) as f:
                content = f.read()
                lines = content.count("\n")
                total_lines += lines
                total_functions += content.count("fun ")
                total_statements += content.count(";")

        # Extrapolate to full dataset
        scale = len(programs) / sample_size
        metadata["statistics"] = {
            "total_functions": int(total_functions * scale),
            "total_statements": int(total_statements * scale),
            "avg_program_size": total_lines / sample_size,
        }

    @staticmethod
    def _format_size(bytes_size):
        """Format bytes to human-readable size."""
        for unit in ["B", "KB", "MB", "GB"]:
            if bytes_size < 1024.0:
                return f"{bytes_size:.2f} {unit}"
            bytes_size /= 1024.0
        return f"{bytes_size:.2f} TB"


def main():
    parser = argparse.ArgumentParser(
        description="MuFi Dataset Manager - Generate, manage, and archive datasets",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Initialize new dataset
  python3 manage_dataset.py init --target 100000 --dir ../mufiz-dataset

  # Generate programs
  python3 manage_dataset.py generate --count 100000 --cores 8

  # Resume interrupted generation
  python3 manage_dataset.py generate --count 100000 --resume

  # Check status
  python3 manage_dataset.py status

  # Validate dataset
  python3 manage_dataset.py validate --sample 1000

  # Create archives
  python3 manage_dataset.py archive --format all
  python3 manage_dataset.py archive --format tar.xz --output ~/archives
        """,
    )

    parser.add_argument(
        "command",
        choices=["init", "generate", "status", "validate", "archive"],
        help="Command to execute",
    )
    parser.add_argument(
        "--dir",
        type=str,
        default="../mufiz-dataset",
        help="Dataset directory (default: ../mufiz-dataset)",
    )
    parser.add_argument(
        "--mufiz",
        type=str,
        default="./zig-out/bin/mufiz",
        help="Path to mufiz binary",
    )
    parser.add_argument(
        "--target",
        type=int,
        default=100000,
        help="Target number of programs (for init)",
    )
    parser.add_argument(
        "--count", type=int, default=100000, help="Number of programs to generate"
    )
    parser.add_argument(
        "--cores",
        type=int,
        default=multiprocessing.cpu_count(),
        help="CPU cores to use",
    )
    parser.add_argument(
        "--batch", type=int, default=1000, help="Batch size for generation"
    )
    parser.add_argument(
        "--resume", action="store_true", help="Resume interrupted generation"
    )
    parser.add_argument(
        "--format",
        choices=["tar.gz", "tar.xz", "zip", "all"],
        default="all",
        help="Archive format",
    )
    parser.add_argument("--output", type=str, help="Output directory for archives")
    parser.add_argument(
        "--sample", type=int, help="Sample size for validation (default: all)"
    )

    args = parser.parse_args()

    # Verify mufiz binary exists
    if not os.path.exists(args.mufiz):
        print(f"Error: MuFi binary not found at {args.mufiz}")
        print("Please build MuFi first or specify correct path with --mufiz")
        return 1

    manager = DatasetManager(args.dir, args.mufiz)

    if args.command == "init":
        manager.initialize_repo(args.target)

    elif args.command == "generate":
        if not manager.metadata_file.exists():
            print("Dataset not initialized. Run 'init' first.")
            return 1
        manager.generate(args.count, args.cores, args.batch, args.resume)

    elif args.command == "status":
        manager.status()

    elif args.command == "validate":
        if not manager.metadata_file.exists():
            print("Dataset not initialized.")
            return 1
        success = manager.validate(args.sample)
        return 0 if success else 1

    elif args.command == "archive":
        if not manager.metadata_file.exists():
            print("Dataset not initialized.")
            return 1
        manager.archive(args.format, args.output)

    return 0


if __name__ == "__main__":
    exit(main())
