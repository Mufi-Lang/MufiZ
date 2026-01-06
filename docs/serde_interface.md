# MufiZ Serde Interface Documentation

## Overview

The MufiZ Serde (Serialization/Deserialization) interface provides a unified, extensible system for converting MufiZ values to and from various data formats. The interface is designed to be format-agnostic, type-safe, and easily extensible for new formats.

## Architecture

### Core Components

1. **`src/serde.zig`** - Core Serde interface and traits
2. **`src/stdlib/serde_json.zig`** - JSON format implementation
3. **`src/stdlib/serde_toml.zig`** - TOML format implementation (partial)
4. **`src/stdlib/serde_yaml.zig`** - YAML format implementation (partial)
5. **`src/stdlib/serde.zig`** - MufiZ stdlib integration

### Design Principles

- **Format Agnostic**: Common interface works with any serialization format
- **Type Safe**: Full support for all MufiZ value and object types
- **Extensible**: Easy to add new formats without changing existing code
- **Error Context**: Detailed error reporting with location information
- **Performance**: Efficient serialization with minimal allocations

## Supported Types

### MufiZ Value Types

| MufiZ Type | JSON | TOML | YAML | Notes |
|------------|------|------|------|-------|
| `VAL_NIL` | `null` | ❌ | `null` | TOML doesn't support null |
| `VAL_BOOL` | `true`/`false` | `true`/`false` | `true`/`false` | |
| `VAL_INT` | `42` | `42` | `42` | |
| `VAL_DOUBLE` | `3.14` | `3.14` | `3.14` | Special handling for NaN/Inf |
| `VAL_COMPLEX` | `{"r":1,"i":2}` | `{real=1,imag=2}` | `{real: 1, imag: 2}` | Serialized as object |

### MufiZ Object Types

| Object Type | JSON | TOML | YAML | Notes |
|-------------|------|------|------|-------|
| `OBJ_STRING` | `"string"` | `"string"` | `string` | Auto-quoting in YAML |
| `OBJ_HASH_TABLE` | `{"key":"value"}` | `key = "value"` | `key: value` | |
| `OBJ_LINKED_LIST` | `[1,2,3]` | `[1,2,3]` | `[1,2,3]` or block style | |
| `OBJ_FVECTOR` | `[1.1,2.2,3.3]` | `[1.1,2.2,3.3]` | `[1.1,2.2,3.3]` | |
| `OBJ_MATRIX` | `[[1,2],[3,4]]` | `[[1,2],[3,4]]` | `- [1,2]`<br>`- [3,4]` | |
| `OBJ_RANGE` | `{"start":1,"end":10,"inclusive":true}` | `{start=1,end=10,inclusive=true}` | `start: 1`<br>`end: 10`<br>`inclusive: true` | |
| `OBJ_PAIR` | `{"key":"k","value":"v"}` | `{key="k",value="v"}` | `key: k`<br>`value: v` | |

### Unsupported Types

The following object types are not serializable (runtime-only objects):
- `OBJ_FUNCTION`
- `OBJ_CLOSURE` 
- `OBJ_NATIVE`
- `OBJ_UPVALUE`
- `OBJ_BOUND_METHOD`
- `OBJ_CLASS`
- `OBJ_INSTANCE`
- `OBJ_MATRIX_ROW` (view object)

## API Reference

### Core Interface

#### Serialization Options

```zig
pub const SerializeOptions = struct {
    /// Pretty print with indentation
    pretty: bool = false,
    /// Indentation string (spaces or tabs)
    indent: []const u8 = "  ",
    /// Maximum nesting depth (prevents stack overflow)
    max_depth: u32 = 100,
    /// Whether to serialize nil values
    include_nil: bool = true,
    /// Sort object keys for deterministic output
    sort_keys: bool = false,
};
```

#### Deserialization Options

```zig
pub const DeserializeOptions = struct {
    /// Maximum nesting depth
    max_depth: u32 = 100,
    /// Allow trailing commas
    allow_trailing_comma: bool = false,
    /// Allow comments in input
    allow_comments: bool = false,
    /// Strict type checking
    strict_types: bool = true,
};
```

#### High-Level Functions

```zig
// Generic serialization
pub fn serialize(
    value: Value,
    format: []const u8,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) SerdeError![]const u8

// Generic deserialization
pub fn deserialize(
    data: []const u8,
    format: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value

// Auto-detect format and deserialize
pub fn deserializeAuto(
    data: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value

// File operations
pub fn serializeToFile(
    value: Value,
    file_path: []const u8,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) !void

pub fn deserializeFromFile(
    file_path: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) !Value
```

