# MufiZ Package Manager (mufiz pm)

> A simple and powerful package manager for MufiZ projects

## Quick Start

### Create a New Project

```bash
mufiz pm new my-project
cd my-project
mufiz pm run
```

That's it! You now have a working MufiZ project.

## Commands

| Command | Description |
|---------|-------------|
| `mufiz pm new <name>` | Create a new project in a new directory |
| `mufiz pm init <name>` | Initialize current directory as a project |
| `mufiz pm run` | Run the current project |
| `mufiz pm info` | Display project information |
| `mufiz pm help` | Show detailed help |

## Project Structure

Every MufiZ project follows this structure:

```
my-project/
├── mufi.toml       # Project metadata
└── src/
    └── main.mufi   # Entry point
```

## Example Workflow

```bash
# 1. Create a new project
mufiz pm new calculator

# 2. Navigate to it
cd calculator

# 3. Edit src/main.mufi with your code
# (Use your favorite editor)

# 4. Run your project
mufiz pm run

# 5. Check project info
mufiz pm info
```

## mufi.toml

The `mufi.toml` file contains your project metadata:

```toml
[package]
name = "calculator"
version = "0.1.0"
authors = []
description = "A MufiZ project"
license = "MIT"

[project]
entry_point = "src/main.mufi"
```

## Sample Project

When you create a new project, you get a working example that demonstrates:

- ✅ Basic MufiZ syntax
- ✅ Function definitions
- ✅ Module imports (using the new `math` module)
- ✅ Using constants with dot notation (`math.PI`)
- ✅ String concatenation and output

## Features

### Current Features

- ✅ Project scaffolding
- ✅ Standardized project structure
- ✅ Project metadata management
- ✅ One-command project execution
- ✅ Project information display

### Coming Soon

- 🔄 Dependency management
- 🔄 Package registry
- 🔄 Build system
- 🔄 Testing framework
- 🔄 Project templates

## Documentation

For more detailed information, see:

- **[PACKAGE_MANAGER_GUIDE.md](PACKAGE_MANAGER_GUIDE.md)** - Comprehensive guide
- **[examples/package_manager_example.md](examples/package_manager_example.md)** - Step-by-step tutorial
- **[PM_IMPLEMENTATION_SUMMARY.md](PM_IMPLEMENTATION_SUMMARY.md)** - Technical details

## Examples

### Creating a Calculator

```bash
mufiz pm new calculator
cd calculator
```

Edit `src/main.mufi`:

```mufi
import math as m;

fun calculate_circle_area(radius) {
    return m.PI * radius * radius;
}

var radius = 10;
println("Area: " + str(calculate_circle_area(radius)));
```

Run it:

```bash
mufiz pm run
```

### Initializing Existing Directory

```bash
mkdir my-app
cd my-app
mufiz pm init my-app
mufiz pm run
```

## Tips

1. **Use `pm run`** instead of manual `mufiz -r` for consistency
2. **Keep `mufi.toml` updated** with accurate project information
3. **Organize code** into multiple files in the `src/` directory
4. **Version your projects** using semantic versioning (1.0.0)

## Error Handling

The package manager provides clear error messages:

```bash
# Trying to create existing project
$ mufiz pm new existing-project
Error: Directory 'existing-project' already exists

# Running outside a project
$ mufiz pm run
Error: Not a MufiZ project (mufi.toml not found)
Run 'mufiz pm init <project_name>' to initialize a project
```

## Integration

The package manager works seamlessly with:

- ✅ Module aliasing (`import math as m`)
- ✅ Dot notation for constants (`math.PI`)
- ✅ All standard library modules
- ✅ File imports
- ✅ Class definitions
- ✅ Functions and closures

## Contributing

Found a bug or have a suggestion? Please open an issue or submit a pull request!

## License

Part of the MufiZ language project.

---

**Get Started Now:**

```bash
mufiz pm new my-first-project
cd my-first-project
mufiz pm run
```

🚀 Happy coding with MufiZ!