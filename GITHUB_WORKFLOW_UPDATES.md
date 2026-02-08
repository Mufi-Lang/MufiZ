# GitHub Workflow Updates - Release Artifacts Enhancement

## Overview

The GitHub release workflows have been updated to include C library and WebAssembly artifacts in all releases (both experimental and stable).

## Changes Made

### 1. New Release Script

**File:** `scripts/prepare_release_artifacts.sh`

A new bash script that automates the preparation of additional release artifacts:

- **C Library Package** (`mufiz-c-library-{VERSION}.zip`)
  - Contains `mufiz.h` header file
  - Contains shared library (`libmufiz.so/.dylib/.dll`)
  - Includes comprehensive README with usage examples
  - Auto-detects platform and packages appropriate library

- **WebAssembly Package** (`mufiz-wasm-{VERSION}.zip`)
  - Contains `mufiz.wasm` binary (~305KB compressed)
  - Contains `index.html` web playground
  - Includes full WASM documentation
  - Builds WASM if not already built

- **Artifact Manifest** (`ARTIFACTS.md`)
  - Lists all release files
  - Provides file sizes and checksums (SHA256)
  - Includes installation instructions
  - Auto-generated during release process

### 2. Updated Workflows

#### Experimental Release Workflow
**File:** `.github/workflows/release.yml`

**New Steps Added:**
```yaml
- name: Build WASM
  run: zig build wasm

- name: Get version
  id: get_version
  run: |
    VERSION=$(python3 -c "...")
    echo "VERSION=$VERSION" >> $GITHUB_OUTPUT

- name: Prepare release artifacts
  run: |
    chmod +x scripts/prepare_release_artifacts.sh
    ./scripts/prepare_release_artifacts.sh ${{ steps.get_version.outputs.VERSION }}
```

**Updated Release Files:**
```yaml
files: |
  pkg/*.zip
  pkg/*.deb
  pkg/*.rpm
  pkg/ARTIFACTS.md
```

**Enhanced Summary Output:**
- Now shows version number
- Lists C library and WASM artifacts
- Confirms inclusion in release

#### Main Release Workflow
**File:** `.github/workflows/new_release.yml`

**Same updates as experimental workflow:**
- WASM build step
- Version extraction
- Artifact preparation
- Updated file patterns

### 3. Documentation

#### New Documentation Files

1. **`C_API_GUIDE.md`** (774 lines)
   - Complete C API reference
   - Installation instructions
   - Quick start examples
   - Advanced usage patterns
   - Multi-language FFI examples (C++, Rust, Python)
   - Troubleshooting guide

2. **`WASM_PLAYGROUND.md`** (280 lines)
   - WebAssembly usage guide
   - Quick start instructions
   - Supported features list
   - Known limitations
   - Technical implementation details
   - Performance benchmarks

3. **`RELEASE_TEMPLATE.md`** (242 lines)
   - Template for release announcements
   - Includes all artifact types
   - Platform support matrix
   - Installation instructions per platform
   - Developer integration examples

4. **`GITHUB_WORKFLOW_UPDATES.md`** (This file)
   - Summary of workflow changes
   - Usage instructions
   - Testing procedures

## Artifact Details

### C Library Package Structure
```
mufiz-c-library-{VERSION}.zip
├── c-library/
│   ├── mufiz.h              # C API header
│   ├── libmufiz.so          # Linux shared library
│   │   OR libmufiz.dylib    # macOS shared library
│   │   OR libmufiz.dll      # Windows shared library
│   └── README.md            # Usage documentation
```

**Size:** ~920KB (includes shared library)

**Use Cases:**
- Embedding MufiZ in C/C++ applications
- Creating language bindings
- Integration with existing codebases
- Scripting engine for applications

### WebAssembly Package Structure
```
mufiz-wasm-{VERSION}.zip
├── wasm/
│   ├── mufiz.wasm           # WebAssembly binary
│   ├── index.html           # Web playground interface
│   └── README.md            # WASM documentation
```

**Size:** ~122KB (WASM binary is ~305KB uncompressed)

**Use Cases:**
- Browser-based playground
- Web applications with scripting
- Education and demonstrations
- No-install testing environment

### Artifact Manifest
```
ARTIFACTS.md
```

**Contents:**
- List of all release packages
- File sizes for each artifact
- SHA256 checksums for verification
- Platform-specific installation instructions
- Links to documentation

## Workflow Execution Flow

### Experimental Release (Next Branch)

```
Push to 'next' branch
    ↓
Run test suite (REQUIRED)
    ↓
Build multi-platform binaries (build_multi.zig)
    ↓
Build WASM module (zig build wasm)
    ↓
Create standard packages (pkgman.py)
    ↓
Prepare additional artifacts (prepare_release_artifacts.sh)
    ↓
Delete previous experimental releases
    ↓
Create new experimental release with all artifacts
    ↓
Upload artifacts to GitHub Release
```

### Main Release (Main Branch)

```
Push to 'main' branch
    ↓
Build multi-platform binaries
    ↓
Build WASM module
    ↓
Create standard packages
    ↓
Prepare additional artifacts
    ↓
Create draft release with all artifacts
    ↓
Upload to GitHub Release (draft)
    ↓
Upload to packagecloud (deb/rpm)
```

## Testing the Workflow

### Local Testing

1. **Test artifact preparation:**
   ```bash
   ./scripts/prepare_release_artifacts.sh 0.11.0
   ```

2. **Verify artifacts created:**
   ```bash
   ls -lh pkg/
   # Should show:
   # - mufiz-c-library-0.11.0.zip
   # - mufiz-wasm-0.11.0.zip
   # - ARTIFACTS.md
   ```

