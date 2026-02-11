# MufiZ Package Manager Example

This example demonstrates how to use the MufiZ Package Manager to create and manage a simple project.

## Creating a New Project

```bash
# Create a new project called "my-calculator"
mufiz pm new my-calculator

# Output:
# 📦 Creating new MufiZ project: my-calculator
# ✅ Project 'my-calculator' created successfully!
#
# Project structure:
#   my-calculator/
#   ├── mufi.toml
#   └── src/
#       └── main.mufi
```

## Project Structure

After creation, your project will have this structure:

```
my-calculator/
├── mufi.toml       # Project metadata and configuration
└── src/
    └── main.mufi   # Entry point of your application
```

## The mufi.toml File

```toml
[package]
name = "my-calculator"
version = "0.1.0"
authors = []
description = "A MufiZ project"
license = "MIT"

[project]
entry_point = "src/main.mufi"

# Dependencies will be supported in future versions
# [dependencies]
```

## The Default main.mufi File

```mufi
// Welcome to your new MufiZ project!
// This is the entry point of your application.

println("Hello from MufiZ! 🚀");

// Example: Simple function
fun greet(name) {
    println("Hello, " + name + "!");
}

greet("World");

// Example: Using the math module
import math;

fun calculate_circle_area(radius) {
    return math.PI * radius * radius;
}

var radius = 5;
var area = calculate_circle_area(radius);
println("Circle area with radius " + str(radius) + ": " + str(area));

// Add your code here!
```

## Customizing Your Project

### Step 1: Update mufi.toml

Edit the `mufi.toml` file to customize your project metadata:

```toml
[package]
name = "my-calculator"
version = "1.0.0"
authors = ["Your Name <your.email@example.com>"]
description = "A simple calculator application"
license = "MIT"

[project]
entry_point = "src/main.mufi"
```

### Step 2: Edit src/main.mufi

Replace the contents with your calculator code:

```mufi
// Simple Calculator Application
import math as m;

println("=== MufiZ Calculator ===");
println();

// Basic operations
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

// Advanced operations using math module
fun power(base, exponent) {
    return pow(base, exponent);
}

fun square_root(n) {
    return sqrt(n);
}

fun circle_area(radius) {
    return m.PI * radius * radius;
}

// Demo calculations
println("Basic Operations:");
println("  5 + 3 = " + str(add(5, 3)));
println("  5 - 3 = " + str(subtract(5, 3)));
println("  5 * 3 = " + str(multiply(5, 3)));
println("  5 / 3 = " + str(divide(5, 3)));
println();

println("Advanced Operations:");
println("  2^8 = " + str(power(2, 8)));
println("  √16 = " + str(square_root(16)));
println("  Circle area (r=5) = " + str(circle_area(5)));
println();

println("Constants:");
println("  PI = " + str(m.PI));
println("  E = " + str(m.E));
```

## Running Your Project

### Method 1: Using Package Manager

```bash
cd my-calculator
mufiz pm run
```

Output:
```
🚀 Running MufiZ project...

=== MufiZ Calculator ===

Basic Operations:
  5 + 3 = 8
  5 - 3 = 2
  5 * 3 = 15
  5 / 3 = 1.6666666666666667

Advanced Operations:
  2^8 = 256
  √16 = 4
  Circle area (r=5) = 78.53981633974483

Constants:
  PI = 3.141592653589793
  E = 2.718281828459045
```

### Method 2: Using Direct Execution

```bash
mufiz -r src/main.mufi
```

## Viewing Project Information

```bash
mufiz pm info
```

Output:
```
📦 Project Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[package]
name = "my-calculator"
version = "1.0.0"
authors = ["Your Name <your.email@example.com>"]
description = "A simple calculator application"
license = "MIT"

[project]
entry_point = "src/main.mufi"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Adding More Features

### Creating Additional Modules

Create a new file `src/advanced_math.mufi`:

```mufi
// Advanced Math Functions
import math as m;

fun factorial(n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

fun fibonacci(n) {
    if (n <= 1) {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

fun is_prime(n) {
    if (n <= 1) {
        return false;
    }
    if (n <= 3) {
        return true;
    }
    if (n % 2 == 0) {
        return false;
    }
    
    var i = 3;
    while (i * i <= n) {
        if (n % i == 0) {
            return false;
        }
        i = i + 2;
    }
    return true;
}
```

### Using the New Module

Update `src/main.mufi`:

```mufi
// Import the advanced math module
import "advanced_math.mufi";

println("=== Advanced Math ===");
println("5! = " + str(factorial(5)));
println("Fibonacci(10) = " + str(fibonacci(10)));
println("Is 17 prime? " + str(is_prime(17)));
```

## Initializing Existing Directories

If you already have a directory and want to turn it into a MufiZ project:

```bash
mkdir existing-app
cd existing-app

# Initialize as MufiZ project
mufiz pm init existing-app
```

This creates the same structure without creating a new parent directory.

## Package Manager Commands Summary

| Command | Description |
|---------|-------------|
| `mufiz pm new <name>` | Create a new project in a new directory |
| `mufiz pm init <name>` | Initialize current directory as a project |
| `mufiz pm run` | Run the current project |
| `mufiz pm info` | Display project information |
| `mufiz pm help` | Show help message |

## Tips and Best Practices

1. **Always use `mufiz pm run`** in your project directory for consistent execution
2. **Keep your `mufi.toml` updated** with accurate version and description
3. **Organize code into modules** for better maintainability
4. **Use semantic versioning** for your project versions
5. **Document your code** with comments for clarity

## Next Steps

- Explore the [MODULE_IMPORT_GUIDE.md](../MODULE_IMPORT_GUIDE.md) for advanced import features
- Check out [PACKAGE_MANAGER_GUIDE.md](../PACKAGE_MANAGER_GUIDE.md) for comprehensive documentation
- Learn about module aliasing and dot notation for cleaner code