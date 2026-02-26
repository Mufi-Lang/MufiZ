# MufiZ Package Manager Refactor Plan

**Status:** Draft
**Goal:** Modernize MufiZ's dependency management by adopting robust patterns from Zig's `Fetch.zig`.

## Overview

The current MufiZ package manager (`src/pm.zig`, `src/cache.zig`) uses a naive approach:
1.  Check if destination exists.
2.  If not, git clone directly to destination.
3.  Resolve only top-level dependencies.

This plan outlines a refactor to improve reliability, performance, and correctness.

## Phase 1: Robust Caching (Atomic Writes)
**Goal:** Prevent corrupted cache states and race conditions.

### Current Problem
If a `git clone` or copy operation is interrupted (Ctrl+C, crash, network failure), the package directory exists but is incomplete. Future runs assume it's valid, leading to build errors.

### Implementation Plan (`src/cache.zig`)
1.  **Temp Directory Strategy**:
    *   Always download/clone into a temporary directory first (e.g., `.mufiz/cache/tmp/pkg-<hash>`).
    *   Perform verification (git checkout, hash check) in this temp dir.
2.  **Atomic Rename**:
    *   Use `std.fs.rename` to move the temp directory to the final cache location (`.mufiz/cache/packages/<hash>`).
    *   This is atomic on POSIX, preventing half-written states.
3.  **Concurrency Safety**:
    *   If the destination exists before rename, assume another process finished it.
    *   Clean up the temp directory.

## Phase 1.5: Enhanced Source Handling (Git & Local)
**Goal:** Robust support for commit hashes and clean local copies.

### Git Improvements
*   **Commit Hash Support:** `git clone --branch` fails for commit hashes.
    *   *New Logic:* Detect if `version` looks like a SHA (40 hex chars).
    *   If SHA: `git init`, `git remote add origin <url>`, `git fetch --depth=1 origin <sha>`, `git checkout FETCH_HEAD`.
    *   If Tag/Branch: Keep existing `git clone --depth=1 --branch`.

### Local Path Improvements
*   **Clean Copy:**
    *   Do NOT blindly copy everything.
    *   **Ignore List:** `.git`, `zig-cache`, `zig-out`, `node_modules`, `.DS_Store`, `.vscode`.
    *   This prevents bloating the cache with large build artifacts and temporary files.

## Phase 2: Recursive Dependency Resolution
**Goal:** Support transitive dependencies (dependencies of dependencies).

### Current Problem
`pm.zig` only reads the root `mufi.zon`. If Library A depends on Library B, the user must manually add Library B to their project, which is fragile.

### Implementation Plan (`src/resolver.zig`, `src/pm.zig`)
1.  **Manifest Parsing**:
    *   After fetching a package, immediately read its `mufi.zon`.
2.  **Graph Expansion**:
    *   Extract dependencies from the fetched package's manifest.
    *   Add them to the `JobQueue` or recursive resolution function.
3.  **Cycle Detection**:
    *   The existing topological sort handles cycles, but the *discovery* phase needs to feed the graph builder recursively.

## Phase 3: Performance (Tarballs & Concurrency)
**Goal:** Speed up installs by avoiding full git history and serial fetches.

### Current Problem
1.  `git clone` is slow and heavy, even with `--depth=1`.
2.  Dependencies are installed one by one.

### Implementation Plan
1.  **Tarball Support**:
    *   Support `http`/`https` URLs pointing to `.tar.gz` or `.zip`.
    *   Use `curl` (since internal `std.http` is disabled) to fetch archives.
    *   Use `tar` to unpack.
    *   GitHub automatically provides tarballs for releases/tags, which are ~10x faster to download than clones.
2.  **Job Queue**:
    *   Implement a `JobQueue` (inspired by `Fetch.zig`) to limit concurrency (e.g., 4 parallel downloads).
    *   Deduplicate requests for the same URL/Version.

## Phase 4: Locking & Reproducibility
**Goal:** Ensure every developer gets the exact same bytes.

### Current Problem
"v1.0.0" is a mutable tag. If a maintainer force-pushes, the cache key (derived from URL+Version) remains the same, but content changes.

### Implementation Plan
1.  **Content Hashing**:
    *   Hash the *contents* of the package, not just the URL/Version.
2.  **Lockfile (`mufi.lock`)**:
    *   Generate a lockfile recording the resolved version and content hash.
    *   Future installs verify the downloaded content matches the lockfile hash.

---

## Action Items (Immediate)

- [ ] **Task 1**: Refactor `src/cache.zig` to use the `download -> temp -> rename` pattern.
- [ ] **Task 2**: Update `src/pm.zig` to queue dependencies recursively.
- [ ] **Task 3**: Add `curl` fallback for tarball support in `src/cache.zig`.
