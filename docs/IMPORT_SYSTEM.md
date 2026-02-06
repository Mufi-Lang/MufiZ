# Python-style Import System for MufiZ

## Overview

MufiZ now supports a Python-style module import system with lazy-loading capabilities. This allows you to selectively import only the modules and functions you need, improving startup time and memory usage.

## Import Syntax

### Basic Module Import

Import an entire module:

```mufi
import math;

var x = sin(3.14159);
var y = cos(0);
var z = sqrt(16);
```

### Selective Function Import

Import specific functions from a module:

```mufi
from math import sin, cos, sqrt;

var x = sin(3.14159);
var y = cos(0);
var z = sqrt(16);
```

### File Import

Import code from another MufiZ file:

```mufi
import "path/to/file.mufi";

// Now you can use functions and variables defined in that file
```

### Import with Alias (Future Feature)

Alias support is planned for future releases:

```mufi
import math as m;
import collections as col;
import "config.mufi" as cfg;
```

## Available Modules

The following standard library modules can be imported on demand:

- **math**: Mathematical functions (sin, cos, sqrt, exp, log, etc.)
- **collections**: Data structures (linked_list, hash_table, fvec, etc.)
- **matrix**: Matrix operations (eye, ones, zeros, transpose, det, inv, etc.)
- **io**: Input/output functions (print, println, printf, input)
- **types**: Type conversion functions (str, int, double, bool, type_of, etc.)
- **utils**: Utility functions (assert, exit, panic, format, equals, hash, clone)
- **json**: JSON parsing and serialization
- **serde**: Serialization/deserialization (JSON, TOML, YAML)

## Core Functions

The following functions are always available without imports:

- **IO**: `print`, `println`, `printf`, `input`
- **Types**: `str`, `int`, `double`, `bool`, `type_of`, `is_nil`, `is_string`, `is_number`, `is_bool`
- **Core**: `what_is`

## Lazy Loading

Modules are loaded **only when imported**. This means:

1. **Faster startup**: The interpreter doesn't load all standard library modules at startup
2. **Lower memory usage**: Unused modules are never loaded into memory
3. **Better modularity**: Your code explicitly declares its dependencies

## Examples

### Example 1: Math Operations

```mufi
import math;

var radius = 5;
var area = pi() * pow(radius, 2);
println(area);
```

### Example 2: Using Multiple Modules

```mufi
import math;
import collections;

var list = linked_list();
push(list, sqrt(16));
push(list, sin(1.5));
push(list, cos(2.0));

println(len(list));
```

### Example 3: Selective Imports

```mufi
from math import sin, cos, tan;
from collections import linked_list, push, len;

var angles = linked_list();
push(angles, sin(0));
push(angles, cos(0));
push(angles, tan(0));

println(len(angles));
```

### Example 4: File Imports

Create a helper file `utils.mufi`:

```mufi
fun calculate_area(radius) {
    return 3.14159 * radius * radius;
}

fun calculate_circumference(radius) {
    return 2 * 3.14159 * radius;
}
```

Use it in your main file:

```mufi
import "utils.mufi";

var r = 10;
println(calculate_area(r));
println(calculate_circumference(r));
```

## Implementation Details

### Module Registry

The module registry (`src/module_registry.zig`) maintains a list of available modules and tracks which ones have been loaded. When you import a module, the registry:

1. Checks if the module is already loaded
2. If not, calls the module's registration function
3. Marks the module as loaded to prevent duplicate loading

### Opcodes

Four new opcodes were added to support imports:

- `OP_IMPORT_MODULE`: Load an entire module
- `OP_IMPORT_FILE`: Load and execute a MufiZ file
- `OP_IMPORT_SPECIFIC`: Load specific functions from a module
- `OP_IMPORT_MODULE_AS`: Load a module with an alias (future)

### Compiler Integration

The compiler recognizes the new `import`, `from`, and `as` keywords and generates the appropriate bytecode. Import statements must be at the top level (not inside functions or blocks).

## Testing

Test files have been created in the `test_suite/` directory:

- `import_module_test.mufi`: Tests basic module import
- `import_from_test.mufi`: Tests selective function import
- `import_file_test.mufi`: Tests file import
- `import_multiple_modules.mufi`: Tests importing multiple modules
- `import_lazy_loading.mufi`: Verifies lazy loading behavior

Run the tests with:

```shell
zig build test
```

Or run individual test files:

```shell
zig build run -- -r test_suite/import_module_test.mufi
```

## Future Enhancements

- **Alias support**: Fully implement `as` keyword for module aliasing
- **Namespace scoping**: Modules imported with aliases have their own namespace
- **Circular dependency detection**: Prevent infinite import loops
- **Module caching**: Cache compiled modules for faster subsequent imports
- **Relative imports**: Support for relative file paths (e.g., `./module.mufi`)
- **Package management**: Integration with external package repositories
