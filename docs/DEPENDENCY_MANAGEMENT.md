# MufiZ Dependency Management

**Version:** MufiZ v0.11.0+  
**Status:** Implemented  
**Last Updated:** 2024

---

## Overview

MufiZ includes a built-in dependency management system that allows you to easily add, install, and manage external packages in your projects. The system uses an **ad-hoc resolver** for dependency resolution and **GitHub repositories** as the primary package source.

### Key Features

- 📦 **GitHub-based packages** - Fetch packages directly from GitHub repositories
- 🔄 **Efficient caching** - Content-addressable storage with space optimization
- 🌲 **Shallow clones** - Minimal disk usage with git shallow clones
- 🔗 **Automatic resolution** - Simple topological sort-based dependency resolution
- ♻️ **Shared cache** - Packages downloaded once and shared across projects
- 🛡️ **Circular dependency detection** - Prevents infinite loops

---

## Quick Start

### 1. Add a Dependency

```bash
mufiz pm add http https://github.com/user/mufiz-http v1.0.0
```

This adds the dependency to your `mufi.zon` file.

### 2. Install Dependencies

```bash
mufiz pm install
```

This downloads and caches all dependencies specified in `mufi.zon`.

### 3. Use in Your Code

```mufi
import http;

var client = http.Client.new();
var response = client.get("https://api.example.com");
println(response.body);
```

---

## Configuration Format

### Dependency Specification in `mufi.zon`

Dependencies are specified in the `.dependencies` section of your `mufi.zon` file:

```zon
.{
    .package = .{
        .name = "my-project",
        .version = "0.1.0",
        .authors = .{},
        .description = "My awesome project",
        .license = "MIT",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
    .dependencies = .{
        .http = .{
            .url = "https://github.com/user/mufiz-http",
            .version = "v1.0.0",
        },
        .json = .{
            .url = "https://github.com/user/mufiz-json",
            .version = "v2.1.0",
        },
        .utils = .{
            .url = "https://github.com/org/mufiz-utils",
            .version = "main",
        },
    },
}
```

### Dependency Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `url` | String | GitHub repository URL | `"https://github.com/user/repo"` |
| `version` | String | Git tag, branch, or commit | `"v1.0.0"`, `"main"`, `"abc123"` |

---

## Commands

### Add Dependency

Add a new dependency to your project:

```bash
mufiz pm add <name> <url> <version>
```

**Arguments:**
- `<name>` - Local name for the dependency (used in imports)
- `<url>` - GitHub repository URL
- `<version>` - Git tag, branch, or commit hash

**Examples:**

```bash
# Add a specific version
mufiz pm add http https://github.com/user/mufiz-http v1.0.0

# Use a branch
mufiz pm add utils https://github.com/org/mufiz-utils main

# Use a commit
mufiz pm add experimental https://github.com/dev/test-lib abc123def
```

**What it does:**
- Validates the version format
- Adds the dependency to `mufi.zon`
- Does NOT download yet (run `install` to download)

---

### Install Dependencies

Download and cache all dependencies:

```bash
mufiz pm install
```

**What it does:**
1. Reads dependencies from `mufi.zon`
2. Resolves dependency tree (topological sort)
3. Downloads missing packages from GitHub
4. Caches packages in `~/.mufiz/cache/`
5. Reuses already-cached packages

**Example Output:**

```
📦 Installing dependencies...

📊 Resolved 3 dependencies

📦 Downloading package: http (v1.0.0)
✅ Package cached: http
♻️  Using cached: json (v2.1.0)
♻️  Using cached: utils (main)

✅ All dependencies installed successfully!
```

---

### Cache Management

#### View Cache Info

See statistics about your package cache:

```bash
mufiz pm cache info
```

**Example Output:**