3. **Test C library package:**
   ```bash
   unzip pkg/mufiz-c-library-0.11.0.zip
   cd c-library
   # Verify files exist:
   ls -l mufiz.h libmufiz.* README.md
   ```

4. **Test WASM package:**
   ```bash
   unzip pkg/mufiz-wasm-0.11.0.zip
   cd wasm
   python3 -m http.server 8000
   # Open http://localhost:8000 and test playground
   ```

### CI/CD Testing

1. **Push to `next` branch:**
   ```bash
   git checkout next
   git push origin next
   ```

2. **Monitor workflow:**
   - Go to GitHub Actions tab
   - Check "Next Experimental Releases" workflow
   - Verify all steps complete successfully

3. **Verify release:**
   - Go to Releases page
   - Find experimental release
   - Verify artifacts are attached:
     - Standard packages (zip, deb, rpm)
     - `mufiz-c-library-{VERSION}.zip`
     - `mufiz-wasm-{VERSION}.zip`
     - `ARTIFACTS.md`

4. **Download and test:**
   ```bash
   wget <release-url>/mufiz-c-library-{VERSION}.zip
   wget <release-url>/mufiz-wasm-{VERSION}.zip
   # Test as above
   ```

## Version Extraction

The workflows automatically extract the version from `build.zig.zon`:

```python
VERSION=$(python3 -c "
import re
data = open('build.zig.zon').read()
match = re.search(r'\.version\s*=\s*\"([\d.]+)\"', data)
print(match.group(1) if match else 'unknown')
")
```

This ensures version consistency across all artifacts.

## File Patterns

### Included in Release
```yaml
files: |
  pkg/*.zip      # All zip archives (standard + C lib + WASM)
  pkg/*.deb      # Debian packages
  pkg/*.rpm      # RPM packages
  pkg/ARTIFACTS.md  # Manifest
```

### Excluded from Release
- Temporary build artifacts in `zig-out/`
- Source files
- Test files
- Development tools

## Benefits

### For Users

1. **Easy C Integration**
   - Download one zip file
   - Get header + library + docs
   - Start using immediately

2. **Browser Testing**
   - No installation required
   - Instant playground access
   - Cross-platform compatibility

3. **Complete Documentation**
   - Usage examples for all artifact types
   - Platform-specific instructions
   - Troubleshooting guides

### For Developers

1. **Automated Process**
   - No manual packaging needed
   - Consistent artifact structure
   - Automatic checksums

2. **Version Control**
   - Single source of truth (build.zig.zon)
   - Automatic version propagation
   - Consistent naming

3. **Quality Assurance**
   - Test suite must pass for release
   - All artifacts verified before upload
   - Checksums for integrity

## Maintenance

### Updating the Script

To modify artifact preparation:

1. Edit `scripts/prepare_release_artifacts.sh`
2. Test locally with `./scripts/prepare_release_artifacts.sh <version>`
3. Commit and push changes

### Adding New Artifact Types

To add a new artifact type:

1. Update `prepare_release_artifacts.sh`:
   - Add new packaging section
   - Generate appropriate README
   - Create zip archive

2. Update `ARTIFACTS.md` template:
   - Add description of new artifact
   - Add installation instructions

3. Test thoroughly before merging

### Modifying Documentation

Documentation files are included in packages:
- C library: README generated from template
- WASM: Uses `WASM_PLAYGROUND.md` as README
- Update source files, not generated packages

## Troubleshooting

### Script Fails to Find Files

**Problem:** `mufiz.h not found` or similar

**Solution:**
```bash
# Ensure standard build completes first
zig build
zig build wasm
# Then run artifact script
./scripts/prepare_release_artifacts.sh <version>
```

### Workflow Fails at Artifact Step

**Problem:** Workflow fails at "Prepare release artifacts"

**Check:**
1. Script has execute permissions (chmod +x)
2. All dependencies are installed (zip)
3. Previous build steps succeeded

**Fix:**
```yaml
- name: Install dependencies
  run: sudo apt-get install -y zip
```

### Missing Files in Release

**Problem:** Some artifacts not uploaded

**Check:**
1. File pattern in workflow matches artifact names
2. Artifacts exist in `pkg/` directory
3. No file size limits exceeded

**Fix:** Verify file patterns and artifact generation

## Future Enhancements

### Potential Additions

1. **Static Library Package**
   - Include `.a` files for static linking
   - Add usage instructions

2. **Language-Specific Packages**
   - Python wheel with ctypes bindings
   - Rust crate with FFI bindings
   - Node.js npm package

3. **Docker Images**
   - Containerized runtime
   - Development environment
   - CI/CD integration

4. **Platform-Specific Enhancements**
   - Homebrew formula
   - Chocolatey package
   - Snap package

## Checklist for New Releases

Before creating a release:

- [ ] All tests pass
- [ ] Version updated in `build.zig.zon`
- [ ] CHANGELOG updated
- [ ] Documentation reflects changes
- [ ] Local artifact generation tested
- [ ] C library compiles on target platforms
- [ ] WASM module loads in browser
- [ ] Release notes prepared

During release:

- [ ] Workflow completes successfully
- [ ] All artifacts uploaded
- [ ] Checksums verified
- [ ] Download links work
- [ ] Installation instructions tested

After release:

- [ ] Announcement posted
- [ ] Documentation updated
- [ ] Community notified
- [ ] Feedback monitored

## Contact

For questions or issues with the release process:

- **GitHub Issues:** https://github.com/mustafif/MufiZ/issues
- **Discussions:** https://github.com/mustafif/MufiZ/discussions

---

**Last Updated:** February 8, 2026
**Applies to:** MufiZ v0.11.0+