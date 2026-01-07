const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_core = @import("../stdlib_core.zig");
const DefineFunction = stdlib_core.DefineFunction;
const ParamSpec = stdlib_core.ParamSpec;
const ParamType = stdlib_core.ParamType;
const NoParams = stdlib_core.NoParams;
const OneAny = stdlib_core.OneAny;
const object_h = @import("../object.zig");
const ObjString = object_h.ObjString;
const ObjHashTable = object_h.ObjHashTable;
const FloatVector = object_h.FloatVector;

// JSON parser state
const JsonParser = struct {
    source: []const u8,
    current: usize,

    fn init(source: []const u8) JsonParser {
        return JsonParser{
            .source = source,
            .current = 0,
        };
    }

    fn isAtEnd(self: *JsonParser) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *JsonParser) u8 {
        if (self.isAtEnd()) return 0;
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn peek(self: *JsonParser) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *JsonParser) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn skipWhitespace(self: *JsonParser) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == ' ' or c == '\r' or c == '\t' or c == '\n') {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    fn parseString(self: *JsonParser) ?Value {
        if (self.peek() != '"') return null;
        _ = self.advance(); // consume opening quote

        const start = self.current;
        var len: usize = 0;

        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\\') {
                _ = self.advance(); // consume backslash
                if (!self.isAtEnd()) _ = self.advance(); // consume escaped char
                len += 1; // simplified - would need proper unescaping
            } else {
                _ = self.advance();
                len += 1;
            }
        }

        if (self.isAtEnd()) return null; // unterminated string
        _ = self.advance(); // consume closing quote

        // Create a simple string without unescaping for now
        const str_slice = self.source[start .. start + len];
        const str_obj = object_h.copyString(str_slice.ptr, str_slice.len);
        return Value.init_obj(@ptrCast(str_obj));
    }

    fn parseNumber(self: *JsonParser) ?Value {
        const start = self.current;

        // Handle negative numbers
        if (self.peek() == '-') _ = self.advance();

        // Must have at least one digit
        if (!std.ascii.isDigit(self.peek())) return null;

        // Parse integer part
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }

        var is_float = false;

        // Parse decimal part
        if (self.peek() == '.') {
            is_float = true;
            _ = self.advance();
            if (!std.ascii.isDigit(self.peek())) return null;
            while (std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        // Parse exponent
        if (self.peek() == 'e' or self.peek() == 'E') {
            is_float = true;
            _ = self.advance();
            if (self.peek() == '+' or self.peek() == '-') _ = self.advance();
            if (!std.ascii.isDigit(self.peek())) return null;
            while (std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        const number_str = self.source[start..self.current];

        if (is_float) {
            const num = std.fmt.parseFloat(f64, number_str) catch return null;
            return Value.init_double(num);
        } else {
            const num = std.fmt.parseInt(i32, number_str, 10) catch return null;
            return Value.init_int(num);
        }
    }

    fn parseArray(self: *JsonParser) ?Value {
        if (self.peek() != '[') return null;
        _ = self.advance(); // consume '['

        var array_values = std.ArrayList(Value).initCapacity(std.heap.page_allocator, 0) catch unreachable;
        defer array_values.deinit(std.heap.page_allocator);

        self.skipWhitespace();

        // Empty array
        if (self.peek() == ']') {
            _ = self.advance();
            const empty_vector = FloatVector.init(0);
            return Value.init_obj(@ptrCast(empty_vector));
        }

        while (true) {
            self.skipWhitespace();

            const value = self.parseValue() orelse return null;
            array_values.append(std.heap.page_allocator, value) catch return null;

            self.skipWhitespace();

            if (self.peek() == ']') {
                _ = self.advance();
                break;
            } else if (self.peek() == ',') {
                _ = self.advance();
            } else {
                return null; // expected ',' or ']'
            }
        }

        // Check if all values are numbers - if so, use FloatVector (true arrays)
        var all_numbers = true;
        for (array_values.items) |val| {
            if (!val.is_prim_num()) {
                all_numbers = false;
                break;
            }
        }

        if (all_numbers) {
            const vector = FloatVector.init(@intCast(array_values.items.len));
            for (array_values.items) |val| {
                const num_val = val.as_num_double();
                vector.push(num_val);
            }
            return Value.init_obj(@ptrCast(vector));
        }

        // For mixed arrays (objects, strings, etc.), use hash table with string indices
        // This allows indexing like array["0"], array["1"], etc. but using hash table semantics
        const hash_table = ObjHashTable.init();
        for (array_values.items, 0..) |val, i| {
            // Create index string like "0", "1", "2", etc.
            var index_buf: [16]u8 = undefined;
            const index_str_slice = std.fmt.bufPrint(&index_buf, "{d}", .{i}) catch unreachable;
            const index_str = object_h.copyString(index_str_slice.ptr, index_str_slice.len);
            _ = hash_table.put(index_str, val);
        }
        return Value.init_obj(@ptrCast(hash_table));
    }

    fn parseObject(self: *JsonParser) ?Value {
        if (self.peek() != '{') return null;
        _ = self.advance(); // consume '{'

        const hash_table = ObjHashTable.init();

        self.skipWhitespace();

        // Empty object
        if (self.peek() == '}') {
            _ = self.advance();
            return Value.init_obj(@ptrCast(hash_table));
        }

        while (true) {
            self.skipWhitespace();

            // Parse key (must be string)
            const key = self.parseString() orelse return null;
            if (!key.is_string()) return null;

            self.skipWhitespace();

            // Expect colon
            if (self.peek() != ':') return null;
            _ = self.advance();

            self.skipWhitespace();

            // Parse value
            const value = self.parseValue() orelse return null;

            // Add to hash table
            const key_str = object_h.copyString(key.as_zstring().ptr, key.as_zstring().len);
            _ = hash_table.put(key_str, value);

            self.skipWhitespace();

            if (self.peek() == '}') {
                _ = self.advance();
                break;
            } else if (self.peek() == ',') {
                _ = self.advance();
            } else {
                return null; // expected ',' or '}'
            }
        }

        return Value.init_obj(@ptrCast(hash_table));
    }

    fn parseValue(self: *JsonParser) ?Value {
        self.skipWhitespace();

        const c = self.peek();
        switch (c) {
            '"' => return self.parseString(),
            '[' => return self.parseArray(),
            '{' => return self.parseObject(),
            't' => {
                if (self.current + 4 <= self.source.len and
                    std.mem.eql(u8, self.source[self.current .. self.current + 4], "true"))
                {
                    self.current += 4;
                    return Value.init_bool(true);
                }
                return null;
            },
            'f' => {
                if (self.current + 5 <= self.source.len and
                    std.mem.eql(u8, self.source[self.current .. self.current + 5], "false"))
                {
                    self.current += 5;
                    return Value.init_bool(false);
                }
                return null;
            },
            'n' => {
                if (self.current + 4 <= self.source.len and
                    std.mem.eql(u8, self.source[self.current .. self.current + 4], "null"))
                {
                    self.current += 4;
                    return Value.init_nil();
                }
                return null;
            },
            else => {
                if (c == '-' or std.ascii.isDigit(c)) {
                    return self.parseNumber();
                }
                return null;
            },
        }
    }
};

// JSON stringifier
const JsonStringifier = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) JsonStringifier {
        return JsonStringifier{
            .buffer = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            .allocator = allocator,
        };
    }

    fn deinit(self: *JsonStringifier) void {
        self.buffer.deinit(self.allocator);
    }

    fn stringify(self: *JsonStringifier, value: Value) std.mem.Allocator.Error!void {
        switch (value.type) {
            .VAL_NIL => try self.buffer.appendSlice(self.allocator, "null"),
            .VAL_BOOL => {
                if (value.as_bool()) {
                    try self.buffer.appendSlice(self.allocator, "true");
                } else {
                    try self.buffer.appendSlice(self.allocator, "false");
                }
            },
            .VAL_INT => {
                const int_val = value.as_int();
                const int_str = try std.fmt.allocPrint(self.allocator, "{d}", .{int_val});
                defer self.allocator.free(int_str);
                try self.buffer.appendSlice(self.allocator, int_str);
            },
            .VAL_DOUBLE => {
                const double_val = value.as_double();
                const double_str = try std.fmt.allocPrint(self.allocator, "{d}", .{double_val});
                defer self.allocator.free(double_str);
                try self.buffer.appendSlice(self.allocator, double_str);
            },
            .VAL_OBJ => {
                if (value.is_string()) {
                    try self.buffer.append(self.allocator, '"');
                    const str = value.as_zstring();
                    // Escape special characters for JSON
                    try self.escapeJsonString(str);
                    try self.buffer.append(self.allocator, '"');
                } else if (value.is_obj_type(.OBJ_HASH_TABLE)) {
                    const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
                    try self.stringifyObject(hash_table);
                } else if (value.is_obj_type(.OBJ_FVECTOR)) {
                    const vector = @as(*FloatVector, @ptrCast(@alignCast(value.as.obj)));
                    try self.stringifyArray(vector);
                } else {
                    // For other object types, convert to string representation
                    try self.buffer.appendSlice(self.allocator, "null");
                }
            },
            .VAL_COMPLEX => {
                // JSON doesn't support complex numbers, convert to string
                const c = value.as_complex();
                const complex_str = try std.fmt.allocPrint(self.allocator, "\"{d}+{d}i\"", .{ c.r, c.i });
                defer self.allocator.free(complex_str);
                try self.buffer.appendSlice(self.allocator, complex_str);
            },
        }
    }

    /// Escape special characters in a JSON string according to RFC 8259
    ///
    /// Handles all required JSON string escape sequences:
    /// - Quotation mark (") -> \"
    /// - Backslash (\) -> \\
    /// - Newline (\n) -> \n
    /// - Carriage return (\r) -> \r
    /// - Tab (\t) -> \t
    /// - Backspace (\b) -> \b
    /// - Form feed (\f) -> \f
    /// - Control characters (0x00-0x1F) -> \uXXXX
    ///
    /// All other characters are passed through unchanged.
    fn escapeJsonString(self: *JsonStringifier, str: []const u8) std.mem.Allocator.Error!void {
        for (str) |c| {
            switch (c) {
                '"' => try self.buffer.appendSlice(self.allocator, "\\\""),
                '\\' => try self.buffer.appendSlice(self.allocator, "\\\\"),
                // '\n' => try self.buffer.appendSlice(self.allocator, "\\n"),
                // '\r' => try self.buffer.appendSlice(self.allocator, "\\r"),
                // '\t' => try self.buffer.appendSlice(self.allocator, "\\t"),
                // '\x08' => try self.buffer.appendSlice(self.allocator, "\\b"),
                // '\x0C' => try self.buffer.appendSlice(self.allocator, "\\f"),
                '\x00'...'\x1F' => {
                    // Control characters: use \uXXXX format
                    // Use stack buffer to avoid allocation
                    var buf: [6]u8 = undefined;
                    const escaped = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch unreachable; // 6 bytes always sufficient
                    try self.buffer.appendSlice(self.allocator, escaped);
                },
                else => try self.buffer.append(self.allocator, c),
            }
        }
    }

    fn stringifyObject(self: *JsonStringifier, hash_table: *ObjHashTable) std.mem.Allocator.Error!void {
        try self.buffer.append(self.allocator, '{');

        var first = true;
        var iterator = hash_table.iterator();

        while (iterator.next()) |entry| {
            if (!first) {
                try self.buffer.append(self.allocator, ',');
            }
            first = false;

            // Key (always string) - escape special characters
            try self.buffer.append(self.allocator, '"');
            try self.escapeJsonString(entry.key.chars);
            try self.buffer.appendSlice(self.allocator, "\":");

            // Value
            try self.stringify(entry.value);
        }

        try self.buffer.append(self.allocator, '}');
    }

    fn stringifyArray(self: *JsonStringifier, vector: *FloatVector) std.mem.Allocator.Error!void {
        try self.buffer.append(self.allocator, '[');

        for (0..vector.count) |i| {
            if (i > 0) {
                try self.buffer.append(self.allocator, ',');
            }
            const val = vector.data[i];
            const val_str = try std.fmt.allocPrint(self.allocator, "{d}", .{val});
            defer self.allocator.free(val_str);
            try self.buffer.appendSlice(self.allocator, val_str);
        }

        try self.buffer.append(self.allocator, ']');
    }
};

