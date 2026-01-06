/// JSON Serializer/Deserializer Implementation using MufiZ Serde Interface
///
/// This module implements JSON serialization and deserialization for MufiZ values
/// using the common Serde interface defined in ../serde.zig.
///
/// Features:
/// - Full MufiZ value type support
/// - Pretty printing with configurable indentation
/// - Error handling with context information
/// - Efficient string building
/// - Support for nested structures
/// - Complex number serialization as objects
/// - FloatVector and Matrix serialization as arrays
///
/// JSON Type Mapping:
/// - VAL_NIL -> null
/// - VAL_BOOL -> true/false
/// - VAL_INT -> number
/// - VAL_DOUBLE -> number
/// - VAL_COMPLEX -> {"r": real, "i": imag}
/// - OBJ_STRING -> "string"
/// - OBJ_HASH_TABLE -> object
/// - OBJ_LINKED_LIST -> array
/// - OBJ_FVECTOR -> array of numbers
/// - OBJ_MATRIX -> array of arrays
/// - OBJ_RANGE -> {"start": n, "end": n, "inclusive": bool}
/// - OBJ_PAIR -> {"key": key, "value": value}
const std = @import("std");
const serde = @import("../serde.zig");
const Value = @import("../value.zig").Value;
const ValueType = @import("../value.zig").ValueType;
const Complex = @import("../value.zig").Complex;
const object_h = @import("../object.zig");
const Obj = object_h.Obj;
const ObjType = object_h.ObjType;
const ObjString = object_h.ObjString;
const ObjHashTable = object_h.ObjHashTable;
const LinkedList = object_h.LinkedList;
const Node = object_h.Node;
const FloatVector = object_h.FloatVector;
const Matrix = object_h.Matrix;
const ObjRange = object_h.ObjRange;
const ObjPair = object_h.ObjPair;
const mem_utils = @import("../mem_utils.zig");

const SerdeError = serde.SerdeError;
const SerdeContext = serde.SerdeContext;
const SerializeOptions = serde.SerializeOptions;
const DeserializeOptions = serde.DeserializeOptions;

