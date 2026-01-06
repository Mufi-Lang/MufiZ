/// MufiZ Serde Interface Tests
///
/// This file contains unit tests for the Serde interface to ensure
/// serialization and deserialization work correctly across different formats.
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

const serde = @import("../src/serde.zig");
const serde_json = @import("../src/stdlib/serde_json.zig");
const serde_toml = @import("../src/stdlib/serde_toml.zig");
const serde_yaml = @import("../src/stdlib/serde_yaml.zig");
const Value = @import("../src/value.zig").Value;
const Complex = @import("../src/value.zig").Complex;
const object_h = @import("../src/object.zig");

// Test allocator
var test_allocator = std.testing.allocator;

test "serde interface - basic value serialization" {
    // Register formats
    try serde_json.registerJsonFormat(test_allocator);
    try serde_yaml.registerYamlFormat(test_allocator);

    const test_values = [_]struct {
        value: Value,
        expected_json: []const u8,
        expected_yaml: []const u8,
    }{
        .{
            .value = Value.init_nil(),
            .expected_json = "null",
            .expected_yaml = "---\nnull\n",
        },
        .{
            .value = Value.init_bool(true),
            .expected_json = "true",
            .expected_yaml = "---\ntrue\n",
        },
        .{
            .value = Value.init_bool(false),
            .expected_json = "false",
            .expected_yaml = "---\nfalse\n",
        },
        .{
            .value = Value.init_int(42),
            .expected_json = "42",
            .expected_yaml = "---\n42\n",
        },
        .{
            .value = Value.init_double(3.14),
            .expected_json = "3.14",
            .expected_yaml = "---\n3.14\n",
        },
    };

    for (test_values) |test_case| {
        // Test JSON serialization
        const json_result = try serde.serialize(test_case.value, "json", .{}, test_allocator);
        defer test_allocator.free(json_result);
        try expectEqualStrings(test_case.expected_json, json_result);

        // Test YAML serialization
        const yaml_result = try serde.serialize(test_case.value, "yaml", .{}, test_allocator);
        defer test_allocator.free(yaml_result);
        try expectEqualStrings(test_case.expected_yaml, yaml_result);
    }
}

test "serde interface - complex number serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    const complex_value = Value.init_complex(Complex{ .r = 1.0, .i = 2.0 });

    // Test JSON serialization
    const json_result = try serde.serialize(complex_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);
    try expectEqualStrings("{\"r\":1,\"i\":2}", json_result);

    // Test pretty JSON serialization
    const pretty_json = try serde.serialize(complex_value, "json", .{ .pretty = true }, test_allocator);
    defer test_allocator.free(pretty_json);
    const expected_pretty =
        \\{
        \\  "r": 1,
        \\  "i": 2
        \\}
    ;
    try expectEqualStrings(expected_pretty, pretty_json);
}

test "serde interface - string serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    const str_obj = object_h.copyString("hello world".ptr, "hello world".len);
    const string_value = Value.init_obj(@ptrCast(str_obj));

    const json_result = try serde.serialize(string_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);
    try expectEqualStrings("\"hello world\"", json_result);
}

test "serde interface - hash table serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    // Create a hash table
    const hash_table = object_h.ObjHashTable.init();

    // Add some key-value pairs
    const name_str = object_h.copyString("John".ptr, "John".len);
    hash_table.set("name", Value.init_obj(@ptrCast(name_str)));
    hash_table.set("age", Value.init_int(30));
    hash_table.set("active", Value.init_bool(true));

    const table_value = Value.init_obj(@ptrCast(hash_table));

    const json_result = try serde.serialize(table_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);

    // Note: Hash table order may vary, so we check for key components
    try expect(std.mem.indexOf(u8, json_result, "\"name\":\"John\"") != null);
    try expect(std.mem.indexOf(u8, json_result, "\"age\":30") != null);
    try expect(std.mem.indexOf(u8, json_result, "\"active\":true") != null);
}

test "serde interface - linked list serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    // Create a linked list
    const list = object_h.LinkedList.init(test_allocator);
    list.append(Value.init_int(1));
    list.append(Value.init_int(2));
    list.append(Value.init_int(3));

    const list_value = Value.init_obj(@ptrCast(list));

    const json_result = try serde.serialize(list_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);
    try expectEqualStrings("[1,2,3]", json_result);

    // Test pretty printing
    const pretty_result = try serde.serialize(list_value, "json", .{ .pretty = true }, test_allocator);
    defer test_allocator.free(pretty_result);
    const expected_pretty =
        \\[
        \\  1,
        \\  2,
        \\  3
        \\]
    ;
    try expectEqualStrings(expected_pretty, pretty_result);
}

test "serde interface - format detection" {
    try serde_json.registerJsonFormat(test_allocator);
    try serde_yaml.registerYamlFormat(test_allocator);

    const registry = serde.getGlobalRegistry(test_allocator);

    // Test JSON detection
    const json_data = "{\"key\": \"value\"}";
    const json_format = registry.detectFormat(json_data);
    try expect(json_format != null);
    try expectEqualStrings("json", json_format.?.name);

    // Test YAML detection
    const yaml_data = "key: value\nother: data";
    const yaml_format = registry.detectFormat(yaml_data);
    try expect(yaml_format != null);
    try expectEqualStrings("yaml", yaml_format.?.name);

    // Test unknown format
    const unknown_data = "this is not a known format";
    const unknown_format = registry.detectFormat(unknown_data);
    try expect(unknown_format == null);
}