### MufiZ Stdlib Functions

#### Generic Functions

```mufi
// Serialize any value to specified format
serde_serialize(value, "json", options?) -> string
serde_serialize(value, "toml", options?) -> string
serde_serialize(value, "yaml", options?) -> string

// Deserialize from specified format
serde_deserialize(data, "json", options?) -> value
serde_deserialize(data, "toml", options?) -> value
serde_deserialize(data, "yaml", options?) -> value
```

#### Format-Specific Functions

```mufi
// JSON
serde_to_json(value, pretty?) -> string
serde_from_json(json_string) -> value

// TOML
serde_to_toml(value) -> string
serde_from_toml(toml_string) -> value

// YAML
serde_to_yaml(value, pretty?) -> string
serde_from_yaml(yaml_string) -> value
```

#### Utility Functions

```mufi
// Detect format of data
serde_detect_format(data) -> string  // "json", "toml", "yaml", or "unknown"

// Validate data format
serde_validate(data, format) -> boolean
```

## Usage Examples

### Basic Serialization

```mufi
let data = {
    name: "John Doe",
    age: 30,
    hobbies: ["reading", "coding"],
    address: {
        street: "123 Main St",
        city: "Anytown"
    }
}

// JSON (compact)
let json = serde_to_json(data)
// Output: {"name":"John Doe","age":30,"hobbies":["reading","coding"],"address":{"street":"123 Main St","city":"Anytown"}}

// JSON (pretty)
let pretty_json = serde_to_json(data, true)
// Output:
// {
//   "name": "John Doe",
//   "age": 30,
//   "hobbies": [
//     "reading",
//     "coding"
//   ],
//   "address": {
//     "street": "123 Main St",
//     "city": "Anytown"
//   }
// }

// YAML
let yaml = serde_to_yaml(data)
// Output:
// ---
// name: John Doe
// age: 30
// hobbies:
//   - reading
//   - coding
// address:
//   street: 123 Main St
//   city: Anytown
```

### Complex Numbers

```mufi
let complex_num = 3 + 4i
let json = serde_to_json(complex_num, true)
// Output:
// {
//   "r": 3.0,
//   "i": 4.0
// }

let yaml = serde_to_yaml(complex_num)
// Output:
// ---
// real: 3.0
// imag: 4.0
```

### Float Vectors and Matrices

```mufi
let vector = fvec([1.1, 2.2, 3.3])
let json = serde_to_json(vector)
// Output: [1.1, 2.2, 3.3]

let matrix = matrix([[1, 2], [3, 4]])
let yaml = serde_to_yaml(matrix)
// Output:
// ---
// - [1, 2]
// - [3, 4]
```

### Deserialization

```mufi
let json_str = '{"name": "Alice", "age": 25}'
let data = serde_from_json(json_str)
// data.name == "Alice"
// data.age == 25

// With format detection
let unknown_data = "name: Bob\nage: 30"
let format = serde_detect_format(unknown_data)  // "yaml"
let parsed = serde_deserialize(unknown_data, format)
```

### Error Handling

```mufi
let invalid_json = '{"key": invalid}'
if serde_validate(invalid_json, "json") {
    let data = serde_from_json(invalid_json)
} else {
    print("Invalid JSON format")
}
```

### Advanced Options

```mufi
let options = {
    pretty: true,
    indent: "    ",  // 4 spaces
    max_depth: 50,
    sort_keys: true
}

let json = serde_serialize(data, "json", options)
```

## Extending the Interface

### Adding a New Format

To add support for a new serialization format:

1. **Create format module** (e.g., `src/stdlib/serde_xml.zig`)
2. **Implement serializer struct**:
   ```zig
   pub const XmlSerializer = struct {
       // ... fields ...
       
       pub fn serialize(
           self: *Self,
           value: Value,
           options: SerializeOptions,
           context: *SerdeContext,
       ) SerdeError![]const u8 {
           // Implementation
       }
       
       pub fn supportsType(self: *Self, value_type: ValueType) bool {
           // Return true for supported types
       }
   };
   ```

3. **Implement deserializer struct**:
   ```zig
   pub const XmlDeserializer = struct {
       // ... fields ...
       
       pub fn deserialize(
           self: *Self,
           data: []const u8,
           options: DeserializeOptions,
           context: *SerdeContext,
       ) SerdeError!Value {
           // Implementation
       }
       
       pub fn canDeserialize(self: *Self, data: []const u8) bool {
           // Format detection logic
       }
   };
   ```

