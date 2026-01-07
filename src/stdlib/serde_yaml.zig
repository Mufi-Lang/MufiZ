/// YAML Serializer/Deserializer Implementation using MufiZ Serde Interface
///
/// This module implements YAML serialization and deserialization for MufiZ values
/// using the common Serde interface defined in ../serde.zig.
///
/// YAML Features:
/// - Human-readable data serialization format
/// - Hierarchical structure with indentation
/// - Support for complex data types
/// - Multi-document streams
/// - Comments and anchors/references
/// - Flow and block styles
///
/// YAML Type Mapping:
/// - VAL_NIL -> null
/// - VAL_BOOL -> true/false
/// - VAL_INT -> integer
/// - VAL_DOUBLE -> float
/// - VAL_COMPLEX -> object with 'real' and 'imag' keys
/// - OBJ_STRING -> string (quoted if necessary)
/// - OBJ_HASH_TABLE -> mapping
/// - OBJ_LINKED_LIST -> sequence
/// - OBJ_FVECTOR -> sequence of floats
/// - OBJ_MATRIX -> sequence of sequences
/// - OBJ_RANGE -> mapping with 'start', 'end', 'inclusive' keys
/// - OBJ_PAIR -> mapping with 'key' and 'value'
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
const FloatVector = object_h.FloatVector;
const Matrix = object_h.Matrix;
const ObjRange = object_h.ObjRange;
const ObjPair = object_h.ObjPair;

const SerdeError = serde.SerdeError;
const SerdeContext = serde.SerdeContext;
const SerializeOptions = serde.SerializeOptions;
const DeserializeOptions = serde.DeserializeOptions;

/// YAML Token Types
const YamlTokenType = enum {
    EOF,
    Error,

    // Scalars
    String,
    Integer,
    Float,
    Boolean,
    Null,

    // Structure
    DocumentStart, // ---
    DocumentEnd, // ...
    MappingStart, // {
    MappingEnd, // }
    SequenceStart, // [
    SequenceEnd, // ]

    // Block structure
    BlockMappingKey, // key:
    BlockSequenceItem, // -

    // Flow structure
    FlowEntry, // ,

    // Whitespace/Formatting
    Newline,
    Indent,
    Dedent,

    // Special
    Comment,
    Anchor, // &anchor
    Reference, // *reference
    Tag, // !!type
};

const YamlToken = struct {
    type: YamlTokenType,
    value: []const u8,
    line: u32,
    column: u32,
    indent_level: u32,
};