test "serde interface - json round-trip" {
    try serde_json.registerJsonFormat(test_allocator);

    // Test simple values round-trip
    const test_values = [_]Value{
        Value.init_nil(),
        Value.init_bool(true),
        Value.init_bool(false),
        Value.init_int(42),
        Value.init_double(3.14159),
    };

    for (test_values) |original_value| {
        // Serialize
        const serialized = try serde.serialize(original_value, "json", .{}, test_allocator);
        defer test_allocator.free(serialized);

        // Deserialize
        const deserialized = try serde.deserialize(serialized, "json", .{}, test_allocator);

        // Compare types (basic check)
        try expectEqual(original_value.type, deserialized.type);

        // Compare values based on type
        switch (original_value.type) {
            .VAL_NIL => {}, // nil values are equal
            .VAL_BOOL => try expectEqual(original_value.as.boolean, deserialized.as.boolean),
            .VAL_INT => try expectEqual(original_value.as.num_int, deserialized.as.num_int),
            .VAL_DOUBLE => try expectEqual(original_value.as.num_double, deserialized.as.num_double),
            else => {}, // Skip other types for this basic test
        }
    }
}

test "serde interface - error handling" {
    try serde_json.registerJsonFormat(test_allocator);

    // Test invalid JSON
    const invalid_json = "{invalid json}";
    const result = serde.deserialize(invalid_json, "json", .{}, test_allocator);
    try expect(std.meta.isError(result));
}

test "serde interface - options handling" {
    try serde_json.registerJsonFormat(test_allocator);

    const test_value = Value.init_int(42);

    // Test default options
    const default_result = try serde.serialize(test_value, "json", .{}, test_allocator);
    defer test_allocator.free(default_result);
    try expectEqualStrings("42", default_result);

    // Test with pretty printing (though for simple int it won't change much)
    const pretty_options = serde.SerializeOptions{ .pretty = true, .indent = "    " };
    const pretty_result = try serde.serialize(test_value, "json", pretty_options, test_allocator);
    defer test_allocator.free(pretty_result);
    try expectEqualStrings("42", pretty_result);

    // Test max depth (create nested structure)
    const hash_table = object_h.ObjHashTable.init();
    hash_table.set("value", test_value);
    const nested_value = Value.init_obj(@ptrCast(hash_table));

    const depth_options = serde.SerializeOptions{ .max_depth = 1 };
    const depth_result = serde.serialize(nested_value, "json", depth_options, test_allocator);
    // This should succeed since we're only 1 level deep
    try expect(!std.meta.isError(depth_result));
    if (!std.meta.isError(depth_result)) {
        test_allocator.free(depth_result catch unreachable);
    }
}

test "serde interface - float vector serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    // Create a float vector
    const fvec = object_h.FloatVector.init(test_allocator, 3);
    fvec.data[0] = 1.1;
    fvec.data[1] = 2.2;
    fvec.data[2] = 3.3;
    fvec.size = 3;

    const fvec_value = Value.init_obj(@ptrCast(fvec));

    const json_result = try serde.serialize(fvec_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);
    try expectEqualStrings("[1.1, 2.2, 3.3]", json_result);
}

test "serde interface - range serialization" {
    try serde_json.registerJsonFormat(test_allocator);

    // Create a range object
    const range = object_h.ObjRange.init(1, 10, true);
    const range_value = Value.init_obj(@ptrCast(range));

    const json_result = try serde.serialize(range_value, "json", .{}, test_allocator);
    defer test_allocator.free(json_result);
    try expectEqualStrings("{\"start\": 1, \"end\": 10, \"inclusive\": true}", json_result);
}

test "serde interface - unsupported type handling" {
    try serde_json.registerJsonFormat(test_allocator);

    // Try to serialize an unsupported format
    const result = serde.serialize(Value.init_int(42), "unsupported_format", .{}, test_allocator);
    try expectEqual(serde.SerdeError.NotSupported, result);
}

test "serde interface - registry functionality" {
    const registry = serde.getGlobalRegistry(test_allocator);

    // Register JSON format
    try serde_json.registerJsonFormat(test_allocator);

    // Test getting format by name
    const json_format = registry.getByName("json");
    try expect(json_format != null);
    try expectEqualStrings("json", json_format.?.name);

    // Test getting format by extension
    const json_by_ext = registry.getByExtension(".json");
    try expect(json_by_ext != null);
    try expectEqualStrings("json", json_by_ext.?.name);

    // Test non-existent format
    const nonexistent = registry.getByName("nonexistent");
    try expect(nonexistent == null);
}

test "serde interface - context error handling" {
    var context = serde.SerdeContext.init(test_allocator);
    defer context.deinit();

    // Test path manipulation
    try context.pushPath("root");
    try context.pushPath("child");

    try expectEqualStrings("child", context.getPath());

    context.popPath();
    try expectEqualStrings("root", context.getPath());

    context.popPath();
    try expectEqualStrings("root", context.getPath()); // Should handle empty path gracefully
}