```
📊 Package Cache Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Cached Packages: 5
  Total Size: 12.45 MB
  Cache Location: /Users/username/.mufiz/cache/v1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Clear Cache

Remove all cached packages:

```bash
mufiz pm cache clear
```

**Warning:** This will remove ALL cached packages. They will need to be re-downloaded next time you run `install`.

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Package Manager                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Resolver   │───▶│    Cache     │───▶│   Storage    │  │
│  │  (Ad-hoc)    │    │   Manager    │    │ (~/.mufiz)   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                    │                               │
│         ▼                    ▼                               │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ Topological  │    │   Git Clone  │                       │
│  │     Sort     │    │  (shallow)   │                       │
│  └──────────────┘    └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Resolution

The **ad-hoc resolver** uses a simple but effective algorithm:

1. **Parse** - Read dependencies from `mufi.zon`
2. **Build Graph** - Create dependency graph
3. **Detect Cycles** - Check for circular dependencies
4. **Topological Sort** - Order dependencies (DFS-based)
5. **Install** - Download in resolved order

**Algorithm:** Depth-First Search (DFS) with cycle detection

**Complexity:** O(V + E) where V = packages, E = dependencies

### Caching Strategy

#### Content-Addressable Storage

Each package is stored using a hash of its URL and version:

```
~/.mufiz/cache/v1/
├── packages/
│   ├── a1b2c3d4e5f6.../  (http@v1.0.0)
│   ├── f6e5d4c3b2a1.../  (json@v2.1.0)
│   └── ...
└── git/
```

**Hash Function:** Blake3 (first 16 bytes, hex-encoded)

#### Space Optimization

1. **Shallow Clones** - Only clone with `--depth=1`
2. **No .git Directory** - Remove after clone (saves ~70% space)
3. **Shared Storage** - One copy shared by all projects
4. **Deduplication** - Same package@version never downloaded twice

**Average Space Savings:** ~85% compared to full clones

---

## Dependency Resolution Details

### Version Handling

**Current Implementation:** Exact version matching

- Dependencies must specify exact versions
- No version ranges (yet)
- No semantic versioning constraints (yet)

**Future:** Semantic versioning support planned

### Conflict Resolution

**Current Strategy:** First-come-first-served

- First declared version wins
- Conflicts are reported but not auto-resolved
- Manual intervention required

**Example:**

```zon
.dependencies = .{
    .http = .{ .url = "...", .version = "v1.0.0" },
    .client = .{ 
        .url = "...", 
        .version = "v2.0.0",
        .dependencies = .{
            .http = .{ .version = "v1.5.0" },  // CONFLICT!
        },
    },
}
```

**Output:**

```
⚠️  Version conflict: http requires both v1.0.0 and v1.5.0
```

### Circular Dependency Detection

The resolver detects circular dependencies during resolution:

**Example:**

```
Package A depends on B
Package B depends on C
Package C depends on A  ← Circular!
```

**Output:**

```
❌ Circular dependency detected involving: A
```

---

## Advanced Usage

### Using Git Branches

You can specify branches instead of tags:

```zon
.dependencies = .{
    .experimental = .{
        .url = "https://github.com/user/experimental-lib",
        .version = "main",  // or "develop", "feature-xyz", etc.
    },
}
```

**Note:** Branch-based dependencies can change unexpectedly. Use tags for stability.

### Using Commit Hashes

For maximum reproducibility:

```zon
.dependencies = .{
    .pinned = .{
        .url = "https://github.com/user/lib",
        .version = "abc123def456",  // Full commit hash
    },
}
```

### Private Repositories

**Current Support:** Requires SSH key authentication

1. Set up SSH keys for GitHub
2. Use SSH URLs:

```zon
.dependencies = .{
    .private = .{
        .url = "git@github.com:user/private-repo.git",
        .version = "v1.0.0",
    },
}
```

**Future:** HTTPS with token support planned

---

## Best Practices

### 1. Use Version Tags

✅ **Good:**
```zon
.version = "v1.2.3",
```

❌ **Avoid:**
```zon
.version = "main",  // Can change unexpectedly
```

### 2. Specify Exact Versions

✅ **Good:**
```zon
.http = .{ .url = "...", .version = "v1.0.0" },
```

❌ **Avoid:**
```zon
.http = .{ .url = "...", .version = "latest" },  // Not supported
```

### 3. Keep Dependencies Minimal

Only include what you actually use:

```zon
.dependencies = .{
    // Only include necessary packages
    .json = .{ .url = "...", .version = "v2.0.0" },
}
```

### 4. Regular Updates

Keep dependencies up to date:

```bash
# Update manually by changing versions in mufi.zon
# Then reinstall
mufiz pm install
```

### 5. Cache Management

Periodically clean your cache:

```bash
# Check cache size
mufiz pm cache info

