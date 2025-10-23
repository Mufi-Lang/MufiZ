# Import Statement Feature

The MufiZ language now supports importing modules using the `import()` function. This allows you to organize your code into separate files and reuse functionality across multiple scripts.

## Usage

### Basic Import

```mufi
const foo = import("path/to/module.mufiz");
```

### Accessing Module Functions

Once imported, you can access functions and constants defined in the module:

```mufi
const math_utils = import("math_utils.mufiz");
const result = math_utils.add(2, 3);
print(result);  // Output: 5
```

### Example Module File (math_utils.mufiz)

```mufi
// math_utils.mufiz
fun add(a, b) {
    return a + b;
}

fun multiply(a, b) {
    return a * b;
}

const PI = 3.14159;
```

### Using the Module

```mufi
// main.mufi
const math = import("math_utils.mufiz");

const sum = math.add(5, 10);
print("Sum: " + str(sum));

const product = math.multiply(4, 7);
print("Product: " + str(product));

print("PI: " + str(math.PI));
```

## How It Works

1. The `import()` function reads and executes the specified file
2. All functions and constants defined in the module are captured
3. They are returned as an object (instance) that you can use
4. Modules are cached, so importing the same file multiple times reuses the first import

## Features

- **Module Caching**: Modules are only loaded once and cached for subsequent imports
- **Object-like Access**: Imported modules act like objects with properties (functions/constants)
- **Function Calls**: You can call functions from imported modules using dot notation
- **Constants**: Access constant values defined in modules

## Best Practices

1. **File Extensions**: Use `.mufiz` or `.mufi` extension for module files
2. **Module Organization**: Keep related functions together in the same module
3. **Clear Naming**: Use descriptive names for modules and exported functions
4. **Path Specification**: Use relative paths from the current working directory

## Example: Problem Statement Use Case

```mufi
// foo.mufiz
fun add(a, b) {
    return a + b;
}
```

```mufi
// main.mufi
const foo = import("foo.mufiz");
const res = foo.add(2, 3);
print(res);  // Output: 5
```

## Notes

- The imported module has access to the standard library functions
- Each module runs in its own scope during import
- Global variables and functions from the importing script are not accessible in the module during import
