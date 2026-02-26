# Plan: Advanced Dependency Management

This plan outlines the enhancements to the MufiZ Package Manager and Module System to support industrial-grade dependency management.

## 1. Transitive Dependency Resolution in `pm.run`
**Goal**: Ensure that when a project is run, all nested dependencies (dependencies of dependencies) are correctly registered in the `module_registry`.

### Tasks
- [x] Refactor `pm.install` recursive logic into a reusable `resolveAllDependencies` function.
- [x] Update `pm.run` to use `resolveAllDependencies` to populate the `module_registry` dependency map.
- [x] Verify with a test case involving 3 levels of depth (App -> LibA -> LibB).

## 2. Global Namespace Protection (Namespace Isolation)
**Goal**: Prevent name collisions in the global scope when importing multiple dependencies.

### Tasks
- [x] Modify `VM` to support "namespaced globals" or implement a state snapshotting mechanism during `loadFile`.
- [x] Update `module_registry.populateModuleMembers` to only extract symbols defined during that specific file's execution.
- [x] Add a test case where two different dependencies export functions with the same name.

## 3. Reproducible Builds (Lockfile)
**Goal**: Ensure consistent builds across different environments by locking dependency versions to specific hashes.

### Tasks
- [x] Design the `mufi.lock` ZON/JSON format.
- [x] Update `pm.install` to generate/update `mufi.lock` after successful resolution.
- [x] Update `pm.install` and `pm.run` to prefer `mufi.lock` over `mufi.zon` when it exists.
- [x] Implement `mufiz pm update` to refresh the lockfile.

## 4. Semantic Versioning (SemVer) Support
**Goal**: Allow flexible but safe version constraints in `mufi.zon`.

### Tasks
- [x] Implement or integrate a SemVer parser in Zig.
- [x] Update `resolver.zig` to handle ranges (e.g., `^1.0.0`, `~2.1.0`).
- [x] Add conflict detection logic when multiple versions of the same package are requested.

## Current Progress
- [x] Phase 1: Transitive Resolution
- [x] Phase 2: Namespace Isolation
- [x] Phase 3: Lockfile implementation
- [x] Phase 4: SemVer Support