/// YAML Lexer
const YamlLexer = struct {
    source: []const u8,
    current: usize,
    line: u32,
    column: u32,
    indent_stack: std.ArrayList(u32),
    current_indent: u32,
    at_line_start: bool,

    const Self = @This();

    fn init(source: []const u8, allocator: std.mem.Allocator) Self {
        return Self{
            .source = source,
            .current = 0,
            .line = 1,
            .column = 1,
            .indent_stack = std.ArrayList(u32).initCapacity(allocator, 0) catch unreachable,
            .current_indent = 0,
            .at_line_start = true,
        };
    }

    fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.indent_stack.deinit(allocator);
    }

    fn isAtEnd(self: *Self) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        const char = self.source[self.current];
        self.current += 1;
        if (char == '\n') {
            self.line += 1;
            self.column = 1;
            self.at_line_start = true;
        } else {
            self.column += 1;
            if (char != ' ' and char != '\t') {
                self.at_line_start = false;
            }
        }
        return char;
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Self) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn makeToken(self: *Self, token_type: YamlTokenType, start: usize) YamlToken {
        return YamlToken{
            .type = token_type,
            .value = self.source[start..self.current],
            .line = self.line,
            .column = self.column - @as(u32, @intCast(self.current - start)),
            .indent_level = self.current_indent,
        };
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.isAtEnd()) {
            switch (self.peek()) {
                ' ', '\t' => {
                    if (self.at_line_start) {
                        self.current_indent += 1;
                    }
                    _ = self.advance();
                },
                else => break,
            }
        }
    }

    fn scanString(self: *Self, quote_char: u8) !YamlToken {
        const start = self.current - 1;

        while (!self.isAtEnd() and self.peek() != quote_char) {
            if (self.peek() == '\\') {
                _ = self.advance(); // Skip escape character
                if (!self.isAtEnd()) {
                    _ = self.advance(); // Skip escaped character
                }
            } else {
                _ = self.advance();
            }
        }

        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }

        _ = self.advance(); // Closing quote
        return self.makeToken(.String, start);
    }

    fn scanNumber(self: *Self) YamlToken {
        const start = self.current - 1;
        var is_float = false;

        // Handle negative sign
        if (self.source[start] == '-') {
            // Already advanced past the minus sign
        }

        // Scan integer part
        while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for decimal point
        if (!self.isAtEnd() and self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
            is_float = true;
            _ = self.advance(); // Consume '.'

            while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        // Look for exponent
        if (!self.isAtEnd() and (self.peek() == 'e' or self.peek() == 'E')) {
            is_float = true;
            _ = self.advance(); // Consume 'e'/'E'

            if (!self.isAtEnd() and (self.peek() == '+' or self.peek() == '-')) {
                _ = self.advance(); // Consume sign
            }

            while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return self.makeToken(if (is_float) .Float else .Integer, start);
    }

    fn scanIdentifier(self: *Self) YamlToken {
        const start = self.current - 1;

        while (!self.isAtEnd()) {
            const char = self.peek();
            switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '-' => _ = self.advance(),
                else => break,
            }
        }

        const text = self.source[start..self.current];

        // Check for special literals
        if (std.mem.eql(u8, text, "true") or std.mem.eql(u8, text, "false")) {
            return self.makeToken(.Boolean, start);
        }
        if (std.mem.eql(u8, text, "null") or std.mem.eql(u8, text, "~")) {
            return self.makeToken(.Null, start);
        }

        return self.makeToken(.String, start);
    }

    fn scanPlainString(self: *Self) YamlToken {
        const start = self.current - 1;

        while (!self.isAtEnd()) {
            const char = self.peek();
            switch (char) {
                '\n', ':', '[', ']', '{', '}', ',' => break,
                '#' => {
                    // Comment starts - stop scanning plain string
                    break;
                },
                else => _ = self.advance(),
            }
        }

        // Trim trailing whitespace
        var end = self.current;
        while (end > start and (self.source[end - 1] == ' ' or self.source[end - 1] == '\t')) {
            end -= 1;
        }

        return YamlToken{
            .type = .String,
            .value = self.source[start..end],
            .line = self.line,
            .column = self.column - @as(u32, @intCast(self.current - start)),
            .indent_level = self.current_indent,
        };
    }

    fn nextToken(self: *Self) !YamlToken {
        // Handle indentation at line start
        if (self.at_line_start) {
            self.current_indent = 0;
            self.skipWhitespace();

            // Check for empty line or comment
            if (self.peek() == '\n' or self.peek() == '#') {
                // Don't process indentation for empty lines or comments
            } else {
                // Process indentation changes
                // Note: This is a simplified implementation
                // Real YAML needs more complex indentation tracking
            }
        } else {
            self.skipWhitespace();
        }

        if (self.isAtEnd()) {
            return self.makeToken(.EOF, self.current);
        }

        const start = self.current;
        const char = self.advance();

        switch (char) {
            '\n' => return self.makeToken(.Newline, start),
            '"' => return try self.scanString('"'),
            '\'' => return try self.scanString('\''),
            '[' => return self.makeToken(.SequenceStart, start),
            ']' => return self.makeToken(.SequenceEnd, start),
            '{' => return self.makeToken(.MappingStart, start),
            '}' => return self.makeToken(.MappingEnd, start),
            ',' => return self.makeToken(.FlowEntry, start),
            ':' => {
                // Check if it's followed by space (mapping key)
                if (!self.isAtEnd() and (self.peek() == ' ' or self.peek() == '\t' or self.peek() == '\n')) {
                    return self.makeToken(.BlockMappingKey, start);
                }
                // Part of plain string
                return self.scanPlainString();
            },
            '-' => {
                // Check for document separator ---
                if (self.peek() == '-' and self.peekNext() == '-') {
                    _ = self.advance();
                    _ = self.advance();
                    return self.makeToken(.DocumentStart, start);
                }
                // Check for sequence item
                if (!self.isAtEnd() and (self.peek() == ' ' or self.peek() == '\t')) {
                    return self.makeToken(.BlockSequenceItem, start);
                }
                // Check for number
                if (std.ascii.isDigit(self.peek())) {
                    return self.scanNumber();
                }
                // Part of plain string
                return self.scanPlainString();
            },
            '.' => {
                // Check for document end ...
                if (self.peek() == '.' and self.peekNext() == '.') {
                    _ = self.advance();
                    _ = self.advance();
                    return self.makeToken(.DocumentEnd, start);
                }
                // Part of number or plain string
                return self.scanPlainString();
            },
            '#' => {
                // Comment - scan to end of line
                while (!self.isAtEnd() and self.peek() != '\n') {
                    _ = self.advance();
                }
                return self.makeToken(.Comment, start);
            },
            '&' => {
                // Anchor
                while (!self.isAtEnd() and !std.ascii.isWhitespace(self.peek())) {
                    _ = self.advance();
                }
                return self.makeToken(.Anchor, start);
            },
            '*' => {
                // Reference
                while (!self.isAtEnd() and !std.ascii.isWhitespace(self.peek())) {
                    _ = self.advance();
                }
                return self.makeToken(.Reference, start);
            },
            '!' => {
                // Tag
                while (!self.isAtEnd() and !std.ascii.isWhitespace(self.peek())) {
                    _ = self.advance();
                }
                return self.makeToken(.Tag, start);
            },
            '0'...'9' => return self.scanNumber(),
            'a'...'z', 'A'...'Z', '_' => return self.scanIdentifier(),
            else => {
                // Try to parse as plain string
                return self.scanPlainString();
            },
        }
    }
};

