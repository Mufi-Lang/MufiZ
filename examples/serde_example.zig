/// MufiZ Serde Interface Example
///
/// This example demonstrates how to use the common Serde interface
/// to serialize and deserialize MufiZ values to/from different formats
/// (JSON, TOML, YAML).
///
/// Usage:
/// zig run examples/serde_example.zig
const std = @import("std");
const serde = @import("../src/serde.zig");
const serde_json = @import("../src/stdlib/serde_json.zig");
const serde_toml = @import("../src/stdlib/serde_toml.zig");
const serde_yaml = @import("../src/stdlib/serde_yaml.zig");
const Value = @import("../src/value.zig").Value;
const Complex = @import("../src/value.zig").Complex;
const object_h = @import("../src/object.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== MufiZ Serde Interface Demo ===\n\n");

    // Register all formats
    try serde_json.registerJsonFormat(allocator);
    try serde_toml.registerTomlFormat(allocator);
    try serde_yaml.registerYamlFormat(allocator);

    // Example 1: Basic value serialization
    std.debug.print("1. Basic Values:\n");
    try demonstrateBasicValues(allocator);

    // Example 2: Complex numbers
    std.debug.print("\n2. Complex Numbers:\n");
    try demonstrateComplexNumbers(allocator);

    // Example 3: Hash table (object) serialization
    std.debug.print("\n3. Hash Tables (Objects):\n");
    try demonstrateHashTables(allocator);

    // Example 4: Array (LinkedList) serialization
    std.debug.print("\n4. Arrays (LinkedLists):\n");
    try demonstrateArrays(allocator);

    // Example 5: FloatVector serialization
    std.debug.print("\n5. Float Vectors:\n");
    try demonstrateFloatVectors(allocator);

    // Example 6: Format detection
    std.debug.print("\n6. Format Detection:\n");
    try demonstrateFormatDetection(allocator);

    // Example 7: Round-trip serialization
    std.debug.print("\n7. Round-trip Serialization:\n");
    try demonstrateRoundTrip(allocator);

    std.debug.print("\n=== Demo Complete ===\n");
}

fn demonstrateBasicValues(allocator: std.mem.Allocator) !void {
    const values = [_]Value{
        Value.init_nil(),
        Value.init_bool(true),
        Value.init_bool(false),
        Value.init_int(42),
        Value.init_double(3.14159),
    };

    const value_names = [_][]const u8{
        "nil",
        "true",
        "false",
        "42",
        "3.14159",
    };

    for (values, value_names) |value, name| {
        std.debug.print("  {s}:\n", .{name});

        // JSON
        if (serde_json.serializeJson(value, .{}, allocator)) |json| {
            defer allocator.free(json);
            std.debug.print("    JSON: {s}\n", .{json});
        } else |err| {
            std.debug.print("    JSON: Error - {}\n", .{err});
        }

        // YAML
        if (serde_yaml.serializeYaml(value, .{}, allocator)) |yaml| {
            defer allocator.free(yaml);
            std.debug.print("    YAML: {s}\n", .{yaml});
        } else |err| {
            std.debug.print("    YAML: Error - {}\n", .{err});
        }
    }
}

fn demonstrateComplexNumbers(allocator: std.mem.Allocator) !void {
    const complex_values = [_]Complex{
        .{ .r = 1.0, .i = 2.0 },
        .{ .r = -3.5, .i = 4.7 },
        .{ .r = 0.0, .i = 1.0 },
    };

    for (complex_values, 0..) |complex, i| {
        const value = Value.init_complex(complex);
        std.debug.print("  Complex {d} ({d} + {d}i):\n", .{ i + 1, complex.r, complex.i });

        // JSON
        if (serde_json.serializeJson(value, .{ .pretty = true }, allocator)) |json| {
            defer allocator.free(json);
            std.debug.print("    JSON:\n{s}\n", .{json});
        } else |err| {
            std.debug.print("    JSON: Error - {}\n", .{err});
        }

        // YAML
        if (serde_yaml.serializeYaml(value, .{ .pretty = true }, allocator)) |yaml| {
            defer allocator.free(yaml);
            std.debug.print("    YAML:\n{s}\n", .{yaml});
        } else |err| {
            std.debug.print("    YAML: Error - {}\n", .{err});
        }
    }
}

