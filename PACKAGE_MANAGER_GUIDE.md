# MufiZ Package Manager Guide

The MufiZ Package Manager (`mufiz pm`) is a command-line tool for creating, managing, and running MufiZ projects.

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Commands](#commands)
5. [Project Structure](#project-structure)
6. [Configuration File](#configuration-file)
7. [Examples](#examples)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

## Overview

The MufiZ Package Manager provides a standardized way to:

- Create new MufiZ projects with proper structure
- Initialize existing directories as MufiZ projects
- Manage project metadata through `mufi.toml`
- Run projects with a single command
- View project information

## Installation

The package manager is built into the MufiZ interpreter. If you have MufiZ installed, you already have access to `mufiz pm`.

To verify installation:

```bash
mufiz pm help
```

## Quick Start

### Creating a New Project

```bash
# Create a new project in a new directory
mufiz pm new my-project

# Navigate to the project
cd my-project

# Run the project
mufiz pm run
```

### Initializing an Existing Directory

```bash
# Create a directory
mkdir my-app
cd my-app

# Initialize as a MufiZ project
mufiz pm init my-app

# Run the project
mufiz pm run
```

## Commands

### `mufiz pm new <name>`

Creates a new MufiZ project in a new directory.

**Usage:**
```bash
mufiz pm new <project-name>
```

**What it does:**
- Creates a new directory with the project name
- Generates a `mufi.toml` configuration file
- Creates a `src/` directory with a sample `main.mufi` file
- Sets up the project structure

**Example:**
```bash
mufiz pm new calculator-app
```

**Output:**
```
📦 Creating new MufiZ project: calculator-app
✅ Project 'calculator-app' created successfully!

Project structure:
  calculator-app/
  ├── mufi.toml
  └── src/
      └── main.mufi

Next steps:
  1. cd calculator-app
  2. Edit src/main.mufi to write your code
  3. Run your project with: mufiz -r src/main.mufi
```

### `mufiz pm init <name>`

Initializes a MufiZ project in the current directory.

**Usage:**
```bash
mufiz pm init <project-name>
```

**What it does:**
- Creates a `mufi.toml` configuration file in the current directory
- Creates a `src/` directory with a sample `main.mufi` file
- Does not create a new parent directory

**Example:**
```bash
mkdir my-project
cd my-project
mufiz pm init my-project
```

**Note:** This command will fail if a `mufi.toml` file already exists in the current directory.

### `mufiz pm info`

Displays information about the current project.

**Usage:**
```bash
mufiz pm info
```

**What it does:**
- Reads and displays the contents of `mufi.toml`
- Shows project metadata including name, version, authors, and description

**Example:**
```bash
cd my-project
mufiz pm info
```

**Output:**
```
📦 Project Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[package]
name = "my-project"
version = "0.1.0"
authors = []
description = "A MufiZ project"
license = "MIT"

[project]
entry_point = "src/main.mufi"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Note:** This command must be run from a directory containing a `mufi.toml` file.

### `mufiz pm run`

Runs the current project by executing the entry point.

**Usage:**
```bash
mufiz pm run
```

**What it does:**
- Checks for the presence of `mufi.toml`
- Executes the entry point specified in the configuration (default: `src/main.mufi`)
- Runs the MufiZ interpreter on the entry point file

**Example:**
```bash
cd my-project
mufiz pm run
```

**Output:**
```
🚀 Running MufiZ project...

Hello from MufiZ! 🚀
Hello, World!
Circle area with radius 5: 78.53981633974483
```

**Note:** This command must be run from a directory containing a `mufi.toml` file and the entry point file must exist.

### `mufiz pm help`

Displays help information about the package manager.

**Usage:**
```bash
mufiz pm help
```

## Project Structure

A standard MufiZ project has the following structure:

```
my-project/
├── mufi.toml          # Project configuration file
└── src/
    └── main.mufi      # Entry point of the application
```

### Directory Breakdown

- **`mufi.toml`**: Configuration file containing project metadata
- **`src/`**: Source directory containing all MufiZ code files
- **`src/main.mufi`**: Default entry point for the application

### Adding More Files

You can add additional MufiZ files to organize your code:

```
my-project/
├── mufi.toml
└── src/
    ├── main.mufi
    ├── utils.mufi
    └── math_helpers.mufi
```

Then import them in your `main.mufi`:

```mufi
import "utils.mufi";
import "math_helpers.mufi";
```

## Configuration File

The `mufi.toml` file contains project metadata and configuration.

### Default Template

```toml
[package]
name = "my-project"
version = "0.1.0"
authors = []
description = "A MufiZ project"
license = "MIT"

[project]
entry_point = "src/main.mufi"

# Dependencies will be supported in future versions
# [dependencies]
```

### Sections

#### `[package]`

Project metadata section:

- **`name`**: The name of your project (string)
- **`version`**: Current version following semantic versioning (string)
- **`authors`**: List of project authors (array of strings)
- **`description`**: Brief description of the project (string)
- **`license`**: Project license (string)

#### `[project]`

Project configuration section:

- **`entry_point`**: Path to the main entry point file (string, default: `"src/main.mufi"`)

#### `[dependencies]`

Dependencies section (future feature):

This section is reserved for future dependency management support. Currently commented out as dependencies are not yet implemented.

### Customizing Your Project

You can manually edit `mufi.toml` to customize your project:

```toml
[package]
name = "calculator"
version = "1.0.0"
authors = ["Jane Doe <jane@example.com>"]
description = "A scientific calculator application"
license = "Apache-2.0"

[project]
entry_point = "src/main.mufi"
```

## Examples

### Example 1: Simple Calculator Project

```bash
# Create project
mufiz pm new calculator

# Navigate to project
cd calculator
```

Edit `src/main.mufi`:

```mufi
// Simple Calculator
import math;

fun add(a, b) {
    return a + b;
}

fun subtract(a, b) {
    return a - b;
}

fun multiply(a, b) {
    return a * b;
}

fun divide(a, b) {
    if (b == 0) {
        println("Error: Division by zero!");
        return nil;
    }
    return a / b;
}

println("=== Calculator ===");
println("5 + 3 = " + str(add(5, 3)));
println("5 - 3 = " + str(subtract(5, 3)));
println("5 * 3 = " + str(multiply(5, 3)));
println("5 / 3 = " + str(divide(5, 3)));
println("Circle area (r=5): " + str(math.PI * 5 * 5));
```

Run the project:

```bash
mufiz pm run
```

### Example 2: Data Processing Project

```bash
# Create project
mufiz pm new data-processor

# Navigate to project
cd data-processor
```

Edit `src/main.mufi`:

```mufi
// Data Processor
import collections;

fun process_data(data) {
    var list = linked_list();
    
    for (var i = 0; i < len(data); i = i + 1) {
        var item = data[i];
        if (item > 10) {
            push(list, item * 2);
        }
    }
    
    return list;
}

println("=== Data Processor ===");
var data = [5, 15, 8, 20, 12, 3];
var result = process_data(data);
println("Processed data:");
println(result);
```

Run the project:

```bash
mufiz pm run
```

### Example 3: Game Project Structure

```bash
# Create project
mufiz pm new simple-game

cd simple-game

# Create additional modules (manually)
mkdir src/game
```

Create `src/game/player.mufi`:

```mufi
// Player module
class Player {
    init(name, health) {
        self.name = name;
        self.health = health;
    }
    
    take_damage(amount) {
        self.health = self.health - amount;
        println(self.name + " took " + str(amount) + " damage!");
    }
    
    is_alive() {
        return self.health > 0;
    }
}
```

Edit `src/main.mufi`:

```mufi
// Simple Game
import "game/player.mufi";

println("=== Simple Game ===");

var player1 = Player("Hero", 100);
var player2 = Player("Enemy", 80);

println(player1.name + " vs " + player2.name);

player1.take_damage(20);
player2.take_damage(30);

println(player1.name + " health: " + str(player1.health));
println(player2.name + " health: " + str(player2.health));
```

Run the project:

```bash
mufiz pm run
```

## Best Practices

### 1. Use Semantic Versioning

Follow semantic versioning (MAJOR.MINOR.PATCH) for your project versions:

```toml
version = "1.2.3"  # MAJOR.MINOR.PATCH
```

- **MAJOR**: Incompatible API changes
- **MINOR**: Add functionality in a backward-compatible manner
- **PATCH**: Backward-compatible bug fixes

### 2. Organize Code into Modules

Keep your code organized by splitting it into logical modules:

```
my-project/
├── mufi.toml
└── src/
    ├── main.mufi
    ├── utils/
    │   ├── math.mufi
    │   └── string.mufi
    └── models/
        └── data.mufi
```

### 3. Document Your Project

Add meaningful descriptions to your `mufi.toml`:

```toml
[package]
name = "awesome-app"
version = "1.0.0"
authors = ["Your Name <you@example.com>"]
description = "An awesome application that does amazing things"
license = "MIT"
```

### 4. Keep Entry Point Simple

Use `main.mufi` as a clean entry point that delegates to other modules:

```mufi
// main.mufi - Keep it simple
import "app/core.mufi";
import "app/ui.mufi";

fun main() {
    initialize_app();
    run_ui();
}

main();
```

### 5. Use Version Control

Initialize a git repository for your project:

```bash
cd my-project
git init
echo ".zig-cache/" > .gitignore
echo "zig-out/" >> .gitignore
git add .
git commit -m "Initial commit"
```

### 6. Test Regularly

Run your project frequently during development:

```bash
mufiz pm run
```

Or run specific files:

```bash
mufiz -r src/main.mufi
```

## Troubleshooting

### Error: "Not a MufiZ project (mufi.toml not found)"

**Problem:** You're trying to run `mufiz pm info` or `mufiz pm run` outside a MufiZ project.

**Solution:** Navigate to a directory containing a `mufi.toml` file, or initialize a new project:

```bash
mufiz pm init my-project
```

### Error: "Project already initialized (mufi.toml exists)"

**Problem:** You're trying to initialize a project in a directory that already has a `mufi.toml` file.

**Solution:** Either remove the existing `mufi.toml` or use a different directory.

### Error: "Directory 'project-name' already exists"

**Problem:** You're trying to create a new project with a name that already exists as a directory.

**Solution:** Choose a different project name or remove the existing directory.

### Error: "Entry point not found (src/main.mufi)"

**Problem:** The `src/main.mufi` file doesn't exist or has been moved.

**Solution:** Create the missing file:

```bash
mkdir -p src
echo 'println("Hello, World!");' > src/main.mufi
```

Or update the `entry_point` in `mufi.toml` to point to the correct file.

### Project Won't Run

**Troubleshooting steps:**

1. Verify you're in the project directory:
   ```bash
   ls mufi.toml  # Should exist
   ```

2. Check the entry point exists:
   ```bash
   ls src/main.mufi  # Should exist
   ```

3. Verify the file syntax:
   ```bash
   mufiz -r src/main.mufi
   ```

4. Check for compilation errors in your code

## Future Features

The following features are planned for future releases:

### Dependency Management

```toml
[dependencies]
http-client = "1.0.0"
json-parser = "2.1.0"
```

### Build System

```bash
mufiz pm build      # Compile the project
mufiz pm test       # Run tests
mufiz pm clean      # Clean build artifacts
```

### Package Registry

```bash
mufiz pm publish    # Publish to package registry
mufiz pm install    # Install dependencies
mufiz pm update     # Update dependencies
```

### Templates

```bash
mufiz pm new my-app --template web
mufiz pm new my-game --template game
```

## Getting Help

- **Package Manager Help**: `mufiz pm help`
- **General Help**: `mufiz --help`
- **Documentation**: `mufiz --docs`
- **GitHub**: [https://github.com/mufiz-lang/mufiz](https://github.com/mufiz-lang/mufiz)

## Contributing

Contributions to the MufiZ Package Manager are welcome! Please see the main MufiZ repository for contribution guidelines.

## License

The MufiZ Package Manager is part of the MufiZ language project and is distributed under the same license.