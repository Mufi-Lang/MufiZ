/// MufiZ Serde Integration Module
///
/// This module provides MufiZ stdlib functions for serialization and deserialization
/// using the common Serde interface. It integrates with the existing MufiZ function
/// system and provides easy-to-use functions for working with JSON, TOML, and YAML.
///
/// Available Functions:
/// - serde_serialize(value, format, options) -> string
/// - serde_deserialize(data, format, options) -> value
/// - serde_to_json(value, pretty?) -> string
/// - serde_from_json(json_string) -> value
/// - serde_to_toml(value) -> string
/// - serde_from_toml(toml_string) -> value
/// - serde_to_yaml(value, pretty?) -> string
/// - serde_from_yaml(yaml_string) -> value
/// - serde_detect_format(data) -> string
/// - serde_validate(data, format) -> boolean
const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_core = @import("../stdlib_core.zig");
const DefineFunction = stdlib_core.DefineFunction;
const ParamSpec = stdlib_core.ParamSpec;
const ParamType = stdlib_core.ParamType;
const object_h = @import("../object.zig");
const ObjString = object_h.ObjString;
const mem_utils = @import("../mem_utils.zig");

const serde = @import("../serde.zig");
const serde_json = @import("serde_json.zig");
const serde_toml = @import("serde_toml.zig");
const serde_yaml = @import("serde_yaml.zig");

// Initialize all serde formats
fn initSerde() void {
    const allocator = mem_utils.getAllocator();

    // Register all supported formats
    serde_json.registerJsonFormat(allocator) catch |err| {
        std.log.warn("Failed to register JSON format: {}", .{err});
    };

    serde_toml.registerTomlFormat(allocator) catch |err| {
        std.log.warn("Failed to register TOML format: {}", .{err});
    };

    serde_yaml.registerYamlFormat(allocator) catch |err| {
        std.log.warn("Failed to register YAML format: {}", .{err});
    };
}

// Call init on module load
const _ = struct {
    comptime {
        initSerde();
    }
}{};

/// Convert MufiZ stdlib error to Value
fn stdlib_error(comptime format: []const u8, args: anytype) Value {
    _ = format;
    _ = args;
    // For now, just return nil on error
    // In the future, this could create an error object
    return Value.init_nil();
}

/// Get format string from Value
fn getFormatString(value: Value) ?[]const u8 {
    if (!value.is_string()) return null;
    const str_obj = value.as_string();
    return str_obj.chars;
}

/// Get options from hash table Value
fn getSerializeOptions(options_value: ?Value) serde.SerializeOptions {
    var options = serde.SerializeOptions{};

    if (options_value) |opts| {
        if (opts.is_obj() and opts.is_obj_type(.OBJ_HASH_TABLE)) {
            const hash_table = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(opts.as.obj)));

            // Check for "pretty" option
            const pretty_key = "pretty";
            const pretty_str = object_h.copyString(pretty_key.ptr, pretty_key.len);
            if (hash_table.get(pretty_str)) |pretty_val| {
                if (pretty_val.is_bool()) {
                    options.pretty = pretty_val.as.boolean;
                }
            }

            // Check for "indent" option
            const indent_key = "indent";
            const indent_key_str = object_h.copyString(indent_key.ptr, indent_key.len);
            if (hash_table.get(indent_key_str)) |indent_val| {
                if (indent_val.is_string()) {
                    const indent_str = indent_val.as_string();
                    options.indent = indent_str.chars;
                }
            }

            // Check for "max_depth" option
            const max_depth_key = "max_depth";
            const max_depth_str = object_h.copyString(max_depth_key.ptr, max_depth_key.len);
            if (hash_table.get(max_depth_str)) |depth_val| {
                if (depth_val.is_int()) {
                    options.max_depth = @intCast(@max(1, depth_val.as.num_int));
                }
            }

            // Check for "include_nil" option
            const include_nil_key = "include_nil";
            const include_nil_str = object_h.copyString(include_nil_key.ptr, include_nil_key.len);
            if (hash_table.get(include_nil_str)) |nil_val| {
                if (nil_val.is_bool()) {
                    options.include_nil = nil_val.as.boolean;
                }
            }

            // Check for "sort_keys" option
            const sort_keys_key = "sort_keys";
            const sort_keys_str = object_h.copyString(sort_keys_key.ptr, sort_keys_key.len);
            if (hash_table.get(sort_keys_str)) |sort_val| {
                if (sort_val.is_bool()) {
                    options.sort_keys = sort_val.as.boolean;
                }
            }
        }
    }

    return options;
}

