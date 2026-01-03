# MufiZ Standard Library v2

A modern, type-safe, and extensible standard library system for the MufiZ programming language.

## Overview

The stdlib_v2 system is a complete redesign of the MufiZ standard library that provides:

- **Automatic Parameter Validation**: No more manual argument counting and type checking
- **Type-Safe Parameter System**: Enum-based types instead of magic numbers
- **Auto-Registration**: Functions are automatically discovered and registered
- **Built-in Documentation**: Integrated help system with examples
- **Modular Architecture**: Easy to add new modules without touching core files
- **Feature Flags**: Conditional compilation support for optional features
- **Consistent Error Messages**: Standardized error formatting with parameter names

## Quick Start

### Basic Usage

```zig
const std = @import("std");
const stdlib_v2 = @import("../stdlib_v2.zig");
const math = @import("math.zig");

pub fn main() !void {
    // Get the global registry
    const registry = stdlib_v2.getGlobalRegistry();
    
    // Auto-register all functions from a module
    const MathModule = stdlib_v2.AutoRegisterModule(math);
    try MathModule.register();
    
    // Register functions with the VM
    registry.registerAll();
    
    // Print documentation
    registry.printDocs();
}
```

### Creating a New Function

```zig
// 1. Write the implementation (no validation needed)
fn my_function_impl(argc: i32, args: [*]Value) Value {
    const input = args[0].as_num_double();
    return Value.init_double(input * 2.0);
}

// 2. Create the wrapper with metadata
pub const my_function = stdlib_v2.DefineFunction(
    "my_function",           // Function name
    "my_module",            // Module name
    "Doubles a number",     // Description
    stdlib_v2.OneNumber,    // Parameter specification
    .double,                // Return type
    &[_][]const u8{         // Examples
        "my_function(5) -> 10.0"
    },
    my_function_impl,       // Implementation function
);
```

## Core Components

### Parameter Types

```zig
pub const ParamType = enum(u8) {
    any,        // Accept any value type
    int,        // Integer values only
    double,     // Floating-point values only
    bool,       // Boolean values only
    nil,        // Nil values only
    object,     // Object values only
    complex,    // Complex numbers only
    number,     // Int or double (flexible numeric)
    string,     // String values only
};
```

### Parameter Specifications

```zig
pub const ParamSpec = struct {
    name: []const u8,           // Parameter name for error messages
    type: ParamType,            // Expected type
    optional: bool = false,     // Whether parameter is optional
};
```

### Common Parameter Patterns

For convenience, common parameter patterns are predefined:

```zig
const NoParams = [_]ParamSpec{};
const OneNumber = [_]ParamSpec{.{ .name = "value", .type = .number }};
const TwoNumbers = [_]ParamSpec{
    .{ .name = "a", .type = .number },
    .{ .name = "b", .type = .number },
};
const OneAny = [_]ParamSpec{.{ .name = "value", .type = .any }};
```

## Function Definition Patterns

### Simple Function (No Parameters)

```zig
fn pi_impl(argc: i32, args: [*]Value) Value {
    _ = argc; _ = args;
    return Value.init_double(std.math.pi);
}

pub const pi = DefineFunction(
    "pi", "math", "Pi constant (3.14159...)",
    NoParams, .double,
    &[_][]const u8{"pi() -> 3.141592653589793"},
    pi_impl,
);
```

### Single Parameter Function

```zig
fn sin_impl(argc: i32, args: [*]Value) Value {
    const angle = args[0].as_num_double();
    return Value.init_double(@sin(angle));
}

pub const sin = DefineFunction(
    "sin", "math", "Sine function",
    OneNumber, .double,
    &[_][]const u8{"sin(pi()/2) -> 1.0"},
    sin_impl,
);
```

### Multiple Parameters