# Clear if needed
mufiz pm cache clear
```

---

## Troubleshooting

### Package Not Found

**Error:**
```
Error: Git clone failed for https://github.com/user/repo@v1.0.0
```

**Solutions:**
1. Verify the URL is correct
2. Check that the version/tag exists
3. Ensure you have network access
4. For private repos, check SSH keys

### Circular Dependency

**Error:**
```
❌ Circular dependency detected involving: package-name
```

**Solution:** Review your dependencies and break the cycle:
- Reorganize code to remove circular references
- Use dependency injection
- Split packages into smaller units

### Version Conflict

**Error:**
```
⚠️  Version conflict: http requires both v1.0.0 and v1.5.0
```

**Solutions:**
1. Update dependencies to use compatible versions
2. Choose one version for all dependents
3. Fork and modify packages if necessary

### Cache Corruption

**Symptoms:**
- Packages fail to load
- Import errors

**Solution:**
```bash
# Clear cache and reinstall
mufiz pm cache clear
mufiz pm install
```

### Disk Space Issues

**Error:**
```
Error: No space left on device
```

**Solution:**
```bash
# Check cache size
mufiz pm cache info

# Clear cache
mufiz pm cache clear

# Reinstall only needed packages
mufiz pm install
```

---

## Implementation Details

### Core Components

#### 1. Cache Manager (`src/cache.zig`)

**Responsibilities:**
- Package storage and retrieval
- Git clone operations
- Space optimization
- Cache statistics

**Key Functions:**
- `cachePackage()` - Download and cache a package
- `isCached()` - Check if package exists in cache
- `getCachedPath()` - Get path to cached package
- `clear()` - Remove all cached packages
- `getStats()` - Calculate cache statistics

#### 2. Dependency Resolver (`src/resolver.zig`)

**Responsibilities:**
- Dependency graph construction
- Topological sorting
- Circular dependency detection
- Version conflict detection

**Key Functions:**
- `addDependency()` - Add package to graph
- `addEdge()` - Add dependency relationship
- `resolve()` - Perform topological sort
- `validate()` - Check graph validity

#### 3. Package Manager (`src/pm.zig`)

**Responsibilities:**
- Command handling
- ZON file manipulation
- Dependency orchestration

**Key Functions:**
- `install()` - Install all dependencies
- `addDependency()` - Add dependency to mufi.zon
- `cacheInfo()` - Display cache statistics
- `cacheClear()` - Clear package cache

---

## Future Enhancements

### Planned Features

#### 1. Semantic Versioning

Support version ranges:

```zon
.dependencies = .{
    .http = .{
        .url = "https://github.com/user/mufiz-http",
        .version = "^1.0.0",  // 1.x.x
    },
}
```

#### 2. Dependency Lockfile

Ensure reproducible builds:

```
mufi.lock
---------
.{
    .packages = .{
        .http = .{
            .url = "...",
            .version = "v1.0.0",
            .hash = "abc123...",
            .resolved = "2024-01-15T10:30:00Z",
        },
    },
}
```

#### 3. Update Command

```bash
# Update all dependencies
mufiz pm update

# Update specific package
mufiz pm update http

# Check for updates
mufiz pm outdated
```

#### 4. Package Registry

Central package index:

```bash
# Search packages
mufiz pm search http