/// Get deserialize options from hash table Value
fn getDeserializeOptions(options_value: ?Value) serde.DeserializeOptions {
    var options = serde.DeserializeOptions{};

    if (options_value) |opts| {
        if (opts.is_obj() and opts.is_obj_type(.OBJ_HASH_TABLE)) {
            const hash_table = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(opts.as.obj)));

            // Check for "max_depth" option
            const max_depth_key = "max_depth";
            const max_depth_str = object_h.copyString(max_depth_key.ptr, max_depth_key.len);
            if (hash_table.get(max_depth_str)) |depth_val| {
                if (depth_val.is_int()) {
                    options.max_depth = @intCast(@max(1, depth_val.as.num_int));
                }
            }

            // Check for "strict_types" option
            const strict_types_key = "strict_types";
            const strict_types_str = object_h.copyString(strict_types_key.ptr, strict_types_key.len);
            if (hash_table.get(strict_types_str)) |strict_val| {
                if (strict_val.is_bool()) {
                    options.strict_types = strict_val.as.boolean;
                }
            }

            // Check for "allow_comments" option
            const allow_comments_key = "allow_comments";
            const allow_comments_str = object_h.copyString(allow_comments_key.ptr, allow_comments_key.len);
            if (hash_table.get(allow_comments_str)) |comments_val| {
                if (comments_val.is_bool()) {
                    options.allow_comments = comments_val.as.boolean;
                }
            }

            // Check for "allow_trailing_comma" option
            const allow_trailing_comma_key = "allow_trailing_comma";
            const allow_trailing_comma_str = object_h.copyString(allow_trailing_comma_key.ptr, allow_trailing_comma_key.len);
            if (hash_table.get(allow_trailing_comma_str)) |comma_val| {
                if (comma_val.is_bool()) {
                    options.allow_trailing_comma = comma_val.as.boolean;
                }
            }
        }
    }

    return options;
}

// Implementation functions

fn serde_serialize_impl(argc: i32, args: [*]Value) Value {
    if (argc < 2 or argc > 3) {
        return stdlib_error("serde_serialize() expects 2-3 arguments, got {d}", .{argc});
    }

    const value = args[0];
    const format_value = args[1];
    const options_value = if (argc >= 3) args[2] else null;

    const format_str = getFormatString(format_value) orelse {
        return stdlib_error("serde_serialize() format must be a string", .{});
    };

    const options = getSerializeOptions(options_value);
    const allocator = mem_utils.getAllocator();

    const result = serde.serialize(value, format_str, options, allocator) catch {
        return stdlib_error("serde_serialize() failed", .{});
    };

    // Convert result to MufiZ string
    const str_obj = object_h.copyString(result.ptr, result.len);
    allocator.free(result);
    return Value.init_obj(@ptrCast(str_obj));
}

fn serde_deserialize_impl(argc: i32, args: [*]Value) Value {
    if (argc < 2 or argc > 3) {
        return stdlib_error("serde_deserialize() expects 2-3 arguments, got {d}", .{argc});
    }

    const data_value = args[0];
    const format_value = args[1];
    const options_value = if (argc >= 3) args[2] else null;

    if (!data_value.is_string()) {
        return stdlib_error("serde_deserialize() data must be a string", .{});
    }

    const format_str = getFormatString(format_value) orelse {
        return stdlib_error("serde_deserialize() format must be a string", .{});
    };

    const data_str = data_value.as_string().chars;
    const options = getDeserializeOptions(options_value);
    const allocator = mem_utils.getAllocator();

    return serde.deserialize(data_str, format_str, options, allocator) catch {
        return stdlib_error("serde_deserialize() failed", .{});
    };
}

fn serde_to_json_impl(argc: i32, args: [*]Value) Value {
    if (argc < 1 or argc > 2) {
        return stdlib_error("serde_to_json() expects 1-2 arguments, got {d}", .{argc});
    }

    const value = args[0];
    const pretty = if (argc >= 2 and args[1].is_bool()) args[1].as.boolean else false;

    const options = serde.SerializeOptions{ .pretty = pretty };
    const allocator = mem_utils.getAllocator();

    const result = serde_json.serializeJson(value, options, allocator) catch {
        return stdlib_error("serde_to_json() failed", .{});
    };

    const str_obj = object_h.copyString(result.ptr, result.len);
    allocator.free(result);
    return Value.init_obj(@ptrCast(str_obj));
}

fn serde_from_json_impl(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("serde_from_json() expects 1 argument, got {d}", .{argc});
    }

    const data_value = args[0];
    if (!data_value.is_string()) {
        return stdlib_error("serde_from_json() data must be a string", .{});
    }

    const data_str = data_value.as_string().chars;
    const options = serde.DeserializeOptions{};
    const allocator = mem_utils.getAllocator();

    return serde_json.deserializeJson(data_str, options, allocator) catch {
        return stdlib_error("serde_from_json() failed", .{});
    };
}