/// YAML Parser
const YamlParser = struct {
    lexer: YamlLexer,
    current_token: YamlToken,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(source: []const u8, allocator: std.mem.Allocator) !Self {
        var lexer = YamlLexer.init(source, allocator);
        const current_token = try lexer.nextToken();

        return Self{
            .lexer = lexer,
            .current_token = current_token,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.lexer.deinit(self.allocator);
    }

    fn advance(self: *Self) !void {
        self.current_token = try self.lexer.nextToken();
    }

    fn skipCommentsAndNewlines(self: *Self) !void {
        while (self.current_token.type == .Comment or self.current_token.type == .Newline) {
            try self.advance();
        }
    }

    fn parseDocument(self: *Self) !Value {
        try self.skipCommentsAndNewlines();

        // Skip document start marker if present
        if (self.current_token.type == .DocumentStart) {
            try self.advance();
            try self.skipCommentsAndNewlines();
        }

        if (self.current_token.type == .EOF) {
            // Empty document
            return Value.init_nil();
        }

        return try self.parseValue();
    }

    const ParseValueError = error{
        ExpectedValue,
        InvalidInteger,
        InvalidFloat,
        InvalidString,
        InvalidUnicodeEscape,
        UnterminatedString,
        UnexpectedToken,
        UnexpectedCharacter,
        NotATable,
        KeyAlreadyExists,
        InvalidKey,
        ExpectedColon,
        OutOfMemory,
    };

    fn parseValue(self: *Self) ParseValueError!Value {
        switch (self.current_token.type) {
            .String => return try self.parseString(),
            .Integer => return try self.parseInteger(),
            .Float => return try self.parseFloat(),
            .Boolean => return try self.parseBoolean(),
            .Null => return try self.parseNull(),
            .SequenceStart => return try self.parseFlowSequence(),
            .MappingStart => return try self.parseFlowMapping(),
            .BlockSequenceItem => return try self.parseBlockSequence(),
            else => {
                // Try to parse as block mapping or plain string
                if (self.isBlockMappingStart()) {
                    return try self.parseBlockMapping();
                }

                // Default to string
                return try self.parseString();
            },
        }
    }

    fn parseString(self: *Self) !Value {
        const token_value = self.current_token.value;
        var result: []u8 = undefined;

        if (token_value.len >= 2 and (token_value[0] == '"' or token_value[0] == '\'')) {
            // Quoted string - process escape sequences
            const quote_char = token_value[0];
            const content = token_value[1 .. token_value.len - 1];

            if (quote_char == '"') {
                result = try self.processEscapeSequences(content);
            } else {
                // Single quoted - in YAML, '' (two single quotes) escapes to '
                result = try self.processSingleQuoteEscapes(content);
            }
        } else {
            // Plain string
            result = try self.allocator.dupe(u8, token_value);
        }

        try self.advance();

        const obj_str = object_h.String.copy(result, result.len);
        return Value.init_obj(@as(*Obj, @ptrCast(obj_str)));
    }

    fn processEscapeSequences(self: *Self, content: []const u8) ![]u8 {
        var result = std.ArrayList(u8).initCapacity(self.allocator, 0) catch unreachable;

        var i: usize = 0;
        while (i < content.len) {
            if (content[i] == '\\' and i + 1 < content.len) {
                switch (content[i + 1]) {
                    'n' => try result.append(self.allocator, '\n'),
                    't' => try result.append(self.allocator, '\t'),
                    'r' => try result.append(self.allocator, '\r'),
                    '\\' => try result.append(self.allocator, '\\'),
                    '"' => try result.append(self.allocator, '"'),
                    'u' => {
                        // Unicode escape \uXXXX
                        if (i + 5 < content.len) {
                            const hex = content[i + 2 .. i + 6];
                            const code_point = std.fmt.parseInt(u21, hex, 16) catch {
                                return error.InvalidUnicodeEscape;
                            };

                            // Convert to UTF-8
                            var utf8_buf: [4]u8 = undefined;
                            const utf8_len = std.unicode.utf8Encode(code_point, &utf8_buf) catch {
                                return error.InvalidUnicodeEscape;
                            };

                            try result.appendSlice(self.allocator, utf8_buf[0..utf8_len]);
                            i += 5; // Skip \uXXXX
                        } else {
                            return error.InvalidUnicodeEscape;
                        }
                    },
                    else => {
                        try result.append(self.allocator, content[i + 1]);
                    },
                }
                i += 2;
            } else {
                try result.append(self.allocator, content[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Process single quote escapes in YAML single-quoted strings
    ///
    /// In YAML, single-quoted strings have minimal escaping:
    /// - '' (two single quotes) -> ' (one single quote)
    /// - All other characters are literal (including backslashes)
    ///
    /// This is different from double-quoted strings which support
    /// full escape sequences like \n, \t, \uXXXX, etc.
    fn processSingleQuoteEscapes(self: *Self, content: []const u8) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(self.allocator, content.len);

        var i: usize = 0;
        while (i < content.len) {
            if (content[i] == '\'' and i + 1 < content.len and content[i + 1] == '\'') {
                // Two single quotes -> one single quote
                try result.append(self.allocator, '\'');
                i += 2;
            } else {
                try result.append(self.allocator, content[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    fn parseInteger(self: *Self) !Value {
        const int_value = std.fmt.parseInt(i64, self.current_token.value, 10) catch {
            return error.InvalidInteger;
        };
        try self.advance();
        return Value.init_int(@intCast(int_value));
    }

    fn parseFloat(self: *Self) !Value {
        const float_value = std.fmt.parseFloat(f64, self.current_token.value) catch {
            return error.InvalidFloat;
        };
        try self.advance();
        return Value.init_double(float_value);
    }

    fn parseBoolean(self: *Self) !Value {
        const bool_value = std.mem.eql(u8, self.current_token.value, "true");
        try self.advance();
        return Value.init_bool(bool_value);
    }

    fn parseNull(self: *Self) !Value {
        try self.advance();
        return Value.init_nil();
    }

    fn parseFlowSequence(self: *Self) !Value {
        try self.advance(); // consume [

        const list = object_h.LinkedList.init();

        try self.skipCommentsAndNewlines();

        while (self.current_token.type != .SequenceEnd and self.current_token.type != .EOF) {
            const value = self.parseValue() catch Value.init_nil();
            list.push(value);

            try self.skipCommentsAndNewlines();

            if (self.current_token.type == .FlowEntry) {
                try self.advance(); // consume ,
                try self.skipCommentsAndNewlines();
            }
        }

        if (self.current_token.type == .SequenceEnd) {
            try self.advance(); // consume ]
        }

        return Value.init_obj(@as(*Obj, @ptrCast(list)));
    }

    fn parseBlockSequence(self: *Self) !Value {
        const list = object_h.LinkedList.init();
        const base_indent = self.current_token.indent_level;

        while (self.current_token.type == .BlockSequenceItem and
            self.current_token.indent_level == base_indent)
        {
            try self.advance(); // consume -

            try self.skipCommentsAndNewlines();

            if (self.current_token.type != .EOF and
                self.current_token.indent_level > base_indent)
            {
                const value = self.parseValue() catch Value.init_nil();
                list.push(value);
            } else {
                // Empty sequence item
                list.push(Value.init_nil());
            }

            try self.skipCommentsAndNewlines();
        }

        return Value.init_obj(@as(*Obj, @ptrCast(list)));
    }

    fn parseFlowMapping(self: *Self) !Value {
        try self.advance(); // consume {

        const table = object_h.HashTable.init();

        try self.skipCommentsAndNewlines();

        while (self.current_token.type != .MappingEnd and self.current_token.type != .EOF) {
            // Parse key
            const key_value = self.parseValue() catch Value.init_nil();
            if (!key_value.is_obj() or !key_value.is_obj_type(.OBJ_STRING)) {
                return error.InvalidKey;
            }

            try self.skipCommentsAndNewlines();

            // Expect colon
            if (self.current_token.type != .BlockMappingKey) {
                return error.ExpectedColon;
            }
            try self.advance();

            try self.skipCommentsAndNewlines();

            // Parse value
            const value = self.parseValue() catch Value.init_nil();

            // Insert into table
            const key_obj = @as(*ObjString, @ptrCast(@alignCast(key_value.as.obj)));
            _ = table.put(key_obj, value);

            try self.skipCommentsAndNewlines();

            if (self.current_token.type == .FlowEntry) {
                try self.advance(); // consume ,
                try self.skipCommentsAndNewlines();
            }
        }

        if (self.current_token.type == .MappingEnd) {
            try self.advance(); // consume }
        }

        return Value.init_obj(@as(*Obj, @ptrCast(table)));
    }

    fn isBlockMappingStart(self: *Self) bool {
        // Look ahead to see if this looks like a block mapping
        // This is a simplified heuristic
        const saved_current = self.lexer.current;
        const saved_line = self.lexer.line;
        const saved_column = self.lexer.column;

        // Try to find a colon on this line
        while (self.lexer.current < self.lexer.source.len) {
            const char = self.lexer.source[self.lexer.current];
            if (char == ':' and self.lexer.current + 1 < self.lexer.source.len and
                (self.lexer.source[self.lexer.current + 1] == ' ' or
                    self.lexer.source[self.lexer.current + 1] == '\t' or
                    self.lexer.source[self.lexer.current + 1] == '\n'))
            {

                // Restore position
                self.lexer.current = saved_current;
                self.lexer.line = saved_line;
                self.lexer.column = saved_column;
                return true;
            }
            if (char == '\n') break;
            self.lexer.current += 1;
        }

        // Restore position
        self.lexer.current = saved_current;
        self.lexer.line = saved_line;
        self.lexer.column = saved_column;
        return false;
    }

    fn parseBlockMapping(self: *Self) !Value {
        const table = object_h.HashTable.init();
        const base_indent = self.current_token.indent_level;

        while (self.current_token.type != .EOF and
            self.current_token.indent_level == base_indent and
            self.isBlockMappingStart())
        {

            // Parse key
            const key_value = self.parseValue() catch Value.init_nil();
            if (!key_value.is_obj() or !key_value.is_obj_type(.OBJ_STRING)) {
                return error.InvalidKey;
            }

            // Expect colon
            if (self.current_token.type != .BlockMappingKey) {
                return error.ExpectedColon;
            }
            try self.advance();

            try self.skipCommentsAndNewlines();

            // Parse value
            const value = if (self.current_token.type != .EOF and
                self.current_token.indent_level > base_indent)
                self.parseValue() catch Value.init_nil()
            else
                Value.init_nil();

            // Insert into table
            const key_obj = @as(*ObjString, @ptrCast(@alignCast(key_value.as.obj)));
            _ = table.put(key_obj, value);

            try self.skipCommentsAndNewlines();
        }

        return Value.init_obj(@as(*Obj, @ptrCast(table)));
    }
};

/// YAML Serializer implementation
pub const YamlSerializer = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    indent_level: u32,
    flow_style: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .output = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            .indent_level = 0,
            .flow_style = false,
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
        self.indent_level = 0;
        self.flow_style = !options.pretty;

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
        switch (value.type) {
            .VAL_NIL => {
                try self.output.appendSlice(self.allocator, "null");
            },
            .VAL_BOOL => {
                const bool_str = if (value.as.boolean) "true" else "false";
                try self.output.appendSlice(self.allocator, bool_str);
            },
            .VAL_INT => {
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_int});
            },
            .VAL_DOUBLE => {
                if (std.math.isNan(value.as.num_double)) {
                    try self.output.appendSlice(self.allocator, ".nan");
                } else if (std.math.isPositiveInf(value.as.num_double)) {
                    try self.output.appendSlice(self.allocator, ".inf");
                } else if (std.math.isNegativeInf(value.as.num_double)) {
                    try self.output.appendSlice(self.allocator, "-.inf");
                } else {
                    try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_double});
                }
            },
            .VAL_COMPLEX => {
                try self.serializeComplex(value.as.complex, options, context);
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

    fn serializeComplex(
        self: *Self,
        complex: Complex,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        _ = options;
        _ = context;

        if (self.flow_style) {
            try self.output.appendSlice(self.allocator, "{real: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{complex.r});
            try self.output.appendSlice(self.allocator, ", imag: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{complex.i});
            try self.output.append(self.allocator, '}');
        } else {
            try self.output.appendSlice(self.allocator, "real: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{complex.r});
            try self.output.append(self.allocator, '\n');
            try self.writeIndent();
            try self.output.appendSlice(self.allocator, "imag: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{complex.i});
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
                try self.serializeFloatVector(fvec);
            },
            .OBJ_MATRIX => {
                const matrix = @as(*Matrix, @ptrCast(@alignCast(obj)));
                try self.serializeMatrix(matrix, options, context);
            },
            .OBJ_RANGE => {
                const range = @as(*ObjRange, @ptrCast(@alignCast(obj)));
                try self.serializeRange(range, options, context);
            },
            .OBJ_PAIR => {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(obj)));
                try self.serializePair(pair, options, context);
            },
            else => {
                return SerdeError.UnsupportedType;
            },
        }
    }

    fn serializeString(self: *Self, str: []const u8) !void {
        const needs_quoting = self.stringNeedsQuoting(str);

        if (needs_quoting) {
            try self.output.append(self.allocator, '"');
            try self.writeEscapedString(str);
            try self.output.append(self.allocator, '"');
        } else {
            try self.output.appendSlice(self.allocator, str);
        }
    }

    fn stringNeedsQuoting(self: *Self, str: []const u8) bool {
        _ = self;

        if (str.len == 0) return true;

        // Check for YAML special values
        if (std.mem.eql(u8, str, "true") or
            std.mem.eql(u8, str, "false") or
            std.mem.eql(u8, str, "null") or
            std.mem.eql(u8, str, "~") or
            std.mem.eql(u8, str, "yes") or
            std.mem.eql(u8, str, "no") or
            std.mem.eql(u8, str, "on") or
            std.mem.eql(u8, str, "off"))
        {
            return true;
        }

        // Check for numeric values
        if (std.fmt.parseInt(i64, str, 10)) |_| {
            return true; // It's an integer
        } else |_| {
            if (std.fmt.parseFloat(f64, str)) |_| {
                return true; // It's a float
            } else |_| {
                // Not a number, continue checking
            }
        }

        // Check for special characters
        for (str) |char| {
            switch (char) {
                ':', '[', ']', '{', '}', ',', '#', '&', '*', '!', '|', '>', '\'', '"', '%', '@', '`' => return true,
                0x00...0x1F, 0x7F => return true, // Control characters
                else => continue,
            }
        }

        // Check if it starts with special characters
        switch (str[0]) {
            '-', '?', ':', '<', '=', '>', '!', '%', '@', '`' => return true,
            ' ', '\t' => return true, // Leading whitespace
            else => {},
        }

        // Check if it ends with whitespace
        if (str[str.len - 1] == ' ' or str[str.len - 1] == '\t') {
            return true;
        }

        return false;
    }

    fn writeEscapedString(self: *Self, str: []const u8) !void {
        for (str) |char| {
            switch (char) {
                '"' => try self.output.appendSlice(self.allocator, "\\\""),
                '\\' => try self.output.appendSlice(self.allocator, "\\\\"),
                '\t' => try self.output.appendSlice(self.allocator, "\\t"),
                '\n' => try self.output.appendSlice(self.allocator, "\\n"),
                '\r' => try self.output.appendSlice(self.allocator, "\\r"),
                0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F, 0x7F => {
                    try std.fmt.format(self.output.writer(self.allocator), "\\u{d:0>4}", .{char});
                },
                else => try self.output.append(self.allocator, char),
            }
        }
    }

    fn serializeHashTable(
        self: *Self,
        hash_table: *ObjHashTable,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        if (self.flow_style) {
            try self.output.append(self.allocator, '{');

            const pairs = hash_table.toPairs();
            var current = pairs.head;
            var first = true;

            while (current) |node| {
                const pair_value = node.data;
                if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                    const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                    if (!first) {
                        try self.output.appendSlice(self.allocator, ", ");
                    }
                    first = false;

                    if (!pair.key.is_string()) {
                        return SerdeError.InvalidKey;
                    }

                    const key = pair.key.as_string().chars;
                    try self.serializeString(key);
                    try self.output.appendSlice(self.allocator, ": ");
                    try self.serializeValue(pair.value, options, context);
                }
                current = node.next;
            }

            try self.output.append(self.allocator, '}');
        } else {
            const pairs = hash_table.toPairs();
            var current = pairs.head;
            var first = true;

            while (current) |node| {
                const pair_value = node.data;
                if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                    const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                    if (!first) {
                        try self.output.append(self.allocator, '\n');
                        try self.writeIndent();
                    }
                    first = false;

                    if (!pair.key.is_string()) {
                        return SerdeError.InvalidKey;
                    }

                    const key = pair.key.as_string().chars;
                    try self.serializeString(key);
                    try self.output.appendSlice(self.allocator, ": ");

                    // If value is complex, increase indentation
                    const needs_indent = pair.value.is_obj() and
                        (pair.value.is_obj_type(.OBJ_HASH_TABLE) or pair.value.is_obj_type(.OBJ_LINKED_LIST));

                    if (needs_indent and !self.flow_style) {
                        try self.output.append(self.allocator, '\n');
                        self.indent_level += 1;
                        try self.writeIndent();
                        try self.serializeValue(pair.value, options, context);
                        self.indent_level -= 1;
                    } else {
                        try self.serializeValue(pair.value, options, context);
                    }
                }
                current = node.next;
            }
        }
    }

    fn serializeLinkedList(
        self: *Self,
        list: *LinkedList,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        if (self.flow_style) {
            try self.output.append(self.allocator, '[');

            var current = list.head;
            var first = true;

            while (current) |node| {
                if (!first) {
                    try self.output.appendSlice(self.allocator, ", ");
                }
                first = false;

                try self.serializeValue(node.data, options, context);
                current = node.next;
            }

            try self.output.append(self.allocator, ']');
        } else {
            var current = list.head;

            while (current) |node| {
                try self.writeIndent();
                try self.output.appendSlice(self.allocator, "- ");

                const needs_indent = node.data.is_obj() and
                    (node.data.is_obj_type(.OBJ_HASH_TABLE) or node.data.is_obj_type(.OBJ_LINKED_LIST));

                if (needs_indent) {
                    self.indent_level += 1;
                    try self.serializeValue(node.data, options, context);
                    self.indent_level -= 1;
                } else {
                    try self.serializeValue(node.data, options, context);
                }

                current = node.next;
                if (current != null) {
                    try self.output.append(self.allocator, '\n');
                }
            }
        }
    }

    fn serializeFloatVector(self: *Self, fvec: *FloatVector) !void {
        if (self.flow_style) {
            try self.output.append(self.allocator, '[');
        }

        for (fvec.data[0..fvec.size], 0..) |value, i| {
            if (self.flow_style) {
                if (i > 0) try self.output.appendSlice(self.allocator, ", ");
            } else {
                if (i > 0) try self.output.append(self.allocator, '\n');
                try self.writeIndent();
                try self.output.appendSlice(self.allocator, "- ");
            }
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value});
        }

        if (self.flow_style) {
            try self.output.append(self.allocator, ']');
        }
    }

    fn serializeMatrix(
        self: *Self,
        matrix: *Matrix,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        _ = options;
        _ = context;

        if (self.flow_style) {
            try self.output.append(self.allocator, '[');
        }

        for (0..matrix.rows) |row| {
            if (self.flow_style) {
                if (row > 0) try self.output.appendSlice(self.allocator, ", ");
                try self.output.append(self.allocator, '[');
            } else {
                if (row > 0) try self.output.append(self.allocator, '\n');
                try self.writeIndent();
                try self.output.appendSlice(self.allocator, "- [");
            }

            for (0..matrix.cols) |col| {
                if (col > 0) try self.output.appendSlice(self.allocator, ", ");
                const idx = row * matrix.cols + col;
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{matrix.data[idx]});
            }

            try self.output.append(self.allocator, ']');
        }

        if (self.flow_style) {
            try self.output.append(self.allocator, ']');
        }
    }

    fn serializeRange(
        self: *Self,
        range: *ObjRange,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        _ = options;
        _ = context;

        if (self.flow_style) {
            try self.output.appendSlice(self.allocator, "{start: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.start});
            try self.output.appendSlice(self.allocator, ", end: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.end});
            try self.output.appendSlice(self.allocator, ", inclusive: ");
            const inclusive_str = if (range.inclusive) "true" else "false";
            try self.output.appendSlice(self.allocator, inclusive_str);
            try self.output.append(self.allocator, '}');
        } else {
            try self.output.appendSlice(self.allocator, "start: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.start});
            try self.output.append(self.allocator, '\n');
            try self.writeIndent();
            try self.output.appendSlice(self.allocator, "end: ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{range.end});
            try self.output.append(self.allocator, '\n');
            try self.writeIndent();
            try self.output.appendSlice(self.allocator, "inclusive: ");
            const inclusive_str = if (range.inclusive) "true" else "false";
            try self.output.appendSlice(self.allocator, inclusive_str);
        }
    }

    fn serializePair(
        self: *Self,
        pair: *ObjPair,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        if (self.flow_style) {
            try self.output.appendSlice(self.allocator, "{key: ");
            try self.serializeValue(pair.key, options, context);
            try self.output.appendSlice(self.allocator, ", value: ");
            try self.serializeValue(pair.value, options, context);
            try self.output.append(self.allocator, '}');
        } else {
            try self.output.appendSlice(self.allocator, "key: ");
            try self.serializeValue(pair.key, options, context);
            try self.output.append(self.allocator, '\n');
            try self.writeIndent();
            try self.output.appendSlice(self.allocator, "value: ");
            try self.serializeValue(pair.value, options, context);
        }
    }

    fn writeIndent(self: *Self) !void {
        const indent_size = self.indent_level * 2;
        for (0..indent_size) |_| {
            try self.output.append(self.allocator, ' ');
        }
    }

    pub fn supportsType(self: *Self, value_type: ValueType) bool {
        _ = self;
        return switch (value_type) {
            .VAL_NIL, .VAL_BOOL, .VAL_INT, .VAL_DOUBLE, .VAL_COMPLEX, .VAL_OBJ => true,
        };
    }
};

/// YAML Deserializer implementation
pub const YamlDeserializer = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(source: []const u8, allocator: std.mem.Allocator) Self {
        _ = source;
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deserialize(
        self: *Self,
        data: []const u8,
        options: DeserializeOptions,
        context: *SerdeContext,
    ) SerdeError!Value {
        _ = options;
        _ = context;

        var parser = YamlParser.init(data, self.allocator) catch {
            return SerdeError.ParseError;
        };
        defer parser.deinit();

        return parser.parseDocument() catch |err| {
            return switch (err) {
                error.UnterminatedString => SerdeError.ParseError,
                error.InvalidInteger => SerdeError.ParseError,
                error.InvalidFloat => SerdeError.ParseError,
                error.InvalidUnicodeEscape => SerdeError.ParseError,
                error.InvalidKey => SerdeError.ParseError,
                error.ExpectedColon => SerdeError.ParseError,
                error.OutOfMemory => SerdeError.OutOfMemory,
                else => SerdeError.ParseError,
            };
        };
    }

    pub fn canDeserialize(self: *Self, data: []const u8) bool {
        _ = self;

        // Basic YAML detection
        var i: usize = 0;

        // Skip whitespace and comments
        while (i < data.len) {
            const char = data[i];
            switch (char) {
                ' ', '\t', '\r', '\n' => {
                    i += 1;
                    continue;
                },
                '#' => {
                    // Skip comment line
                    while (i < data.len and data[i] != '\n') {
                        i += 1;
                    }
                    continue;
                },
                '-' => {
                    // Check for document separator (---) or list item (- )
                    if (i + 2 < data.len and data[i + 1] == '-' and data[i + 2] == '-') {
                        return true; // Document separator
                    }
                    if (i + 1 < data.len and data[i + 1] == ' ') {
                        return true; // List item
                    }
                    return false;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    // Look for key: value pattern
                    while (i < data.len) {
                        const key_char = data[i];
                        switch (key_char) {
                            'a'...'z', 'A'...'Z', '0'...'9', '_', '-' => i += 1,
                            ':' => {
                                // Found key: pattern
                                return true;
                            },
                            ' ', '\t' => {
                                // Skip whitespace and look for colon
                                while (i < data.len and (data[i] == ' ' or data[i] == '\t')) {
                                    i += 1;
                                }
                                if (i < data.len and data[i] == ':') {
                                    return true;
                                }
                                return false;
                            },
                            else => return false,
                        }
                    }
                    break;
                },
                '[', '{' => {
                    // Flow style - could be YAML or JSON
                    return true;
                },
                else => return false,
            }
        }

        return false;
    }
};

// Format detection function
fn detectYamlFormat(data: []const u8) bool {
    var deserializer = YamlDeserializer.init(data, std.heap.page_allocator);
    return deserializer.canDeserialize(data);
}

// High-level functions that integrate with the Serde registry
pub fn serializeYaml(
    value: Value,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) SerdeError![]const u8 {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var serializer = YamlSerializer.init(allocator);
    defer serializer.deinit();

    return serializer.serialize(value, options, &context);
}

pub fn deserializeYaml(
    data: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var deserializer = YamlDeserializer.init(data, allocator);
    return deserializer.deserialize(data, options, &context);
}

// Register YAML format with the global registry
pub fn registerYamlFormat(allocator: std.mem.Allocator) !void {
    const registry = serde.getGlobalRegistry(allocator);
    const extensions = [_][]const u8{ ".yaml", ".yml" };

    try registry.registerFormat(
        "yaml",
        &extensions,
        serializeYaml,
        deserializeYaml,
        detectYamlFormat,
    );
}