/// JSON Serializer implementation
pub const JsonSerializer = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    depth: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .output = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            .depth = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit(self.allocator);
    }

    pub fn serialize(
        self: *Self,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError![]const u8 {
        self.output.clearRetainingCapacity();
        self.depth = 0;

        try self.serializeValue(value, options, context);

        // Return owned copy of the serialized data
        return self.allocator.dupe(u8, self.output.items);
    }

    fn serializeValue(
        self: *Self,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        if (self.depth >= options.max_depth) {
            return SerdeError.TooDeep;
        }

        switch (value.type) {
            .VAL_NIL => try self.output.appendSlice(self.allocator, "null"),
            .VAL_BOOL => {
                const bool_str = if (value.as.boolean) "true" else "false";
                try self.output.appendSlice(self.allocator, bool_str);
            },
            .VAL_INT => {
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_int});
            },
            .VAL_DOUBLE => {
                // Handle special float values
                if (std.math.isNan(value.as.num_double)) {
                    try self.output.appendSlice(self.allocator, "null");
                } else if (std.math.isInf(value.as.num_double)) {
                    try self.output.appendSlice(self.allocator, "null");
                } else {
                    try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_double});
                }
            },
            .VAL_COMPLEX => {
                try self.output.append(self.allocator, '{');
                if (options.pretty) try self.appendNewlineAndIndent(options);

                try self.output.appendSlice(self.allocator, "\"r\":");
                if (options.pretty) try self.output.append(self.allocator, ' ');
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.complex.r});
                try self.output.append(self.allocator, ',');

                if (options.pretty) try self.appendNewlineAndIndent(options);
                try self.output.appendSlice(self.allocator, "\"i\":");
                if (options.pretty) try self.output.append(self.allocator, ' ');
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.complex.i});

                if (options.pretty) {
                    self.depth -= 1;
                    try self.appendNewlineAndIndent(options);
                }
                try self.output.append(self.allocator, '}');
            },
            .VAL_OBJ => {
                if (value.as.obj) |obj| {
                    try self.serializeObject(obj, options, context);
                } else {
                    try self.output.appendSlice(self.allocator, "null");
                }
            },
        }
    }

    fn serializeObject(
        self: *Self,
        obj: *Obj,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        switch (obj.type) {
            .OBJ_STRING => {
                const str_obj = @as(*ObjString, @ptrCast(@alignCast(obj)));
                try self.serializeString(str_obj.chars);
            },
            .OBJ_HASH_TABLE => {
                const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(obj)));
                try self.serializeHashTable(hash_table, options, context);
            },
            .OBJ_LINKED_LIST => {
                const list = @as(*LinkedList, @ptrCast(@alignCast(obj)));
                try self.serializeLinkedList(list, options, context);
            },
            .OBJ_FVECTOR => {
                const fvec = @as(*FloatVector, @ptrCast(@alignCast(obj)));
                try self.serializeFloatVector(fvec, options);
            },
            .OBJ_MATRIX => {
                const matrix = @as(*Matrix, @ptrCast(@alignCast(obj)));
                try self.serializeMatrix(matrix, options, context);
            },
            .OBJ_RANGE => {
                const range = @as(*ObjRange, @ptrCast(@alignCast(obj)));
                try self.serializeRange(range, options);
            },
            .OBJ_PAIR => {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(obj)));
                try self.serializePair(pair, options, context);
            },
            else => {
                // Unsupported object types
                return SerdeError.UnsupportedType;
            },
        }
    }

    fn serializeString(self: *Self, str: []const u8) SerdeError!void {
        try self.output.append(self.allocator, '"');

        for (str) |char| {
            switch (char) {
                '"' => try self.output.appendSlice(self.allocator, "\\\""),
                '\\' => try self.output.appendSlice(self.allocator, "\\\\"),
                '\n' => try self.output.appendSlice(self.allocator, "\\n"),
                '\r' => try self.output.appendSlice(self.allocator, "\\r"),
                '\t' => try self.output.appendSlice(self.allocator, "\\t"),
                '\u{08}' => try self.output.appendSlice(self.allocator, "\\b"),
                '\u{0C}' => try self.output.appendSlice(self.allocator, "\\f"),
                0x00...0x07, 0x0B, 0x0E...0x1F, 0x7F => {
                    try std.fmt.format(self.output.writer(self.allocator), "\\u{:04}", .{char});
                },
                else => try self.output.append(self.allocator, char),
            }
        }

        try self.output.append(self.allocator, '"');
    }

    fn serializeHashTable(
        self: *Self,
        hash_table: *ObjHashTable,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        try self.output.append(self.allocator, '{');
        self.depth += 1;

        const pairs = hash_table.toPairs();
        defer {
            // Clean up pairs list if needed
            // pairs.deinit(); // This would depend on the LinkedList implementation
        }

        var current = pairs.head;
        var first = true;

        while (current) |node| {
            const pair_value = node.data;
            if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                // Only string keys are supported in JSON
                if (!pair.key.is_string()) {
                    return SerdeError.InvalidKey;
                }

                if (!first) {
                    try self.output.append(self.allocator, ',');
                }
                first = false;

                if (options.pretty) try self.appendNewlineAndIndent(options);

                // Serialize key
                const key_str = pair.key.as_string();
                try self.serializeString(key_str.chars);
                try self.output.append(self.allocator, ':');
                if (options.pretty) try self.output.append(self.allocator, ' ');

                // Serialize value
                try self.serializeValue(pair.value, options, context);
            }

            current = node.next;
        }

        if (options.pretty and !first) {
            self.depth -= 1;
            try self.appendNewlineAndIndent(options);
        } else {
            self.depth -= 1;
        }

        try self.output.append(self.allocator, '}');
    }

    fn serializeLinkedList(
        self: *Self,
        list: *LinkedList,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        try self.output.append(self.allocator, '[');
        self.depth += 1;

        var current = list.head;
        var first = true;

        while (current) |node| {
            if (!first) {
                try self.output.append(self.allocator, ',');
            }
            first = false;

            if (options.pretty) try self.appendNewlineAndIndent(options);

            try self.serializeValue(node.data, options, context);
            current = node.next;
        }

        if (options.pretty and !first) {
            self.depth -= 1;
            try self.appendNewlineAndIndent(options);
        } else {
            self.depth -= 1;
        }

        try self.output.append(self.allocator, ']');
    }

    fn serializeFloatVector(
        self: *Self,
        fvec: *FloatVector,
        options: SerializeOptions,
    ) SerdeError!void {
        try self.output.append(self.allocator, '[');

        for (fvec.data[0..fvec.size], 0..) |value, i| {
            if (i > 0) try self.output.append(self.allocator, ',');
            if (options.pretty) try self.output.append(self.allocator, ' ');

            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value});
        }

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.append(self.allocator, ']');
    }

    fn serializeMatrix(
        self: *Self,
        matrix: *Matrix,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        _ = context;
        try self.output.append(self.allocator, '[');
        self.depth += 1;

        for (0..matrix.rows) |row| {
            if (row > 0) try self.output.append(self.allocator, ',');
            if (options.pretty) try self.appendNewlineAndIndent(options);

            try self.output.append(self.allocator, '[');
            for (0..matrix.cols) |col| {
                if (col > 0) try self.output.append(self.allocator, ',');
                if (options.pretty) try self.output.append(self.allocator, ' ');

                const value = matrix.get(@intCast(row), @intCast(col));
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value});
            }
            if (options.pretty) try self.output.append(self.allocator, ' ');
            try self.output.append(self.allocator, ']');
        }

        if (options.pretty) {
            self.depth -= 1;
            try self.appendNewlineAndIndent(options);
        } else {
            self.depth -= 1;
        }

        try self.output.append(self.allocator, ']');
    }

    fn serializeRange(self: *Self, range: *ObjRange, options: SerializeOptions) SerdeError!void {
        try self.output.append(self.allocator, '{');
        if (options.pretty) try self.output.append(self.allocator, ' ');

        try self.output.appendSlice(self.allocator, "\"start\":");
        if (options.pretty) try self.output.append(self.allocator, ' ');
        try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.start});
        try self.output.append(self.allocator, ',');

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.appendSlice(self.allocator, "\"end\":");
        if (options.pretty) try self.output.append(self.allocator, ' ');
        try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.end});
        try self.output.append(self.allocator, ',');

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.appendSlice(self.allocator, "\"inclusive\":");
        if (options.pretty) try self.output.append(self.allocator, ' ');
        const inclusive_str = if (range.inclusive) "true" else "false";
        try self.output.appendSlice(self.allocator, inclusive_str);

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.append(self.allocator, '}');
    }

    fn serializePair(
        self: *Self,
        pair: *ObjPair,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        try self.output.append(self.allocator, '{');
        if (options.pretty) try self.output.append(self.allocator, ' ');

        try self.output.appendSlice(self.allocator, "\"key\":");
        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.serializeValue(pair.key, options, context);
        try self.output.append(self.allocator, ',');

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.appendSlice(self.allocator, "\"value\":");
        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.serializeValue(pair.value, options, context);

        if (options.pretty) try self.output.append(self.allocator, ' ');
        try self.output.append(self.allocator, '}');
    }

    fn appendNewlineAndIndent(self: *Self, options: SerializeOptions) !void {
        try self.output.append(self.allocator, '\n');
        for (0..self.depth) |_| {
            try self.output.appendSlice(self.allocator, options.indent);
        }
    }

    pub fn supportsType(self: *Self, value_type: ValueType) bool {
        _ = self;
        return serde.isSerializableType(value_type);
    }
};