fn serde_to_toml_impl(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("serde_to_toml() expects 1 argument, got {d}", .{argc});
    }

    const value = args[0];
    const options = serde.SerializeOptions{};
    const allocator = mem_utils.getAllocator();

    const result = serde_toml.serializeToml(value, options, allocator) catch {
        return stdlib_error("serde_to_toml() failed", .{});
    };

    const str_obj = object_h.copyString(result.ptr, result.len);
    allocator.free(result);
    return Value.init_obj(@ptrCast(str_obj));
}

fn serde_from_toml_impl(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("serde_from_toml() expects 1 argument, got {d}", .{argc});
    }

    const data_value = args[0];
    if (!data_value.is_string()) {
        return stdlib_error("serde_from_toml() data must be a string", .{});
    }

    const data_str = data_value.as_string().chars;
    const options = serde.DeserializeOptions{};
    const allocator = mem_utils.getAllocator();

    return serde_toml.deserializeToml(data_str, options, allocator) catch {
        return stdlib_error("serde_from_toml() failed", .{});
    };
}

fn serde_to_yaml_impl(argc: i32, args: [*]Value) Value {
    if (argc < 1 or argc > 2) {
        return stdlib_error("serde_to_yaml() expects 1-2 arguments, got {d}", .{argc});
    }

    const value = args[0];
    const pretty = if (argc >= 2 and args[1].is_bool()) args[1].as.boolean else true;

    const options = serde.SerializeOptions{ .pretty = pretty };
    const allocator = mem_utils.getAllocator();

    const result = serde_yaml.serializeYaml(value, options, allocator) catch {
        return stdlib_error("serde_to_yaml() failed", .{});
    };

    const str_obj = object_h.copyString(result.ptr, result.len);
    allocator.free(result);
    return Value.init_obj(@ptrCast(str_obj));
}

fn serde_from_yaml_impl(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("serde_from_yaml() expects 1 argument, got {d}", .{argc});
    }

    const data_value = args[0];
    if (!data_value.is_string()) {
        return stdlib_error("serde_from_yaml() data must be a string", .{});
    }

    const data_str = data_value.as_string().chars;
    const options = serde.DeserializeOptions{};
    const allocator = mem_utils.getAllocator();

    return serde_yaml.deserializeYaml(data_str, options, allocator) catch {
        return stdlib_error("serde_from_yaml() failed", .{});
    };
}

fn serde_detect_format_impl(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("serde_detect_format() expects 1 argument, got {d}", .{argc});
    }

    const data_value = args[0];
    if (!data_value.is_string()) {
        return stdlib_error("serde_detect_format() data must be a string", .{});
    }

    const data_str = data_value.as_string().chars;
    const allocator = mem_utils.getAllocator();
    const registry = serde.getGlobalRegistry(allocator);

    if (registry.detectFormat(data_str)) |format_entry| {
        const str_obj = object_h.copyString(format_entry.name.ptr, format_entry.name.len);
        return Value.init_obj(@ptrCast(str_obj));
    } else {
        const unknown_literal = "unknown";
        const unknown_str = object_h.copyString(unknown_literal.ptr, unknown_literal.len);
        return Value.init_obj(@ptrCast(unknown_str));
    }
}

fn serde_validate_impl(argc: i32, args: [*]Value) Value {
    if (argc != 2) {
        return stdlib_error("serde_validate() expects 2 arguments, got {d}", .{argc});
    }

    const data_value = args[0];
    const format_value = args[1];

    if (!data_value.is_string()) {
        return stdlib_error("serde_validate() data must be a string", .{});
    }

    const format_str = getFormatString(format_value) orelse {
        return stdlib_error("serde_validate() format must be a string", .{});
    };

    const data_str = data_value.as_string().chars;
    const options = serde.DeserializeOptions{};
    const allocator = mem_utils.getAllocator();

    // Try to deserialize - if it succeeds, the format is valid
    const result = serde.deserialize(data_str, format_str, options, allocator);
    if (result) |_| {
        return Value.init_bool(true);
    } else |_| {
        return Value.init_bool(false);
    }
}

// Exported MufiZ stdlib functions

/// Generic serialization function
/// serde_serialize(value, format, options?) -> string
pub const serde_serialize = DefineFunction("serde_serialize", "serde", "Serialize a value to a string using the specified format", &[_]ParamSpec{
    .{ .name = "value", .type = .any },
    .{ .name = "format", .type = .string },
    .{ .name = "options", .type = .object, .optional = true },
}, .string, &[_][]const u8{ "serde_serialize({key: \"value\"}, \"json\") // -> \"{\"key\":\"value\"}\"", "serde_serialize(data, \"yaml\", {pretty: true}) // -> Pretty YAML output" }, serde_serialize_impl);

