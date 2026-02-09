# Specification - Large-Scale Neural Network Dataset Generation

## Overview
This track involves creating a standalone Python utility to generate a high-quality dataset of 100,000 valid Mufi-Lang programs for neural network training. The utility will orchestrate a multi-stage pipeline: generating code based on the formal PEG grammar, validating it via the `mufiz` compiler/VM, and managing the resulting data in a dedicated Git repository.

## Functional Requirements

### 1. Standalone Generation Orchestrator
- **Implementation:** A Python 3 script located in `tools/mufiz_dataset_gen.py`.
- **Pipeline Workflow:**
    1. **Syntactic Generation:** Produce Mufi code snippets that strictly adhere to `docs/grammar.peg`.
    2. **Functional Validation:** Call the `mufiz` binary to compile and execute each snippet. Only those with a zero exit code are accepted.
- **Dataset Variety:** 
    - Full coverage of all grammar rules.
    - Support for deeply nested blocks (loops, conditionals).
    - Randomized inclusion of standard library calls (matrix operations, math, etc.).

### 2. Dataset Repository Management
- **Git Automation:** The script will:
    - Initialize a new Git repository in a target directory.
    - Automate batch commits (e.g., every 1,000 successful files) to maintain repository performance.
- **Flat Organization:** All 100,000 files will be stored in a single flat directory within the new repository.

### 3. High-Performance Execution
- **Parallelization:** Utilize Python's `multiprocessing` to run generation and `mufiz` validation tasks across all available CPU cores.
- **Resumption:** Ability to track progress and resume from the last successful batch if interrupted.

### 4. Archiving and Portability
- **Shell Script:** A companion script `tools/archive_dataset.sh` to create a compressed `.tar.gz` of the generated repository.

## Technical Requirements
- **Dependencies:** Python 3.x, `git` CLI, and a compiled `mufiz` binary.
- **Output:** A standalone directory containing a `.git` folder and 100,000 `.mufi` files.

## Acceptance Criteria
- [ ] `tools/mufiz_dataset_gen.py` successfully generates 100,000 unique, valid `.mufi` files.
- [ ] Every file in the output repository passes `mufiz` compilation.
- [ ] The output is a functional, independent Git repository with batched history.
- [ ] `tools/archive_dataset.sh` successfully produces a portable compressed archive.
- [ ] Generation utilizes multi-core processing effectively.

## Out of Scope
- Integrating generation logic directly into the Zig `mufiz` binary.
- Training or testing neural network models.