fn demonstrateHashTables(allocator: std.mem.Allocator) !void {
    // Create a hash table with sample data
    const hash_table = object_h.ObjHashTable.init();

    // Add some key-value pairs
    const name_str = object_h.copyString("John Doe".ptr, "John Doe".len);
    hash_table.set("name", Value.init_obj(@ptrCast(name_str)));

    hash_table.set("age", Value.init_int(30));
    hash_table.set("height", Value.init_double(5.9));
    hash_table.set("is_student", Value.init_bool(false));

    const table_value = Value.init_obj(@ptrCast(hash_table));

    std.debug.print("  Sample Object:\n");

    // JSON (pretty)
    if (serde_json.serializeJson(table_value, .{ .pretty = true, .indent = "  " }, allocator)) |json| {
        defer allocator.free(json);
        std.debug.print("    JSON (pretty):\n{s}\n", .{json});
    } else |err| {
        std.debug.print("    JSON: Error - {}\n", .{err});
    }

    // JSON (compact)
    if (serde_json.serializeJson(table_value, .{}, allocator)) |json| {
        defer allocator.free(json);
        std.debug.print("    JSON (compact): {s}\n", .{json});
    } else |err| {
        std.debug.print("    JSON: Error - {}\n", .{err});
    }

    // TOML
    if (serde_toml.serializeToml(table_value, .{}, allocator)) |toml| {
        defer allocator.free(toml);
        std.debug.print("    TOML:\n{s}\n", .{toml});
    } else |err| {
        std.debug.print("    TOML: Error - {}\n", .{err});
    }

    // YAML
    if (serde_yaml.serializeYaml(table_value, .{ .pretty = true }, allocator)) |yaml| {
        defer allocator.free(yaml);
        std.debug.print("    YAML:\n{s}\n", .{yaml});
    } else |err| {
        std.debug.print("    YAML: Error - {}\n", .{err});
    }
}

fn demonstrateArrays(allocator: std.mem.Allocator) !void {
    // Create a linked list with sample data
    const list = object_h.LinkedList.init(allocator);

    list.append(Value.init_int(1));
    list.append(Value.init_int(2));
    list.append(Value.init_int(3));

    const str_obj = object_h.copyString("hello".ptr, "hello".len);
    list.append(Value.init_obj(@ptrCast(str_obj)));

    list.append(Value.init_bool(true));

    const list_value = Value.init_obj(@ptrCast(list));

    std.debug.print("  Sample Array [1, 2, 3, \"hello\", true]:\n");

    // JSON
    if (serde_json.serializeJson(list_value, .{ .pretty = true }, allocator)) |json| {
        defer allocator.free(json);
        std.debug.print("    JSON:\n{s}\n", .{json});
    } else |err| {
        std.debug.print("    JSON: Error - {}\n", .{err});
    }

    // YAML (flow style)
    if (serde_yaml.serializeYaml(list_value, .{ .pretty = false }, allocator)) |yaml| {
        defer allocator.free(yaml);
        std.debug.print("    YAML (flow): {s}\n", .{yaml});
    } else |err| {
        std.debug.print("    YAML: Error - {}\n", .{err});
    }

    // YAML (block style)
    if (serde_yaml.serializeYaml(list_value, .{ .pretty = true }, allocator)) |yaml| {
        defer allocator.free(yaml);
        std.debug.print("    YAML (block):\n{s}\n", .{yaml});
    } else |err| {
        std.debug.print("    YAML: Error - {}\n", .{err});
    }
}

