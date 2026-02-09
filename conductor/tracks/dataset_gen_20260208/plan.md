# Implementation Plan - Large-Scale Dataset Generation

This plan follows the spec-driven development workflow, focusing on a standalone Python utility.

## Phase 1: Core Generation Logic

- [~] **Task: Develop Python PEG Parser/Generator**
    - [~] Create `tools/mufiz_dataset_gen.py`.
    - [ ] Implement a basic recursive-descent generator in Python that reads `docs/grammar.peg` (or uses a hardcoded rule-set based on it).
    - [ ] Add support for "variety generators" (random math, matrix, and string operations).

- [ ] **Task: Functional Validation Bridge**
    - [ ] Implement logic to call the local `mufiz` binary with a generated script.
    - [ ] Handle exit codes and stderr to filter out invalid programs.

- [ ] **Task: Conductor - User Manual Verification 'Phase 1: Core Generation Logic' (Protocol in workflow.md)**

## Phase 2: Scale and Git Automation

- [ ] **Task: Parallelize Generation Engine**
    - [ ] Implement `multiprocessing.Pool` to run generation and validation in parallel.
    - [ ] Add progress tracking and a resumption mechanism using a local state file.

- [ ] **Task: Implement Automated Git Lifecycle**
    - [ ] Add logic to initialize a target directory as a Git repository.
    - [ ] Implement batch commit logic (e.g., commit every 1,000 files).

- [ ] **Task: Conductor - User Manual Verification 'Phase 2: Scale and Git Automation' (Protocol in workflow.md)**

## Phase 3: Archiving and Final Validation

- [ ] **Task: Create Archiving Utility**
    - [ ] Create `tools/archive_dataset.sh`.
    - [ ] Ensure it correctly packages the entire generated repository while excluding unnecessary temp files.

- [ ] **Task: Stress Test and Final Dataset Run**
    - [ ] Run a test generation of 10,000 files to verify performance and Git stability.
    - [ ] Final check of syntax coverage across a sample of the generated files.

- [ ] **Task: Conductor - User Manual Verification 'Phase 3: Archiving and Final Validation' (Protocol in workflow.md)**