# Install from registry
mufiz pm add http  # Automatically resolves to registry package
```

#### 5. Transitive Dependencies

Automatic resolution of nested dependencies:

```zon
.dependencies = .{
    .client = .{ .url = "...", .version = "v1.0.0" },
    // client's dependencies automatically resolved
}
```

#### 6. Build Scripts

Pre/post install hooks:

```zon
.dependencies = .{
    .native = .{
        .url = "...",
        .version = "v1.0.0",
        .build = "zig build",
    },
}
```

---

## Comparison with Other Package Managers

### vs NPM (Node.js)

| Feature | MufiZ PM | NPM |
|---------|----------|-----|
| Source | GitHub | Registry |
| Lockfile | Planned | ✅ package-lock.json |
| Semver | Planned | ✅ |
| Nested deps | Planned | ✅ |
| Speed | Fast (shallow clone) | Fast (tar.gz) |

### vs Cargo (Rust)

| Feature | MufiZ PM | Cargo |
|---------|----------|-------|
| Source | GitHub | crates.io |
| Lockfile | Planned | ✅ Cargo.lock |
| Semver | Planned | ✅ |
| Build scripts | Planned | ✅ |
| Workspace | Not yet | ✅ |

### vs Zig Package Manager

| Feature | MufiZ PM | Zig PM |
|---------|----------|--------|
| Format | ZON | ZON |
| Source | GitHub | Any URL |
| Hash verify | Planned | ✅ |
| Lazy fetching | No | ✅ |
| Integration | Built-in | Built-in |

---

## FAQ

### Q: Can I use packages from GitLab or BitBucket?

**A:** Not yet. Currently only GitHub is supported. Support for other git hosts is planned.

### Q: How do I specify a subdirectory in a repository?

**A:** Not supported yet. The entire repository is cloned. Monorepo support is planned.

### Q: Can I use local packages?

**A:** Not yet. File path dependencies are planned for development workflows.

### Q: How do I publish a package?

**A:** Simply create a GitHub repository with your MufiZ code. Tag releases with semantic versions (v1.0.0, v1.1.0, etc.).

### Q: What about package namespaces?

**A:** Use GitHub usernames/organizations as namespaces: `github.com/user/package-name`

### Q: How do I handle breaking changes?

**A:** Use semantic versioning. Major version bumps (v1.x.x → v2.0.0) indicate breaking changes.

### Q: Can I mirror packages locally?

**A:** Yes! The cache at `~/.mufiz/cache/` can be backed up or synced. You can also set up a local git server.

---

## Contributing

### Creating Packages

To create a MufiZ package:

1. **Create Repository:**
   ```bash
   mkdir mufiz-mypackage
   cd mufiz-mypackage
   git init
   ```

2. **Add mufi.zon:**
   ```zon
   .{
       .package = .{
           .name = "mypackage",
           .version = "0.1.0",
           .description = "My awesome package",
           .license = "MIT",
       },
       .project = .{
           .entry_point = "src/main.mufi",
       },
   }
   ```

3. **Write Code:**
   ```mufi
   // src/main.mufi
   export fun hello(name) {
       return "Hello, " + name + "!";
   }
   ```

4. **Tag Release:**
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. **Users Can Install:**
   ```bash
   mufiz pm add mypackage https://github.com/yourname/mufiz-mypackage v0.1.0
   ```

### Package Guidelines

- Use semantic versioning
- Include comprehensive README
- Provide examples
- Write tests
- Document public API
- Minimize dependencies
- Follow MufiZ style guide

---

## Resources

- **MufiZ Documentation:** [https://mufi-lang.mokareads.org](https://mufi-lang.mokareads.org)
- **GitHub:** [https://github.com/mufiz-lang/mufiz](https://github.com/mufiz-lang/mufiz)
- **Package Guidelines:** See `CONTRIBUTING.md`
- **ZON Format:** `docs/ZON_MIGRATION.md`

---

## Support

- **Issues:** [GitHub Issues](https://github.com/mufiz-lang/mufiz/issues)
- **Discussions:** [GitHub Discussions](https://github.com/mufiz-lang/mufiz/discussions)
- **Community:** Join our Discord (link in README)

---

**Last Updated:** 2024  
**MufiZ Version:** 0.11.0+  
**License:** MIT