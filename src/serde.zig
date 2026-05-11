const system = @import("system.zig");

/// MufiZ Serialization/Deserialization (Serde) Interface
///
/// This module provides a common interface for serializing and deserializing
/// MufiZ values to and from various formats (JSON, TOML, YAML, etc.).
///
/// ## Design Goals
/// - Format-agnostic serialization interface
/// - Type-safe handling of all MufiZ value types
/// - Extensible for new formats
/// - Error handling with detailed context
/// - Support for nested structures and complex types
///
/// ## Usage Example
/// ```zig
/// var json_serializer = JsonSerializer.init(allocator);
/// const json_str = try serde.serialize(Value, value, json_serializer);
///
/// var json_deserializer = JsonDeserializer.init(json_str, allocator);
/// const parsed_value = try serde.deserialize(Value, json_deserializer);
/// ```
const std = @import("std");
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const Complex = @import("value.zig").Complex;
const object_h = @import("object.zig");
const Obj = object_h.Obj;
const ObjType = object_h.ObjType;
const ObjString = object_h.ObjString;
const ObjHashTable = object_h.ObjHashTable;
const LinkedList = object_h.LinkedList;
const FloatVector = object_h.FloatVector;
const Matrix = object_h.Matrix;
const ObjRange = object_h.ObjRange;
const ObjPair = object_h.ObjPair;

/// Error types for serialization/deserialization operations
pub const SerdeError = error{
    /// Unsupported value type for the current format
    UnsupportedType,
    /// Invalid format or syntax in input data
    InvalidFormat,
    /// Memory allocation failure
    OutOfMemory,
    /// Maximum nesting depth exceeded
    TooDeep,
    /// Invalid key type (must be string for most formats)
    InvalidKey,
    /// Circular reference detected
    CircularReference,
    /// Generic parsing error
    ParseError,
    /// Missing required field
    MissingField,
    /// Type mismatch during deserialization
    TypeMismatch,
    /// Invalid number format
    InvalidNumber,
    /// Invalid string escape sequence
    InvalidEscape,
    /// Unexpected end of input
    UnexpectedEnd,
    /// Feature not supported by format
    NotSupported,
};

/// Context information for error reporting
pub const SerdeContext = struct {
    path: std.ArrayList([]const u8),
    line: ?u32 = null,
    column: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator) SerdeContext {
        return SerdeContext{
            .path = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .line = null,
            .column = null,
        };
    }

    pub fn deinit(self: *SerdeContext, allocator: std.mem.Allocator) void {
        self.path.deinit(allocator);
    }

    pub fn pushPath(self: *SerdeContext, segment: []const u8) !void {
        try self.path.append(segment);
    }

    pub fn popPath(self: *SerdeContext) void {
        _ = self.path.pop();
    }

    pub fn getPath(self: *const SerdeContext) []const u8 {
        if (self.path.items.len == 0) return "root";
        // Return the last path segment for now
        // Full path joining with '.' would require allocation
        // and should be done by the caller if needed
        return self.path.items[self.path.items.len - 1];
    }

    /// Get the full path joined with '.' separator
    /// Caller owns the returned memory and must free it
    pub fn getFullPath(self: *const SerdeContext, allocator: std.mem.Allocator) ![]const u8 {
        if (self.path.items.len == 0) {
            return try allocator.dupe(u8, "root");
        }

        if (self.path.items.len == 1) {
            return try allocator.dupe(u8, self.path.items[0]);
        }

        // Calculate total length needed
        var total_len: usize = 0;
        for (self.path.items) |segment| {
            total_len += segment.len;
        }
        // Add separators (len - 1 dots)
        total_len += self.path.items.len - 1;

        // Allocate and build the path
        var result = try allocator.alloc(u8, total_len);
        var pos: usize = 0;
        
        for (self.path.items, 0..) |segment, i| {
            @memcpy(result[pos..pos + segment.len], segment);
            pos += segment.len;
            if (i < self.path.items.len - 1) {
                result[pos] = '.';
                pos += 1;
            }
        }

        return result;
    }
};

/// Configuration options for serialization
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