fn demonstrateFloatVectors(allocator: std.mem.Allocator) !void {
    // Create a float vector
    const fvec = object_h.FloatVector.init(allocator, 5);
    fvec.data[0] = 1.1;
    fvec.data[1] = 2.2;
    fvec.data[2] = 3.3;
    fvec.data[3] = 4.4;
    fvec.data[4] = 5.5;
    fvec.size = 5;

    const fvec_value = Value.init_obj(@ptrCast(fvec));

    std.debug.print("  Float Vector [1.1, 2.2, 3.3, 4.4, 5.5]:\n");

    // JSON
    if (serde_json.serializeJson(fvec_value, .{}, allocator)) |json| {
        defer allocator.free(json);
        std.debug.print("    JSON: {s}\n", .{json});
    } else |err| {
        std.debug.print("    JSON: Error - {}\n", .{err});
    }

    // YAML
    if (serde_yaml.serializeYaml(fvec_value, .{}, allocator)) |yaml| {
        defer allocator.free(yaml);
        std.debug.print("    YAML: {s}\n", .{yaml});
    } else |err| {
        std.debug.print("    YAML: Error - {}\n", .{err});
    }
}

fn demonstrateFormatDetection(allocator: std.mem.Allocator) !void {
    const test_data = [_][]const u8{
        "{\"name\": \"John\", \"age\": 30}",
        "name = \"John\"\nage = 30",
        "name: John\nage: 30",
        "[1, 2, 3]",
        "invalid data",
    };

    const registry = serde.getGlobalRegistry(allocator);

    for (test_data) |data| {
        std.debug.print("  Data: {s}\n", .{data});

        if (registry.detectFormat(data)) |format| {
            std.debug.print("    Detected format: {s}\n", .{format.name});
        } else {
            std.debug.print("    Format: Unknown\n");
        }
    }
}

fn demonstrateRoundTrip(allocator: std.mem.Allocator) !void {
    // Create a complex nested structure
    const root_table = object_h.ObjHashTable.init();

    // Add basic values
    root_table.set("name", Value.init_obj(@ptrCast(object_h.copyString("Alice".ptr, "Alice".len))));
    root_table.set("age", Value.init_int(25));
    root_table.set("score", Value.init_double(95.5));

    // Add a nested object
    const nested_table = object_h.ObjHashTable.init();
    nested_table.set("street", Value.init_obj(@ptrCast(object_h.copyString("123 Main St".ptr, "123 Main St".len))));
    nested_table.set("city", Value.init_obj(@ptrCast(object_h.copyString("Anytown".ptr, "Anytown".len))));
    nested_table.set("zip", Value.init_int(12345));
    root_table.set("address", Value.init_obj(@ptrCast(nested_table)));

    // Add an array
    const hobbies = object_h.LinkedList.init(allocator);
    hobbies.append(Value.init_obj(@ptrCast(object_h.copyString("reading".ptr, "reading".len))));
    hobbies.append(Value.init_obj(@ptrCast(object_h.copyString("coding".ptr, "coding".len))));
    hobbies.append(Value.init_obj(@ptrCast(object_h.copyString("hiking".ptr, "hiking".len))));
    root_table.set("hobbies", Value.init_obj(@ptrCast(hobbies)));

    const original_value = Value.init_obj(@ptrCast(root_table));

    std.debug.print("  Testing round-trip serialization:\n");

    // Test JSON round-trip
    if (serde_json.serializeJson(original_value, .{ .pretty = true }, allocator)) |json_str| {
        defer allocator.free(json_str);
        std.debug.print("    Original -> JSON:\n{s}\n", .{json_str});

        if (serde_json.deserializeJson(json_str, .{}, allocator)) |deserialized| {
            std.debug.print("    JSON round-trip: SUCCESS\n");
            _ = deserialized;
        } else |err| {
            std.debug.print("    JSON round-trip: FAILED - {}\n", .{err});
        }
    } else |err| {
        std.debug.print("    JSON serialization: FAILED - {}\n", .{err});
    }

    // Test YAML round-trip (serialization only - deserialization is stub)
    if (serde_yaml.serializeYaml(original_value, .{ .pretty = true }, allocator)) |yaml_str| {
        defer allocator.free(yaml_str);
        std.debug.print("    Original -> YAML:\n{s}\n", .{yaml_str});
        std.debug.print("    YAML serialization: SUCCESS (deserialization not implemented)\n");
    } else |err| {
        std.debug.print("    YAML serialization: FAILED - {}\n", .{err});
    }
}