/// JSON Deserializer implementation
pub const JsonDeserializer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    current: usize,
    line: u32,
    column: u32,
    depth: u32,

    const Self = @This();

    pub fn init(source: []const u8, allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .source = source,
            .current = 0,
            .line = 1,
            .column = 1,
            .depth = 0,
        };
    }

    pub fn deserialize(
        self: *Self,
        data: []const u8,
        options: DeserializeOptions,
        context: *SerdeContext,
    ) SerdeError!Value {
        self.source = data;
        self.current = 0;
        self.line = 1;
        self.column = 1;
        self.depth = 0;

        context.line = self.line;
        context.column = self.column;

        self.skipWhitespace();
        return self.parseValue(options, context);
    }

    pub fn canDeserialize(self: *Self, data: []const u8) bool {
        _ = self;

        // Basic JSON detection - look for common JSON starting characters
        for (data) |char| {
            switch (char) {
                ' ', '\t', '\r', '\n' => continue,
                '{', '[', '"', 't', 'f', 'n', '-', '0'...'9' => return true,
                else => return false,
            }
        }
        return false;
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        const char = self.source[self.current];
        self.current += 1;

        if (char == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }

        return char;
    }

    fn peek(self: *const Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.isAtEnd()) {
            const char = self.peek();
            if (char == ' ' or char == '\r' or char == '\t' or char == '\n') {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    fn parseValue(
        self: *Self,
        options: DeserializeOptions,
        context: *SerdeContext,
    ) SerdeError!Value {
        if (self.depth >= options.max_depth) {
            return SerdeError.TooDeep;
        }

        context.line = self.line;
        context.column = self.column;

        self.skipWhitespace();

        const char = self.peek();
        return switch (char) {
            '{' => self.parseObject(options, context),
            '[' => self.parseArray(options, context),
            '"' => self.parseString(),
            't', 'f' => self.parseBoolean(),
            'n' => self.parseNull(),
            '-', '0'...'9' => self.parseNumber(),
            else => SerdeError.InvalidFormat,
        };
    }

    fn parseObject(
        self: *Self,
        options: DeserializeOptions,
        context: *SerdeContext,
    ) SerdeError!Value {
        _ = self.advance(); // consume '{'
        self.depth += 1;
        defer self.depth -= 1;

        // Create a new hash table
        const hash_table = ObjHashTable.init();
        const table_value = Value.init_obj(@ptrCast(hash_table));

        self.skipWhitespace();

        // Handle empty object
        if (self.peek() == '}') {
            _ = self.advance();
            return table_value;
        }

        while (true) {
            self.skipWhitespace();

            // Parse key (must be string)
            if (self.peek() != '"') {
                return SerdeError.InvalidFormat;
            }

            const key_value = try self.parseString();
            const key_str = key_value.as_string();

            self.skipWhitespace();

            // Expect colon
            if (self.peek() != ':') {
                return SerdeError.InvalidFormat;
            }
            _ = self.advance();

            self.skipWhitespace();

            // Parse value
            const value = try self.parseValue(options, context);

            // Insert into hash table
            _ = hash_table.put(key_str, value);

            self.skipWhitespace();

            const next_char = self.peek();
            if (next_char == '}') {
                _ = self.advance();
                break;
            } else if (next_char == ',') {
                _ = self.advance();
                continue;
            } else {
                return SerdeError.InvalidFormat;
            }
        }

        return table_value;
    }

    fn parseArray(
        self: *Self,
        options: DeserializeOptions,
        context: *SerdeContext,
    ) SerdeError!Value {
        _ = self.advance(); // consume '['
        self.depth += 1;
        defer self.depth -= 1;

        // Create a new linked list
        const list = LinkedList.init();
        const list_value = Value.init_obj(@ptrCast(list));

        self.skipWhitespace();

        // Handle empty array
        if (self.peek() == ']') {
            _ = self.advance();
            return list_value;
        }

        while (true) {
            self.skipWhitespace();

            // Parse value
            const value = try self.parseValue(options, context);
            list.push(value);

            self.skipWhitespace();

            const next_char = self.peek();
            if (next_char == ']') {
                _ = self.advance();
                break;
            } else if (next_char == ',') {
                _ = self.advance();
                continue;
            } else {
                return SerdeError.InvalidFormat;
            }
        }

        return list_value;
    }

    fn parseString(self: *Self) SerdeError!Value {
        _ = self.advance(); // consume opening '"'

        var string_chars = std.ArrayList(u8).initCapacity(self.allocator, 0) catch unreachable;
        defer string_chars.deinit(self.allocator);

        while (!self.isAtEnd() and self.peek() != '"') {
            var char = self.advance();

            if (char == '\\') {
                if (self.isAtEnd()) return SerdeError.UnexpectedEnd;

                const escaped = self.advance();
                char = switch (escaped) {
                    '"' => '"',
                    '\\' => '\\',
                    '/' => '/',
                    'b' => '\u{08}',
                    'f' => '\u{0C}',
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    'u' => blk: {
                        // Unicode escape sequence \uXXXX
                        var code_point: u32 = 0;
                        for (0..4) |_| {
                            if (self.isAtEnd()) return SerdeError.UnexpectedEnd;
                            const hex_char = self.advance();
                            const digit = switch (hex_char) {
                                '0'...'9' => hex_char - '0',
                                'A'...'F' => hex_char - 'A' + 10,
                                'a'...'f' => hex_char - 'a' + 10,
                                else => return SerdeError.InvalidEscape,
                            };
                            code_point = (code_point << 4) | digit;
                        }

                        // For simplicity, only handle ASCII range for now
                        if (code_point > 127) return SerdeError.NotSupported;
                        break :blk @as(u8, @intCast(code_point));
                    },
                    else => return SerdeError.InvalidEscape,
                };
            }

            try string_chars.append(self.allocator, char);
        }

        if (self.isAtEnd()) return SerdeError.UnexpectedEnd;
        _ = self.advance(); // consume closing '"'

        // Create MufiZ string object
        const str_obj = object_h.copyString(string_chars.items.ptr, string_chars.items.len);
        return Value.init_obj(@ptrCast(str_obj));
    }

    fn parseBoolean(self: *Self) SerdeError!Value {
        const start_pos = self.current;

        if (self.source.len - start_pos >= 4 and
            std.mem.eql(u8, self.source[start_pos .. start_pos + 4], "true"))
        {
            self.current += 4;
            self.column += 4;
            return Value.init_bool(true);
        } else if (self.source.len - start_pos >= 5 and
            std.mem.eql(u8, self.source[start_pos .. start_pos + 5], "false"))
        {
            self.current += 5;
            self.column += 5;
            return Value.init_bool(false);
        }

        return SerdeError.InvalidFormat;
    }

    fn parseNull(self: *Self) SerdeError!Value {
        const start_pos = self.current;

        if (self.source.len - start_pos >= 4 and
            std.mem.eql(u8, self.source[start_pos .. start_pos + 4], "null"))
        {
            self.current += 4;
            self.column += 4;
            return Value.init_nil();
        }

        return SerdeError.InvalidFormat;
    }

    fn parseNumber(self: *Self) SerdeError!Value {
        const start_pos = self.current;
        var has_decimal = false;
        var has_exponent = false;

        // Handle negative sign
        if (self.peek() == '-') {
            _ = self.advance();
        }

        // Parse integer part
        if (self.peek() == '0') {
            _ = self.advance();
        } else if (self.peek() >= '1' and self.peek() <= '9') {
            while (self.peek() >= '0' and self.peek() <= '9') {
                _ = self.advance();
            }
        } else {
            return SerdeError.InvalidNumber;
        }

        // Parse decimal part
        if (self.peek() == '.') {
            has_decimal = true;
            _ = self.advance();

            if (!(self.peek() >= '0' and self.peek() <= '9')) {
                return SerdeError.InvalidNumber;
            }

            while (self.peek() >= '0' and self.peek() <= '9') {
                _ = self.advance();
            }
        }

        // Parse exponent part
        if (self.peek() == 'e' or self.peek() == 'E') {
            has_exponent = true;
            _ = self.advance();

            if (self.peek() == '+' or self.peek() == '-') {
                _ = self.advance();
            }

            if (!(self.peek() >= '0' and self.peek() <= '9')) {
                return SerdeError.InvalidNumber;
            }

            while (self.peek() >= '0' and self.peek() <= '9') {
                _ = self.advance();
            }
        }

        const number_str = self.source[start_pos..self.current];

        if (has_decimal or has_exponent) {
            const double_value = std.fmt.parseFloat(f64, number_str) catch {
                return SerdeError.InvalidNumber;
            };
            return Value.init_double(double_value);
        } else {
            const int_value = std.fmt.parseInt(i32, number_str, 10) catch {
                return SerdeError.InvalidNumber;
            };
            return Value.init_int(int_value);
        }
    }
};

// Format detection function
fn detectJsonFormat(data: []const u8) bool {
    var deserializer = JsonDeserializer.init(data, std.heap.page_allocator);
    return deserializer.canDeserialize(data);
}

// High-level functions that integrate with the Serde registry
pub fn serializeJson(
    value: Value,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) SerdeError![]const u8 {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var serializer = JsonSerializer.init(allocator);
    defer serializer.deinit();

    return serializer.serialize(value, options, &context);
}

pub fn deserializeJson(
    data: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var deserializer = JsonDeserializer.init(data, allocator);
    return deserializer.deserialize(data, options, &context);
}

// Register JSON format with the global registry
pub fn registerJsonFormat(allocator: std.mem.Allocator) !void {
    const registry = serde.getGlobalRegistry(allocator);
    const extensions = [_][]const u8{".json"};

    try registry.registerFormat(
        "json",
        &extensions,
        serializeJson,
        deserializeJson,
        detectJsonFormat,
    );
}