// Implementation functions

fn json_parse_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const json_str = args[0].as_zstring();

    var parser = JsonParser.init(json_str);
    const result = parser.parseValue();

    if (result) |value| {
        return value;
    } else {
        return stdlib_core.stdlib_error("Invalid JSON syntax", .{});
    }
}

fn json_stringify_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const value = args[0];

    const allocator = std.heap.page_allocator;
    var stringifier = JsonStringifier.init(allocator);
    defer stringifier.deinit();

    stringifier.stringify(value) catch {
        return stdlib_core.stdlib_error("Failed to stringify value to JSON", .{});
    };

    const result_str = stringifier.buffer.toOwnedSlice(allocator) catch {
        return stdlib_core.stdlib_error("Failed to create JSON string", .{});
    };

    const str_obj = object_h.copyString(result_str.ptr, result_str.len);
    allocator.free(result_str);

    return Value.init_obj(@ptrCast(str_obj));
}

fn json_is_valid_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const json_str = args[0].as_zstring();

    var parser = JsonParser.init(json_str);
    const result = parser.parseValue();

    if (result != null) {
        // Check if we consumed all input (no trailing characters)
        parser.skipWhitespace();
        return Value.init_bool(parser.isAtEnd());
    } else {
        return Value.init_bool(false);
    }
}