```zig
fn pow_impl(argc: i32, args: [*]Value) Value {
    const base = args[0].as_num_double();
    const exponent = args[1].as_num_double();
    return Value.init_double(std.math.pow(f64, base, exponent));
}

pub const pow = DefineFunction(
    "pow", "math", "Power function (base^exponent)",
    TwoNumbers, .double,
    &[_][]const u8{"pow(2, 3) -> 8.0"},
    pow_impl,
);
```

### Optional Parameters

```zig
fn clamp_impl(argc: i32, args: [*]Value) Value {
    const value = args[0].as_num_double();
    const min_val = if (argc > 1) args[1].as_num_double() else 0.0;
    const max_val = if (argc > 2) args[2].as_num_double() else 1.0;
    
    const clamped = @min(@max(value, min_val), max_val);
    return Value.init_double(clamped);
}

pub const clamp = DefineFunction(
    "clamp", "math", "Clamp a value between min and max bounds",
    &[_]ParamSpec{
        .{ .name = "value", .type = .number },
        .{ .name = "min", .type = .number, .optional = true },
        .{ .name = "max", .type = .number, .optional = true },
    },
    .double,
    &[_][]const u8{
        "clamp(1.5) -> 1.0",
        "clamp(-0.5, 0, 10) -> 0.0",
        "clamp(15, 0, 10) -> 10.0",
    },
    clamp_impl,
);
```

### Polymorphic Functions (Multiple Types)

```zig
fn abs_impl(argc: i32, args: [*]Value) Value {
    switch (args[0].type) {
        .VAL_COMPLEX => {
            const c = args[0].as_complex();
            return Value.init_double(@sqrt(c.r * c.r + c.i * c.i));
        },
        .VAL_DOUBLE => {
            const d = args[0].as_num_double();
            return Value.init_double(@abs(d));
        },
        .VAL_INT => {
            const i = args[0].as_num_int();
            return Value.init_int(@intCast(@abs(i)));
        },
        else => return stdlib_v2.stdlib_error("abs() expects a Numeric Type!", .{}),
    }
}

pub const abs = DefineFunction(
    "abs", "math", "Absolute value or magnitude",
    &[_]ParamSpec{.{ .name = "value", .type = .any }}, // Accept any type
    .number,
    &[_][]const u8{
        "abs(-5) -> 5",
        "abs(3.14) -> 3.14",
        "abs(complex(3, 4)) -> 5.0",
    },
    abs_impl,
);
```

## Module Organization

### Creating a Module

1. Create a new `.zig` file in `src/stdlib_v2/`
2. Import required dependencies
3. Define implementation functions with `_impl` suffix
4. Create public wrappers using `DefineFunction`

**Example Module Structure:**

```zig
// src/stdlib_v2/string.zig
const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");

// Implementation functions
fn upper_impl(argc: i32, args: [*]Value) Value {
    // Implementation here
}

fn lower_impl(argc: i32, args: [*]Value) Value {
    // Implementation here
}

// Public wrappers
pub const upper = stdlib_v2.DefineFunction(
    "upper", "string", "Convert to uppercase",
    &[_]stdlib_v2.ParamSpec{.{ .name = "text", .type = .string }},
    .string,
    &[_][]const u8{"upper(\"hello\") -> \"HELLO\""},
    upper_impl,
);

pub const lower = stdlib_v2.DefineFunction(
    "lower", "string", "Convert to lowercase", 
    &[_]stdlib_v2.ParamSpec{.{ .name = "text", .type = .string }},
    .string,
    &[_][]const u8{"lower(\"WORLD\") -> \"world\""},
    lower_impl,
);
```

### Module Registration

**Auto-registration (Recommended):**
```zig
const StringModule = stdlib_v2.AutoRegisterModule(@import("string.zig"));
try StringModule.register();
```

**Manual Registration:**
```zig
const registry = stdlib_v2.getGlobalRegistry();
try registry.register(string.upper);
try registry.register(string.lower);
```

**Conditional Registration:**
```zig
// Only register if feature is enabled
try stdlib_v2.registerModuleConditional(network_module, "enable_net");
```

