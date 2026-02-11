# Module Import Guide: Aliasing and Dot Notation

This guide explains the Python-like module system in MufiZ, including module aliasing and dot notation for accessing module members.

## Table of Contents

1. [Overview](#overview)
2. [Basic Module Import](#basic-module-import)
3. [Module Aliasing](#module-aliasing)
4. [Dot Notation for Constants](#dot-notation-for-constants)
5. [Complete Examples](#complete-examples)
6. [Available Modules](#available-modules)
7. [Best Practices](#best-practices)

## Overview

MufiZ now supports a Python-like module import system with the following features:

- **Module Aliasing**: Import modules with custom names using the `as` keyword
- **Dot Notation**: Access module constants and members using the dot operator (`.`)
- **Lazy Loading**: Modules are loaded on-demand when imported
- **Namespace Isolation**: Each module maintains its own namespace

## Basic Module Import

Import a module using the `import` statement:

```mufi
import math;

// Use functions from the math module
var result = sin(3.14159);
println(result);
```

## Module Aliasing

Import a module with a custom alias using the `as` keyword:

```mufi
import math as m;

// Now you can use 'm' instead of 'math'
var result = sin(m.PI);
println(result);
```

### Syntax

```mufi
import <module_name> as <alias>;
```

- `<module_name>`: The name of the module to import
- `<alias>`: Your chosen alias for the module

### Example

```mufi
import collections as col;
import math as m;
import matrix as mx;
```

## Dot Notation for Constants

Access module constants using the dot operator:

```mufi
import math;

// Access PI constant
println(math.PI);  // 3.141592653589793

// Access E constant (Euler's number)
println(math.E);   // 2.718281828459045
```

### Using Constants in Calculations

```mufi
import math;

// Calculate circle area
var radius = 5;
var area = math.PI * radius * radius;
println(area);  // 78.53981633974483

// Calculate circle circumference
var circumference = 2 * math.PI * radius;
println(circumference);  // 31.41592653589793
```

### Combining Aliasing and Dot Notation

```mufi
import math as m;

// Use aliased module with dot notation
var circle_area = m.PI * 10 * 10;
println(circle_area);  // 314.1592653589793

var euler_squared = m.E * m.E;
println(euler_squared);  // 7.3890560989306495
```

## Complete Examples

### Example 1: Mathematical Calculations

```mufi
import math as m;

// Calculate using module constants
println("Circle calculations:");
var radius = 7;
var area = m.PI * radius * radius;
var circumference = 2 * m.PI * radius;

println("Radius: " + str(radius));
println("Area: " + str(area));
println("Circumference: " + str(circumference));

// Trigonometric functions with constants
var angle = m.PI / 4;  // 45 degrees in radians
println("sin(π/4) = " + str(sin(angle)));
println("cos(π/4) = " + str(cos(angle)));
```

### Example 2: Multiple Module Imports

```mufi
import math as m;
import collections as col;

// Use math module
println("Math constants:");
println("PI = " + str(m.PI));
println("E = " + str(m.E));

// Use collections module
println("\nCollections available");
```

### Example 3: Nested Expressions

```mufi
import math as m;

// Complex mathematical expressions
var expr1 = sqrt(m.PI * m.PI + m.E * m.E);
println("√(π² + e²) = " + str(expr1));

var expr2 = sin(m.PI / 6) + cos(m.PI / 3);
println("sin(π/6) + cos(π/3) = " + str(expr2));

var expr3 = pow(m.E, 2) / m.PI;
println("e² / π = " + str(expr3));
```

### Example 4: Storing Constants in Variables

```mufi
import math as m;

// Store constants in variables for reuse
var pi = m.PI;
var e = m.E;

println("Stored PI: " + str(pi));
println("Stored E: " + str(e));

// Use stored values
var sum = pi + e;
var product = pi * e;

println("PI + E = " + str(sum));
println("PI * E = " + str(product));
```

## Available Modules

MufiZ standard library includes the following modules:

### math
Mathematical functions and constants
- Constants: `PI`, `E`
- Functions: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `sqrt`, `pow`, `exp`, `ln`, `log2`, `log10`, `abs`, `ceil`, `floor`, `rand`, `randn`, `complex`, `phase`

### collections
Data structure utilities
- Functions: `linked_list`, `hash_table`, `fvec`, `push`, `pop`, `push_front`, `pop_front`, `len`, `insert_at`, `remove_at`, `get_at`, `set_at`, `contains`, `clear`, `reverse`, `sort`, `map`, `filter`, `reduce`, `find`, `all`, `any`, `zip`, `enumerate`, `range`, `slice`

### matrix
Matrix operations
- Functions: `eye`, `ones`, `zeros`, `rand`, `randn`, `transpose`, `det`, `inv`, `dot`, `add`, `sub`, `mul`, `trace`, `rank`, `norm`, `reshape`, `flatten`, `concat`

### io
Input/Output operations
- Functions: `print`, `printf`, `println`, `input`

### types
Type conversion and checking
- Functions: `str`, `int`, `double`, `bool`, `type_of`, `is_nil`, `is_string`, `is_number`, `is_bool`, `is_function`, `is_class`, `is_instance`

### utils
Utility functions
- Functions: `assert`, `exit`, `panic`, `format`, `equals`, `hash`, `clone`, `identity`, `compose`, `pipe`

### json
JSON parsing and serialization
- Functions: `json_parse`, `json_stringify`, `json_is_valid`, `json_pretty`, `json_get`, `json_set`

### serde
Serialization/Deserialization utilities
- Functions: `serde_serialize`, `serde_deserialize`, `serde_to_json`, `serde_from_json`, `serde_to_toml`, `serde_from_toml`, `serde_to_yaml`, `serde_from_yaml`

## Best Practices

### 1. Use Meaningful Aliases

```mufi
// Good: Clear and concise
import math as m;
import collections as col;
import matrix as mx;

// Avoid: Too cryptic
import math as x;
import collections as c;
```

### 2. Import Only What You Need

```mufi
// Use 'from' imports for specific functions
from math import sin, cos, tan;

// Or import the full module for multiple uses
import math;
```

### 3. Consistent Naming

Be consistent with your module aliases throughout your codebase:

```mufi
// At the top of your file
import math as m;
import collections as col;

// Use consistently throughout
var result = m.sin(m.PI);
var list = col.linked_list();
```

### 4. Access Constants via Dot Notation

```mufi
// Preferred: Clear and explicit
import math;
var area = math.PI * radius * radius;

// Also valid with aliasing
import math as m;
var circumference = 2 * m.PI * radius;
```

### 5. Combine with Existing Features

Module imports work seamlessly with all MufiZ features:

```mufi
import math as m;

// In functions
fun circle_area(radius) {
    return m.PI * radius * radius;
}

// In classes
class Circle {
    init(radius) {
        self.radius = radius;
    }
    
    area() {
        return m.PI * self.radius * self.radius;
    }
}

// With loops and conditionals
for (var i = 0; i < 10; i = i + 1) {
    if (i * m.PI > 10) {
        println("Large angle: " + str(i * m.PI));
    }
}
```

## Migration Guide

If you have existing code that uses the old import system:

### Before (Old Style)
```mufi
import math;
var result = pi();  // Function call
```

### After (New Style with Dot Notation)
```mufi
import math;
var result = math.PI;  // Direct constant access
```

### With Aliasing
```mufi
import math as m;
var result = m.PI;  // Clean and concise
```

## Summary

The new module system brings MufiZ closer to modern scripting languages like Python:

- ✅ **Module aliasing** with `import module as alias;`
- ✅ **Dot notation** for constants: `math.PI`, `math.E`
- ✅ **Namespace isolation** for better code organization
- ✅ **Lazy loading** for efficient module initialization
- ✅ **Backward compatible** with existing import syntax

For more examples, see the test files:
- `test_suite/module_alias_and_constants.mufi`
- `test_suite/module_aliasing_complete.mufi`
- `test_suite/simple_module_alias.mufi`