/// Configuration options for deserialization
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

/// Trait for types that can serialize MufiZ values
pub fn Serializer(comptime T: type) type {
    return struct {
        const Self = @This();

        // Required methods that implementers must provide
        pub fn serialize(self: *T, value: Value, options: SerializeOptions, context: *SerdeContext) SerdeError![]const u8 {
            _ = self;
            _ = value;
            _ = options;
            _ = context;
            @compileError("serialize method must be implemented by " ++ @typeName(T));
        }

        pub fn supportsType(self: *T, value_type: ValueType) bool {
            _ = self;
            _ = value_type;
            @compileError("supportsType method must be implemented by " ++ @typeName(T));
        }
    };
}

/// Trait for types that can deserialize to MufiZ values
pub fn Deserializer(comptime T: type) type {
    return struct {
        const Self = @This();

        // Required methods that implementers must provide
        pub fn deserialize(self: *T, data: []const u8, options: DeserializeOptions, context: *SerdeContext) SerdeError!Value {
            _ = self;
            _ = data;
            _ = options;
            _ = context;
            @compileError("deserialize method must be implemented by " ++ @typeName(T));
        }

        pub fn canDeserialize(self: *T, data: []const u8) bool {
            _ = self;
            _ = data;
            @compileError("canDeserialize method must be implemented by " ++ @typeName(T));
        }
    };
}

/// Format registry for dynamic format selection
pub const FormatRegistry = struct {
    const FormatEntry = struct {
        name: []const u8,
        extensions: []const []const u8,
        serialize_fn: *const fn (Value, SerializeOptions, std.mem.Allocator) SerdeError![]const u8,
        deserialize_fn: *const fn ([]const u8, DeserializeOptions, std.mem.Allocator) SerdeError!Value,
        detect_fn: *const fn ([]const u8) bool,
    };

    formats: std.ArrayList(FormatEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FormatRegistry {
        return FormatRegistry{
            .formats = std.ArrayList(FormatEntry).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FormatRegistry) void {
        self.formats.deinit(self.allocator);
    }

    pub fn registerFormat(
        self: *FormatRegistry,
        name: []const u8,
        extensions: []const []const u8,
        serialize_fn: *const fn (Value, SerializeOptions, std.mem.Allocator) SerdeError![]const u8,
        deserialize_fn: *const fn ([]const u8, DeserializeOptions, std.mem.Allocator) SerdeError!Value,
        detect_fn: *const fn ([]const u8) bool,
    ) !void {
        const entry = FormatEntry{
            .name = name,
            .extensions = extensions,
            .serialize_fn = serialize_fn,
            .deserialize_fn = deserialize_fn,
            .detect_fn = detect_fn,
        };
        try self.formats.append(entry);
    }

    pub fn getByName(self: *const FormatRegistry, name: []const u8) ?*const FormatEntry {
        for (self.formats.items) |*entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry;
            }
        }
        return null;
    }

    pub fn getByExtension(self: *const FormatRegistry, extension: []const u8) ?*const FormatEntry {
        for (self.formats.items) |*entry| {
            for (entry.extensions) |ext| {
                if (std.mem.eql(u8, ext, extension)) {
                    return entry;
                }
            }
        }
        return null;
    }

    pub fn detectFormat(self: *const FormatRegistry, data: []const u8) ?*const FormatEntry {
        for (self.formats.items) |*entry| {
            if (entry.detect_fn(data)) {
                return entry;
            }
        }
        return null;
    }
};

/// Global format registry instance
var global_registry: ?FormatRegistry = null;

/// Get or initialize the global format registry
pub fn getGlobalRegistry(allocator: std.mem.Allocator) *FormatRegistry {
    if (global_registry == null) {
        global_registry = FormatRegistry.init(allocator);
    }
    return &global_registry.?;
}

/// High-level serialization function
pub fn serialize(
    value: Value,
    format: []const u8,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) SerdeError![]const u8 {
    const registry = getGlobalRegistry(allocator);
    const format_entry = registry.getByName(format) orelse return SerdeError.NotSupported;

    return format_entry.serialize_fn(value, options, allocator);
}