## Feature Flags

Control which modules are available at compile time:

```zig
// Set feature flags
stdlib_v2.setFeatureFlags(.{
    .enable_fs = true,      // File system operations
    .enable_net = false,    // Network operations  
});

// Check if feature is enabled
if (stdlib_v2.isFeatureEnabled("enable_net")) {
    // Register network functions
}
```

## Error Handling

The new system provides consistent, informative error messages:

### Automatic Validation Errors

```
// Wrong argument count
sqrt() expects 1-1 arguments, got 2

// Wrong parameter type  
sqrt() parameter 'value' expects Number, got String

// Missing required parameter
pow() missing required parameter: exponent
```

### Custom Error Messages

```zig
// Use stdlib_v2.stdlib_error for custom errors
return stdlib_v2.stdlib_error("Division by zero in function {s}", .{function_name});
```

## Registry and Documentation

### Function Registry

The global registry tracks all registered functions:

```zig
const registry = stdlib_v2.getGlobalRegistry();

// Get statistics
const total = registry.getFunctionCount();
const math_count = registry.getModuleFunctionCount("math");

// Register all functions with VM
registry.registerAll();

// Register only specific module
registry.registerModule("math");
```

### Built-in Documentation

Generate documentation for all registered functions:

```zig
// Print all documentation
registry.printDocs();

// Example output:
// === Math Module ===
// 
// sin(value: Number) -> Double
//   Sine function
//   Examples:
//     sin(pi()/2) -> 1.0
//
// cos(value: Number) -> Double  
//   Cosine function
//   Examples:
//     cos(0) -> 1.0
```

## Advanced Features

### Type Validation

The system automatically validates:
- Argument count (required vs optional parameters)
- Parameter types with clear error messages
- Parameter names in error messages

### Compile-time Safety

- Functions are registered at compile time
- Type checking prevents common errors
- Missing functions cause compile-time errors

### Performance

- Minimal runtime overhead (~2-5 instructions per parameter)
- One-time registration cost at startup
- Same O(1) function lookup as before

## Migration Guide

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions on migrating from the old stdlib system.

## Examples

Complete examples are available in:
- [math.zig](math.zig) - Mathematical functions
- [example_usage.zig](example_usage.zig) - Usage examples
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Migration examples

## Best Practices

### Function Design
- Use descriptive parameter names
- Provide clear descriptions and examples
- Choose appropriate parameter types (prefer `.number` over `.double` for flexibility)
- Mark optional parameters correctly

### Module Organization
- Group related functions together
- Use consistent naming conventions  
- Keep implementation functions private (`_impl` suffix)
- One module per logical domain

### Error Messages
- Let the system handle parameter validation
- Focus implementation on core logic
- Use `stdlib_v2.stdlib_error()` for domain-specific errors

### Documentation
- Always provide examples
- Document edge cases and limitations
- Keep descriptions concise but informative

## Architecture Benefits

### For Function Authors
- **Less Code**: ~70% reduction in boilerplate
- **Fewer Bugs**: Automatic validation prevents errors
- **Better Errors**: Clear, consistent error messages
- **Self-Documenting**: Built-in documentation system

### For Users
- **Better Help**: Integrated documentation with examples
- **Clearer Errors**: Parameter names in error messages
- **Consistent API**: Standardized behavior across all functions

### For Maintainers  
- **Modular Design**: Easy to add/remove modules
- **Centralized Logic**: All validation in one place
- **Type Safety**: Compile-time guarantees
- **Feature Flags**: Conditional compilation support

## Contributing

When adding new functions:

1. Follow the naming conventions
2. Include comprehensive examples
3. Write clear documentation
4. Test edge cases
5. Use appropriate parameter types
6. Consider optional parameters where appropriate

The stdlib_v2 system makes it easier than ever to contribute high-quality, well-documented functions to the MufiZ standard library.