/// Generic deserialization function
/// serde_deserialize(data, format, options?) -> value
pub const serde_deserialize = DefineFunction("serde_deserialize", "serde", "Deserialize a string to a value using the specified format", &[_]ParamSpec{
    .{ .name = "data", .type = .string },
    .{ .name = "format", .type = .string },
    .{ .name = "options", .type = .object, .optional = true },
}, .any, &[_][]const u8{ "serde_deserialize(\"{\\\"key\\\":\\\"value\\\"}\", \"json\") // -> {key: \"value\"}", "serde_deserialize(yaml_data, \"yaml\", {strict_types: false})" }, serde_deserialize_impl);

/// JSON serialization function
/// serde_to_json(value, pretty?) -> string
pub const serde_to_json = DefineFunction("serde_to_json", "serde", "Serialize a value to JSON format", &[_]ParamSpec{
    .{ .name = "value", .type = .any },
    .{ .name = "pretty", .type = .bool, .optional = true },
}, .string, &[_][]const u8{ "serde_to_json({name: \"John\", age: 30}) // -> \"{\"name\":\"John\",\"age\":30}\"", "serde_to_json(data, true) // -> Pretty printed JSON" }, serde_to_json_impl);

/// JSON deserialization function
/// serde_from_json(json_string) -> value
pub const serde_from_json = DefineFunction("serde_from_json", "serde", "Deserialize a JSON string to a value", &[_]ParamSpec{
    .{ .name = "json_string", .type = .string },
}, .any, &[_][]const u8{ "serde_from_json(\"{\\\"name\\\":\\\"John\\\"}\") // -> {name: \"John\"}", "serde_from_json(\"[1,2,3]\") // -> [1, 2, 3]" }, serde_from_json_impl);

/// TOML serialization function
/// serde_to_toml(value) -> string
pub const serde_to_toml = DefineFunction("serde_to_toml", "serde", "Serialize a value to TOML format", &[_]ParamSpec{
    .{ .name = "value", .type = .object },
}, .string, &[_][]const u8{"serde_to_toml({database: {host: \"localhost\", port: 5432}}) // -> TOML config"}, serde_to_toml_impl);

/// TOML deserialization function
/// serde_from_toml(toml_string) -> value
pub const serde_from_toml = DefineFunction("serde_from_toml", "serde", "Deserialize a TOML string to a value", &[_]ParamSpec{
    .{ .name = "toml_string", .type = .string },
}, .object, &[_][]const u8{"serde_from_toml(\"name = \\\"value\\\"\") // -> {name: \"value\"}"}, serde_from_toml_impl);

/// YAML serialization function
/// serde_to_yaml(value, pretty?) -> string
pub const serde_to_yaml = DefineFunction("serde_to_yaml", "serde", "Serialize a value to YAML format", &[_]ParamSpec{
    .{ .name = "value", .type = .any },
    .{ .name = "pretty", .type = .bool, .optional = true },
}, .string, &[_][]const u8{ "serde_to_yaml({name: \"John\", hobbies: [\"reading\", \"coding\"]}) // -> YAML output", "serde_to_yaml(data, false) // -> Flow style YAML" }, serde_to_yaml_impl);

/// YAML deserialization function
/// serde_from_yaml(yaml_string) -> value
pub const serde_from_yaml = DefineFunction("serde_from_yaml", "serde", "Deserialize a YAML string to a value", &[_]ParamSpec{
    .{ .name = "yaml_string", .type = .string },
}, .any, &[_][]const u8{"serde_from_yaml(\"name: John\\nage: 30\") // -> {name: \"John\", age: 30}"}, serde_from_yaml_impl);

/// Format detection function
/// serde_detect_format(data) -> string
pub const serde_detect_format = DefineFunction("serde_detect_format", "serde", "Detect the format of serialized data", &[_]ParamSpec{
    .{ .name = "data", .type = .string },
}, .string, &[_][]const u8{ "serde_detect_format(\"{\\\"key\\\": \\\"value\\\"}\") // -> \"json\"", "serde_detect_format(\"name: John\") // -> \"yaml\"" }, serde_detect_format_impl);

/// Format validation function
/// serde_validate(data, format) -> boolean
pub const serde_validate = DefineFunction("serde_validate", "serde", "Validate if data conforms to the specified format", &[_]ParamSpec{
    .{ .name = "data", .type = .string },
    .{ .name = "format", .type = .string },
}, .bool, &[_][]const u8{ "serde_validate(\"{\\\"valid\\\": true}\", \"json\") // -> true", "serde_validate(\"invalid json{\", \"json\") // -> false" }, serde_validate_impl);