/// High-level deserialization function
pub fn deserialize(
    data: []const u8,
    format: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value {
    const registry = getGlobalRegistry(allocator);
    const format_entry = registry.getByName(format) orelse return SerdeError.NotSupported;

    return format_entry.deserialize_fn(data, options, allocator);
}

/// Auto-detect format and deserialize
pub fn deserializeAuto(
    data: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value {
    const registry = getGlobalRegistry(allocator);
    const format_entry = registry.detectFormat(data) orelse return SerdeError.InvalidFormat;

    return format_entry.deserialize_fn(data, options, allocator);
}

/// Serialize to file
pub fn serializeToFile(
    value: Value,
    file_path: []const u8,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) !void {
    const registry = getGlobalRegistry(allocator);

    // Detect format by file extension
    const extension = std.fs.path.extension(file_path);
    const format_entry = registry.getByExtension(extension) orelse return SerdeError.NotSupported;

    // Serialize to string
    const serialized_data = try format_entry.serialize_fn(value, options, allocator);
    defer allocator.free(serialized_data);

    // Write to file
    const file = try std.Io.Dir.cwd().createFile(system.global_io, file_path, .{});
    defer file.close(system.global_io);
    try file.writeStreamingAll(system.global_io, serialized_data);
}

/// Deserialize from file
pub fn deserializeFromFile(
    file_path: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) !Value {
    const registry = getGlobalRegistry(allocator);

    // Read file content
    const file = try std.Io.Dir.cwd().openFile(system.global_io, file_path, .{});
    defer file.close(system.global_io);
    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);
    _ = try file.readAll(content);

    // Detect format by file extension
    const extension = std.fs.path.extension(file_path);
    const format_entry = registry.getByExtension(extension) orelse {
        // Try auto-detection if extension is unknown
        const detected_entry = registry.detectFormat(content) orelse return SerdeError.InvalidFormat;
        return detected_entry.deserialize_fn(content, options, allocator);
    };

    return format_entry.deserialize_fn(content, options, allocator);
}

/// Utility to check if a value type is supported for serialization
pub fn isSerializableType(value_type: ValueType) bool {
    return switch (value_type) {
        .VAL_BOOL, .VAL_NIL, .VAL_INT, .VAL_DOUBLE, .VAL_COMPLEX => true,
        .VAL_OBJ => true, // Will be checked per object type
    };
}

/// Utility to check if an object type is supported for serialization
pub fn isSerializableObjType(obj_type: ObjType) bool {
    return switch (obj_type) {
        .OBJ_STRING => true,
        .OBJ_HASH_TABLE => true,
        .OBJ_LINKED_LIST => true,
        .OBJ_FVECTOR => true,
        .OBJ_MATRIX => true,
        .OBJ_RANGE => true,
        .OBJ_PAIR => true,
        // Functions and other runtime objects are generally not serializable
        .OBJ_FUNCTION, .OBJ_CLOSURE, .OBJ_NATIVE, .OBJ_UPVALUE, .OBJ_BOUND_METHOD => false,
        .OBJ_CLASS, .OBJ_INSTANCE => false, // Could be supported in the future
        .OBJ_MATRIX_ROW => false, // Views are not serializable
    };
}

/// Create a deep copy of a Value (useful for deserialization)
/// 
/// This function recursively clones a Value and all its contained data structures.
/// Primitive types (bool, nil, int, double, complex) are copied by value.
/// Object types are recursively cloned with new allocations:
/// - Strings: shared (immutable and interned)
/// - Vectors: data array is deep copied
/// - Hash tables: all entries are recursively cloned
/// - Matrices: data array is deep copied
/// - Linked lists: all nodes and values are recursively cloned
/// - Pairs: both elements are recursively cloned
/// - Ranges: copied by value
/// - Functions/Classes: shared (not typically cloned)
///
/// Returns: A new Value with independent memory allocations
/// Errors: OutOfMemory if allocation fails during cloning
pub fn cloneValue(value: Value, allocator: std.mem.Allocator) !Value {
    switch (value.type) {
        .VAL_BOOL, .VAL_NIL, .VAL_INT, .VAL_DOUBLE, .VAL_COMPLEX => {
            // Primitive types can be copied directly
            return value;
        },
        .VAL_OBJ => {
            const obj = value.as.obj;
            switch (obj.type) {
                .OBJ_STRING => {
                    // Strings are immutable and interned, so we can share the reference
                    return value;
                },
                .OBJ_FVECTOR => {
                    // Clone float vector using proper constructor
                    const original = @as(*FloatVector, @ptrCast(@alignCast(obj)));
                    const new_vector = FloatVector.init(original.size);
                    
                    // Copy data
                    new_vector.count = original.count;
                    @memcpy(new_vector.data[0..original.count], original.data[0..original.count]);
                    new_vector.sorted = original.sorted;
                    
                    return Value.init_obj(@as(*Obj, @ptrCast(new_vector)));
                },
                .OBJ_HASH_TABLE => {
                    // Clone hash table using proper constructor
                    const original = @as(*ObjHashTable, @ptrCast(@alignCast(obj)));
                    const new_table = object_h.HashTable.init();
                    
                    // Copy all entries using the put method
                    var iterator = original.iterator();
                    while (iterator.next()) |entry| {
                        const cloned_value = try cloneValue(entry.value, allocator);
                        _ = new_table.put(entry.key, cloned_value);
                    }
                    return Value.init_obj(@as(*Obj, @ptrCast(new_table)));
                },
                .OBJ_MATRIX => {
                    // Clone matrix using proper constructor
                    const original = @as(*Matrix, @ptrCast(@alignCast(obj)));
                    const new_matrix = Matrix.init(original.rows, original.cols);
                    
                    // Copy data
                    const total_size = original.rows * original.cols;
                    @memcpy(new_matrix.data[0..total_size], original.data[0..total_size]);
                    
                    return Value.init_obj(@as(*Obj, @ptrCast(new_matrix)));
                },
                .OBJ_LINKED_LIST => {
                    // Clone linked list using proper constructor
                    const original = @as(*LinkedList, @ptrCast(@alignCast(obj)));
                    const new_list = LinkedList.init();
                    
                    // Copy all nodes using push method
                    var current = original.head;
                    while (current) |node| {
                        const cloned_value = try cloneValue(node.data, allocator);
                        new_list.push(cloned_value);
                        current = node.next;
                    }
                    return Value.init_obj(@as(*Obj, @ptrCast(new_list)));
                },
                .OBJ_RANGE => {
                    // Ranges are small value types, safe to copy
                    return value;
                },
                .OBJ_PAIR => {
                    // Clone pair using proper constructor
                    const original = @as(*ObjPair, @ptrCast(@alignCast(obj)));
                    const cloned_key = try cloneValue(original.key, allocator);
                    const cloned_value = try cloneValue(original.value, allocator);
                    const new_pair = ObjPair.create(cloned_key, cloned_value);
                    return Value.init_obj(@as(*Obj, @ptrCast(new_pair)));
                },
                else => {
                    // For other object types (functions, classes, etc.),
                    // return the original as they're not typically cloned
                    // or we'd need VM context to clone them properly
                    return value;
                },
            }
        },
    }
}

/// Helper to create error messages with context
pub fn contextError(
    comptime format: []const u8,
    args: anytype,
    context: *const SerdeContext,
    allocator: std.mem.Allocator,
) ![]u8 {
    const path = context.getPath();
    if (context.line) |line| {
        return std.fmt.allocPrint(allocator, "Error at {s}:{d}:{d}: " ++ format, .{ path, line, context.column orelse 0 } ++ args);
    } else {
        return std.fmt.allocPrint(allocator, "Error at {s}: " ++ format, .{path} ++ args);
    }
}

// Test utilities for format implementations
pub const testing = struct {
    pub fn expectSerializeRoundtrip(
        value: Value,
        format: []const u8,
        allocator: std.mem.Allocator,
    ) !void {
        const serialized = try serialize(value, format, SerializeOptions{}, allocator);
        defer allocator.free(serialized);

        const deserialized = try deserialize(serialized, format, DeserializeOptions{}, allocator);

        // Compare values for equality
        if (!valuesEqual(value, deserialized)) {
            return error.RoundtripMismatch;
        }
    }

    /// Compare two Values for equality
    fn valuesEqual(a: Value, b: Value) bool {
        // Check type equality first
        if (a.type != b.type) return false;

        return switch (a.type) {
            .VAL_NIL => true,
            .VAL_BOOL => a.as.boolean == b.as.boolean,
            .VAL_INT => a.as.integer == b.as.integer,
            .VAL_DOUBLE => a.as.double == b.as.double,
            .VAL_COMPLEX => a.as.complex.r == b.as.complex.r and a.as.complex.i == b.as.complex.i,
            .VAL_OBJ => objectsEqual(a.as.obj, b.as.obj),
        };
    }

    /// Compare two Objects for equality
    fn objectsEqual(a: *Obj, b: *Obj) bool {
        if (a.type != b.type) return false;

        return switch (a.type) {
            .OBJ_STRING => {
                const str_a = @as(*ObjString, @ptrCast(@alignCast(a)));
                const str_b = @as(*ObjString, @ptrCast(@alignCast(b)));
                return std.mem.eql(u8, str_a.chars, str_b.chars);
            },
            .OBJ_FVECTOR => {
                const vec_a = @as(*FloatVector, @ptrCast(@alignCast(a)));
                const vec_b = @as(*FloatVector, @ptrCast(@alignCast(b)));
                if (vec_a.count != vec_b.count) return false;
                for (0..vec_a.count) |i| {
                    if (vec_a.data[i] != vec_b.data[i]) return false;
                }
                return true;
            },
            .OBJ_HASH_TABLE => {
                const table_a = @as(*ObjHashTable, @ptrCast(@alignCast(a)));
                const table_b = @as(*ObjHashTable, @ptrCast(@alignCast(b)));
                if (table_a.map.count != table_b.map.count) return false;
                
                var iter = table_a.iterator();
                while (iter.next()) |entry| {
                    const value_b = table_b.get(entry.key) orelse return false;
                    if (!valuesEqual(entry.value, value_b)) return false;
                }
                return true;
            },
            .OBJ_MATRIX => {
                const mat_a = @as(*Matrix, @ptrCast(@alignCast(a)));
                const mat_b = @as(*Matrix, @ptrCast(@alignCast(b)));
                if (mat_a.rows != mat_b.rows or mat_a.cols != mat_b.cols) return false;
                const size = mat_a.rows * mat_a.cols;
                for (0..size) |i| {
                    if (mat_a.data[i] != mat_b.data[i]) return false;
                }
                return true;
            },
            .OBJ_LINKED_LIST => {
                const list_a = @as(*LinkedList, @ptrCast(@alignCast(a)));
                const list_b = @as(*LinkedList, @ptrCast(@alignCast(b)));
                if (list_a.count != list_b.count) return false;
                
                var node_a = list_a.head;
                var node_b = list_b.head;
                while (node_a != null and node_b != null) {
                    if (!valuesEqual(node_a.?.data, node_b.?.data)) return false;
                    node_a = node_a.?.next;
                    node_b = node_b.?.next;
                }
                return node_a == null and node_b == null;
            },
            .OBJ_PAIR => {
                const pair_a = @as(*ObjPair, @ptrCast(@alignCast(a)));
                const pair_b = @as(*ObjPair, @ptrCast(@alignCast(b)));
                return valuesEqual(pair_a.key, pair_b.key) and 
                       valuesEqual(pair_a.value, pair_b.value);
            },
            .OBJ_RANGE => {
                const range_a = @as(*ObjRange, @ptrCast(@alignCast(a)));
                const range_b = @as(*ObjRange, @ptrCast(@alignCast(b)));
                return range_a.start == range_b.start and 
                       range_a.end == range_b.end and
                       range_a.inclusive == range_b.inclusive;
            },
            else => {
                // For other types (functions, classes, etc.), use pointer equality
                return a == b;
            },
        };
    }
};