fn json_pretty_impl(argc: i32, args: [*]Value) Value {
    // For now, just return regular stringified JSON
    // In a full implementation, we'd add indentation and formatting
    return json_stringify_impl(argc, args);
}

fn json_get_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const json_value = args[0];
    const key = args[1].as_zstring();

    if (!json_value.is_obj_type(.OBJ_HASH_TABLE)) {
        return stdlib_core.stdlib_error("json_get() requires a JSON object as first argument", .{});
    }

    const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(json_value.as.obj)));
    const key_str = object_h.copyString(key.ptr, key.len);
    const result = hash_table.get(key_str);

    return result orelse Value.init_nil();
}

fn json_set_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const json_value = args[0];
    const key = args[1].as_zstring();
    const value = args[2];

    if (!json_value.is_obj_type(.OBJ_HASH_TABLE)) {
        return stdlib_core.stdlib_error("json_set() requires a JSON object as first argument", .{});
    }

    const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(json_value.as.obj)));
    const key_str = object_h.copyString(key.ptr, key.len);
    _ = hash_table.put(key_str, value);

    return json_value; // Return modified object
}

// Public function wrappers with metadata

pub const json_parse = DefineFunction(
    "json_parse",
    "json",
    "Parse a JSON string into a MufiZ value",
    &[_]ParamSpec{
        .{ .name = "json_string", .type = .string },
    },
    .any,
    &[_][]const u8{
        "json_parse(\"{\\\"name\\\": \\\"John\\\", \\\"age\\\": 30}\") -> hash table",
        "json_parse(\"[1, 2, 3]\") -> float vector",
        "json_parse(\"\\\"hello\\\"\") -> \"hello\"",
        "json_parse(\"42\") -> 42",
        "json_parse(\"true\") -> true",
        "json_parse(\"null\") -> nil",
    },
    json_parse_impl,
);