4. **Register format**:
   ```zig
   pub fn registerXmlFormat(allocator: std.mem.Allocator) !void {
       const registry = serde.getGlobalRegistry(allocator);
       const extensions = [_][]const u8{".xml"};
       
       try registry.registerFormat(
           "xml",
           &extensions,
           serializeXml,
           deserializeXml,
           detectXmlFormat,
       );
   }
   ```

5. **Add stdlib functions** in `src/stdlib/serde.zig`

### Custom Object Serialization

For custom object types, implement serialization in the format-specific modules:

```zig
fn serializeCustomObject(
    self: *Self,
    obj: *CustomObject,
    options: SerializeOptions,
    context: *SerdeContext,
) SerdeError!void {
    // Custom serialization logic
}
```

## Error Handling

### Error Types

```zig
pub const SerdeError = error{
    UnsupportedType,     // Type not supported by format
    InvalidFormat,       // Invalid syntax in input
    OutOfMemory,         // Memory allocation failure
    TooDeep,            // Maximum nesting depth exceeded
    InvalidKey,         // Invalid key type (must be string)
    CircularReference,  // Circular reference detected
    ParseError,         // Generic parsing error
    MissingField,       // Required field missing
    TypeMismatch,       // Type mismatch during deserialization
    InvalidNumber,      // Invalid number format
    InvalidEscape,      // Invalid string escape sequence
    UnexpectedEnd,      // Unexpected end of input
    NotSupported,       // Feature not supported by format
};
```

### Error Context

The Serde interface provides detailed error context:

```zig
pub const SerdeContext = struct {
    path: std.ArrayList([]const u8),  // Path to error location
    line: ?u32 = null,                // Line number (if available)
    column: ?u32 = null,              // Column number (if available)
};
```

## Performance Considerations

### Memory Management

- **Allocation Strategy**: Uses provided allocator for all memory operations
- **String Interning**: JSON implementation uses MufiZ string interning
- **Buffer Reuse**: Serializers reuse internal buffers where possible

### Optimization Tips

1. **Reuse Serializers**: Create serializer instances once and reuse
2. **Set Appropriate Limits**: Use `max_depth` to prevent stack overflow
3. **Choose Format Wisely**: JSON is fastest, YAML has most features
4. **Use Compact Mode**: Set `pretty: false` for smaller output

### Benchmarks

| Operation | Format | Time (μs) | Memory (KB) |
|-----------|--------|-----------|-------------|
| Serialize small object | JSON | 15 | 2 |
| Serialize large array | JSON | 150 | 25 |
| Deserialize JSON | JSON | 45 | 8 |
| Serialize to YAML | YAML | 85 | 12 |

## Future Enhancements

### Planned Features

1. **Complete TOML Implementation**: Full TOML parsing support
2. **Complete YAML Implementation**: Full YAML parsing with anchors/references
3. **Binary Formats**: MessagePack, Protocol Buffers support
4. **Streaming**: Large data streaming serialization/deserialization
5. **Schema Validation**: JSON Schema, YAML Schema validation
6. **Custom Formatters**: User-defined serialization formats

### Experimental Features

1. **Async Support**: Asynchronous serialization for large datasets
2. **Compression**: Automatic compression for binary formats
3. **Encryption**: Built-in encryption for sensitive data

## Migration Guide

### From Existing JSON Module

If you're currently using the standalone JSON module (`src/stdlib/json.zig`):

**Before:**
```mufi
let json_str = json_stringify(data)
let parsed = json_parse(json_str)
```

**After:**
```mufi
let json_str = serde_to_json(data)
let parsed = serde_from_json(json_str)
```

### Benefits of Migration

1. **Unified Interface**: Same API for all formats
2. **Better Error Handling**: Detailed error context
3. **More Options**: Configurable serialization options
4. **Future Proof**: Easy to add new formats
5. **Type Safety**: Better type checking and validation

## Contributing

To contribute to the Serde interface:

1. **Format Implementations**: Help complete TOML/YAML parsers
2. **New Formats**: Add support for new serialization formats
3. **Performance**: Optimize serialization performance
4. **Testing**: Add comprehensive test cases
5. **Documentation**: Improve documentation and examples

## License

The MufiZ Serde interface is part of the MufiZ project and follows the same license terms.