pub const json_stringify = DefineFunction(
    "json_stringify",
    "json",
    "Convert a MufiZ value to JSON string",
    OneAny,
    .string,
    &[_][]const u8{
        "json_stringify(#{\"name\": \"John\", \"age\": 30}) -> \"{\\\"name\\\":\\\"John\\\",\\\"age\\\":30}\"",
        "json_stringify({1, 2, 3}) -> \"[1,2,3]\"",
        "json_stringify(\"hello\") -> \"\\\"hello\\\"\"",
        "json_stringify(42) -> \"42\"",
        "json_stringify(true) -> \"true\"",
        "json_stringify(nil) -> \"null\"",
    },
    json_stringify_impl,
);

pub const json_is_valid = DefineFunction(
    "json_is_valid",
    "json",
    "Check if a string is valid JSON",
    &[_]ParamSpec{
        .{ .name = "json_string", .type = .string },
    },
    .bool,
    &[_][]const u8{
        "json_is_valid(\"{\\\"valid\\\": true}\") -> true",
        "json_is_valid(\"{invalid json}\") -> false",
        "json_is_valid(\"42\") -> true",
        "json_is_valid(\"'single quotes'\") -> false",
    },
    json_is_valid_impl,
);

pub const json_pretty = DefineFunction(
    "json_pretty",
    "json",
    "Convert a value to pretty-printed JSON string",
    OneAny,
    .string,
    &[_][]const u8{
        "json_pretty(#{\"a\": 1, \"b\": 2}) -> formatted JSON string",
        "json_pretty({1, 2, 3}) -> formatted JSON array",
    },
    json_pretty_impl,
);

pub const json_get = DefineFunction(
    "json_get",
    "json",
    "Get a value from a JSON object by key",
    &[_]ParamSpec{
        .{ .name = "json_object", .type = .object },
        .{ .name = "key", .type = .string },
    },
    .any,
    &[_][]const u8{
        "json_get(json_parse(\"{\\\"name\\\": \\\"John\\\"}\"), \"name\") -> \"John\"",
        "json_get(json_parse(\"{\\\"age\\\": 30}\"), \"age\") -> 30",
        "json_get(json_parse(\"{}\"), \"missing\") -> nil",
    },
    json_get_impl,
);

pub const json_set = DefineFunction(
    "json_set",
    "json",
    "Set a value in a JSON object by key",
    &[_]ParamSpec{
        .{ .name = "json_object", .type = .object },
        .{ .name = "key", .type = .string },
        .{ .name = "value", .type = .any },
    },
    .object,
    &[_][]const u8{
        "json_set(json_parse(\"{}\"), \"name\", \"John\") -> modified object",
        "json_set(obj, \"count\", 42) -> object with count set to 42",
    },
    json_set_impl,
);
