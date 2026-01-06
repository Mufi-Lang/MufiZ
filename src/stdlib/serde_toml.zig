/// TOML Serializer/Deserializer Implementation using MufiZ Serde Interface
///
/// This module implements TOML serialization and deserialization for MufiZ values
/// using the common Serde interface defined in ../serde.zig.
///
/// TOML Features:
/// - Hierarchical key-value configuration format
/// - Strong typing with explicit type annotations
/// - Support for arrays, tables, and inline tables
/// - Comments and multiline strings
/// - Date/time types (future extension)
///
/// TOML Type Mapping:
/// - VAL_NIL -> not serialized (TOML doesn't have null)
/// - VAL_BOOL -> true/false
/// - VAL_INT -> integer
/// - VAL_DOUBLE -> float
/// - VAL_COMPLEX -> table with 'real' and 'imag' keys
/// - OBJ_STRING -> string (quoted if necessary)
/// - OBJ_HASH_TABLE -> table
/// - OBJ_LINKED_LIST -> array
/// - OBJ_FVECTOR -> array of floats
/// - OBJ_MATRIX -> array of arrays
/// - OBJ_RANGE -> table with 'start', 'end', 'inclusive' keys
/// - OBJ_PAIR -> inline table with 'key' and 'value'
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

/// TOML Token Types
const TokenType = enum {
    EOF,

    // Literals
    String,
    Integer,
    Float,
    Boolean,

    // Punctuation
    LeftBracket, // [
    RightBracket, // ]
    LeftBrace, // {
    RightBrace, // }
    Equals, // =
    Comma, // ,
    Dot, // .

    // Identifiers
    Identifier,

    // Special
    Comment,
    Newline,

    // Array of tables
    ArrayTableStart, // [[
};

const Token = struct {
    type: TokenType,
    value: []const u8,
    line: u32,
    column: u32,
};

/// TOML Lexer
const TomlLexer = struct {
    source: []const u8,
    current: usize,
    line: u32,
    column: u32,

    const Self = @This();

    fn init(source: []const u8) Self {
        return Self{
            .source = source,
            .current = 0,
            .line = 1,
            .column = 1,
        };
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
        } else {
            self.column += 1;
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

    fn match(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.isAtEnd()) {
            switch (self.peek()) {
                ' ', '\t', '\r' => _ = self.advance(),
                else => break,
            }
        }
    }

    fn makeToken(self: *Self, token_type: TokenType, start: usize) Token {
        return Token{
            .type = token_type,
            .value = self.source[start..self.current],
            .line = self.line,
            .column = self.column - @as(u32, @intCast(self.current - start)),
        };
    }

    fn scanString(self: *Self) !Token {
        const start = self.current - 1; // Include opening quote

        while (!self.isAtEnd() and self.peek() != '"') {
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

    fn scanNumber(self: *Self) Token {
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

    fn scanIdentifier(self: *Self) Token {
        const start = self.current - 1;

        while (!self.isAtEnd()) {
            const char = self.peek();
            switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '-' => _ = self.advance(),
                else => break,
            }
        }

        const text = self.source[start..self.current];

        // Check for boolean literals
        if (std.mem.eql(u8, text, "true") or std.mem.eql(u8, text, "false")) {
            return self.makeToken(.Boolean, start);
        }

        return self.makeToken(.Identifier, start);
    }

    fn scanComment(self: *Self) Token {
        const start = self.current - 1;

        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }

        return self.makeToken(.Comment, start);
    }

    fn nextToken(self: *Self) !Token {
        self.skipWhitespace();

        if (self.isAtEnd()) {
            return self.makeToken(.EOF, self.current);
        }

        const start = self.current;
        const char = self.advance();

        switch (char) {
            '[' => {
                if (self.match('[')) {
                    return self.makeToken(.ArrayTableStart, start);
                }
                return self.makeToken(.LeftBracket, start);
            },
            ']' => return self.makeToken(.RightBracket, start),
            '{' => return self.makeToken(.LeftBrace, start),
            '}' => return self.makeToken(.RightBrace, start),
            '=' => return self.makeToken(.Equals, start),
            ',' => return self.makeToken(.Comma, start),
            '.' => return self.makeToken(.Dot, start),
            '\n' => return self.makeToken(.Newline, start),
            '"' => return try self.scanString(),
            '#' => return self.scanComment(),
            '-' => {
                if (std.ascii.isDigit(self.peek())) {
                    return self.scanNumber();
                }
                return self.scanIdentifier();
            },
            '0'...'9' => return self.scanNumber(),
            'a'...'z', 'A'...'Z', '_' => return self.scanIdentifier(),
            else => return error.UnexpectedCharacter,
        }
    }
};

/// TOML Parser
const TomlParser = struct {
    lexer: TomlLexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(source: []const u8, allocator: std.mem.Allocator) !Self {
        var lexer = TomlLexer.init(source);
        const current_token = try lexer.nextToken();

        return Self{
            .lexer = lexer,
            .current_token = current_token,
            .allocator = allocator,
        };
    }

    fn advance(self: *Self) !void {
        self.current_token = try self.lexer.nextToken();
    }

    fn skipNewlinesAndComments(self: *Self) !void {
        while (self.current_token.type == .Newline or self.current_token.type == .Comment) {
            try self.advance();
        }
    }

    fn match(self: *Self, token_type: TokenType) bool {
        if (self.current_token.type == token_type) {
            return true;
        }
        return false;
    }

    fn consume(self: *Self, token_type: TokenType) !void {
        if (self.current_token.type != token_type) {
            return error.UnexpectedToken;
        }
        try self.advance();
    }

    fn parseDocument(self: *Self) !Value {
        const root_table = object_h.HashTable.init();
        var root_value = Value.init_obj(@as(*Obj, @ptrCast(root_table)));

        try self.skipNewlinesAndComments();

        while (self.current_token.type != .EOF) {
            if (self.current_token.type == .LeftBracket) {
                try self.parseTable(&root_value);
            } else if (self.current_token.type == .ArrayTableStart) {
                try self.parseArrayTable(&root_value);
            } else if (self.current_token.type == .Identifier) {
                try self.parseKeyValue(&root_value);
            } else {
                try self.advance();
            }

            try self.skipNewlinesAndComments();
        }

        return root_value;
    }

    fn parseTable(self: *Self, root: *Value) !void {
        try self.consume(.LeftBracket);

        const key_path = try self.parseKeyPath();
        defer self.allocator.free(key_path);

        try self.consume(.RightBracket);
        try self.skipNewlinesAndComments();

        // Navigate to or create the table
        var current_table = root;
        for (key_path) |key| {
            current_table = try self.getOrCreateTable(current_table, key);
        }

        // Parse key-value pairs for this table
        while (self.current_token.type == .Identifier) {
            try self.parseKeyValue(current_table);
            try self.skipNewlinesAndComments();
        }
    }

    /// Parse TOML array of tables: [[key.path]]
    /// 
    /// Array of tables allow multiple table instances under the same key.
    /// Example TOML:
    /// ```toml
    /// [[products]]
    /// name = "Hammer"
    /// sku = 738594937
    /// 
    /// [[products]]
    /// name = "Nail"
    /// sku = 284758393
    /// ```
    /// 
    /// This creates an array at root["products"] containing two table objects.
    /// Each [[products]] declaration creates a new table and appends it to the array.
    fn parseArrayTable(self: *Self, root: *Value) !void {
        try self.consume(.ArrayTableStart);

        const key_path = try self.parseKeyPath();
        defer self.allocator.free(key_path);

        try self.consume(.RightBracket);
        try self.consume(.RightBracket);
        try self.skipNewlinesAndComments();

        // Array of tables: [[key.path]]
        // Navigate to the parent table and create/append to array
        var current = root;
        
        // Navigate to parent (all keys except the last)
        for (key_path[0 .. key_path.len - 1]) |key| {
            current = try self.getOrCreateTable(current, key);
        }
        
        // Get or create array for the last key
        const array_key = key_path[key_path.len - 1];
        const array = try self.getOrCreateArray(current, array_key);
        
        // Create a new table and add it to the array
        const new_table = object_h.HashTable.init();
        const table_value = Value.init_obj(@as(*Obj, @ptrCast(new_table)));
        
        // Add the table to the array (LinkedList) using push method
        const list = @as(*object_h.LinkedList, @ptrCast(@alignCast(array.as.obj)));
        list.push(table_value);
        
        // Parse key-value pairs for this table instance
        const table_ptr = @constCast(&table_value);
        while (self.current_token.type == .Identifier) {
            try self.parseKeyValue(table_ptr);
            try self.skipNewlinesAndComments();
        }
    }

    fn getOrCreateArray(self: *Self, parent: *Value, key: []const u8) !Value {
        _ = self;
        if (!parent.is_obj() or !parent.is_obj_type(.OBJ_HASH_TABLE)) {
            return error.NotATable;
        }

        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(parent.as.obj)));
        const key_obj = object_h.String.copy(key, key.len);

        if (hash_table.get(key_obj)) |existing| {
            // Ensure it's a linked list (array)
            if (existing.is_obj() and existing.is_obj_type(.OBJ_LINKED_LIST)) {
                return existing;
            } else {
                return error.KeyAlreadyExistsAsNonArray;
            }
        }

        // Create new linked list for the array
        const new_list = object_h.LinkedList.init();
        const list_value = Value.init_obj(@as(*Obj, @ptrCast(new_list)));

        _ = hash_table.put(key_obj, list_value);
        return hash_table.get(key_obj).?;
    }

    fn parseKeyValue(self: *Self, table: *Value) !void {
        const key = try self.parseKey();
        defer self.allocator.free(key);

        try self.consume(.Equals);

        const value = try self.parseValue();

        // Insert into table
        try self.insertIntoTable(table, key, value);
    }

    fn parseKeyPath(self: *Self) ![][]u8 {
        var path = std.ArrayList([]u8).initCapacity(self.allocator, 0) catch unreachable;

        const first_key = try self.parseKey();
        try path.append(self.allocator, first_key);

        while (self.match(.Dot)) {
            try self.advance(); // consume dot
            const next_key = try self.parseKey();
            try path.append(self.allocator, next_key);
        }

        return path.toOwnedSlice(self.allocator);
    }

    fn parseKey(self: *Self) ![]u8 {
        switch (self.current_token.type) {
            .Identifier => {
                const key = try self.allocator.dupe(u8, self.current_token.value);
                try self.advance();
                return key;
            },
            .String => {
                const key = try self.parseStringValue();
                try self.advance();
                return key;
            },
            else => return error.ExpectedKey,
        }
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
        ExpectedKey,
        ExpectedColon,
        OutOfMemory,
    };

    fn parseValue(self: *Self) ParseValueError!Value {
        switch (self.current_token.type) {
            .String => {
                const str_value = try self.parseStringValue();
                const obj_str = object_h.String.copy(str_value, str_value.len);
                try self.advance();
                return Value.init_obj(@as(*Obj, @ptrCast(obj_str)));
            },
            .Integer => {
                const int_value = std.fmt.parseInt(i64, self.current_token.value, 10) catch {
                    return error.InvalidInteger;
                };
                try self.advance();
                return Value.init_int(@intCast(int_value));
            },
            .Float => {
                const float_value = std.fmt.parseFloat(f64, self.current_token.value) catch {
                    return error.InvalidFloat;
                };
                try self.advance();
                return Value.init_double(float_value);
            },
            .Boolean => {
                const bool_value = std.mem.eql(u8, self.current_token.value, "true");
                try self.advance();
                return Value.init_bool(bool_value);
            },
            .LeftBrace => return try self.parseInlineTable(),
            .LeftBracket => return try self.parseArray(),
            else => return error.ExpectedValue,
        }
    }

    fn parseStringValue(self: *Self) ![]u8 {
        const token_value = self.current_token.value;

        // Remove quotes and process escape sequences
        if (token_value.len < 2 or token_value[0] != '"' or token_value[token_value.len - 1] != '"') {
            return error.InvalidString;
        }

        const content = token_value[1 .. token_value.len - 1];
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
                            const code_point = std.fmt.parseInt(u16, hex, 16) catch {
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

    fn parseInlineTable(self: *Self) !Value {
        try self.consume(.LeftBrace);

        const table = object_h.HashTable.init();
        var table_value = Value.init_obj(@as(*Obj, @ptrCast(table)));

        // Parse key-value pairs
        while (!self.match(.RightBrace) and self.current_token.type != .EOF) {
            const key = try self.parseKey();
            defer self.allocator.free(key);

            try self.consume(.Equals);

            const value = try self.parseValue();
            try self.insertIntoTable(&table_value, key, value);

            if (self.match(.Comma)) {
                try self.advance();
            } else {
                break;
            }
        }

        try self.consume(.RightBrace);
        return table_value;
    }

    fn parseArray(self: *Self) !Value {
        try self.consume(.LeftBracket);

        const list = object_h.LinkedList.init();

        while (!self.match(.RightBracket) and self.current_token.type != .EOF) {
            const value = self.parseValue() catch Value.init_nil();
            list.push(value);

            if (self.match(.Comma)) {
                try self.advance();
                try self.skipNewlinesAndComments();
            } else {
                break;
            }
        }

        try self.consume(.RightBracket);
        return Value.init_obj(@as(*Obj, @ptrCast(list)));
    }

    fn getOrCreateTable(self: *Self, parent: *Value, key: []const u8) !*Value {
        _ = self;
        if (!parent.is_obj() or !parent.is_obj_type(.OBJ_HASH_TABLE)) {
            return error.NotATable;
        }

        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(parent.as.obj)));

        // Try to find existing key
        const key_obj = object_h.String.copy(key, key.len);

        if (hash_table.get(key_obj)) |existing| {
            if (existing.is_obj() and existing.is_obj_type(.OBJ_HASH_TABLE)) {
                return @constCast(&existing);
            } else {
                return error.KeyAlreadyExists;
            }
        }

        // Create new table
        const new_table = object_h.HashTable.init();
        const table_value = Value.init_obj(@as(*Obj, @ptrCast(new_table)));

        _ = hash_table.put(key_obj, table_value);

        // Return pointer to the stored value
        const stored_value = hash_table.get(key_obj).?;
        return @constCast(&stored_value);
    }

    fn insertIntoTable(self: *Self, table: *Value, key: []const u8, value: Value) !void {
        _ = self;
        if (!table.is_obj() or !table.is_obj_type(.OBJ_HASH_TABLE)) {
            return error.NotATable;
        }

        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(table.as.obj)));
        const key_obj = object_h.String.copy(key, key.len);

        _ = hash_table.put(key_obj, value);
    }
};

/// TOML Serializer implementation
pub const TomlSerializer = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    current_table_path: std.ArrayList([]const u8),
    written_tables: std.StringHashMap(void),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .output = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            .current_table_path = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .written_tables = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit(self.allocator);
        self.current_table_path.deinit(self.allocator);
        self.written_tables.deinit();
    }

    pub fn serialize(
        self: *Self,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError![]const u8 {
        self.output.clearRetainingCapacity();
        self.current_table_path.clearRetainingCapacity();
        self.written_tables.clearRetainingCapacity();

        // TOML must start with a table (object)
        if (!value.is_obj() or !value.is_obj_type(.OBJ_HASH_TABLE)) {
            return SerdeError.UnsupportedType;
        }

        try self.serializeRootTable(value, options, context);

        // Return owned copy of the serialized data
        return self.allocator.dupe(u8, self.output.items);
    }

    fn serializeRootTable(
        self: *Self,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(value.as.obj)));

        // First pass: write simple key-value pairs
        const pairs = hash_table.toPairs();
        var current = pairs.head;

        while (current) |node| {
            const pair_value = node.data;
            if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                if (!pair.key.is_string()) {
                    return SerdeError.InvalidKey;
                }

                const key = pair.key.as_string().chars;

                // Skip nested tables for now - they'll be handled in second pass
                if (pair.value.is_obj() and pair.value.is_obj_type(.OBJ_HASH_TABLE)) {
                    current = node.next;
                    continue;
                }

                try self.writeKeyValue(key, pair.value, options, context);
                try self.output.append(self.allocator, '\n');
            }
            current = node.next;
        }

        // Second pass: write tables
        current = pairs.head;
        while (current) |node| {
            const pair_value = node.data;
            if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                if (pair.value.is_obj() and pair.value.is_obj_type(.OBJ_HASH_TABLE)) {
                    const key = pair.key.as_string().chars;
                    try self.writeTable(key, pair.value, options, context);
                }
            }
            current = node.next;
        }
    }

    fn writeKeyValue(
        self: *Self,
        key: []const u8,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        try self.writeKey(key);
        try self.output.appendSlice(self.allocator, " = ");
        try self.serializeValue(value, options, context, false);
    }

    fn writeTable(
        self: *Self,
        table_name: []const u8,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
    ) SerdeError!void {
        // Write table header
        try self.output.append(self.allocator, '\n');
        try self.output.append(self.allocator, '[');
        try self.writeKey(table_name);
        try self.output.append(self.allocator, ']');
        try self.output.append(self.allocator, '\n');

        // Write table contents
        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
        const pairs = hash_table.toPairs();
        var current = pairs.head;

        while (current) |node| {
            const pair_value = node.data;
            if (pair_value.is_obj() and pair_value.is_obj_type(.OBJ_PAIR)) {
                const pair = @as(*ObjPair, @ptrCast(@alignCast(pair_value.as.obj)));

                if (!pair.key.is_string()) {
                    return SerdeError.InvalidKey;
                }

                const key = pair.key.as_string().chars;
                try self.writeKeyValue(key, pair.value, options, context);
                try self.output.append(self.allocator, '\n');
            }
            current = node.next;
        }
    }

    fn writeKey(self: *Self, key: []const u8) !void {
        // Check if key needs quoting
        const needs_quoting = self.keyNeedsQuoting(key);

        if (needs_quoting) {
            try self.output.append(self.allocator, '"');
            try self.writeEscapedString(key);
            try self.output.append(self.allocator, '"');
        } else {
            try self.output.appendSlice(self.allocator, key);
        }
    }

    fn keyNeedsQuoting(self: *Self, key: []const u8) bool {
        _ = self;

        if (key.len == 0) return true;

        // TOML bare keys can only contain A-Z, a-z, 0-9, -, _
        for (key) |char| {
            switch (char) {
                'A'...'Z', 'a'...'z', '0'...'9', '-', '_' => continue,
                else => return true,
            }
        }
        return false;
    }

    fn serializeValue(
        self: *Self,
        value: Value,
        options: SerializeOptions,
        context: *SerdeContext,
        inline_context: bool,
    ) SerdeError!void {
        switch (value.type) {
            .VAL_NIL => {
                // TOML doesn't have null - this is an error
                return SerdeError.UnsupportedType;
            },
            .VAL_BOOL => {
                const bool_str = if (value.as.boolean) "true" else "false";
                try self.output.appendSlice(self.allocator, bool_str);
            },
            .VAL_INT => {
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_int});
            },
            .VAL_DOUBLE => {
                if (std.math.isNan(value.as.num_double) or std.math.isInf(value.as.num_double)) {
                    return SerdeError.UnsupportedType;
                }
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.num_double});
            },
            .VAL_COMPLEX => {
                // Serialize as inline table
                try self.output.appendSlice(self.allocator, "{ real = ");
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.complex.r});
                try self.output.appendSlice(self.allocator, ", imag = ");
                try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value.as.complex.i});
                try self.output.appendSlice(self.allocator, " }");
            },
            .VAL_OBJ => {
                if (value.as.obj) |obj| {
                    try self.serializeObject(obj, options, context, inline_context);
                } else {
                    return SerdeError.UnsupportedType;
                }
            },
        }
    }

    fn serializeObject(
        self: *Self,
        obj: *Obj,
        options: SerializeOptions,
        context: *SerdeContext,
        inline_context: bool,
    ) SerdeError!void {
        _ = options;
        _ = context;

        switch (obj.type) {
            .OBJ_STRING => {
                const str_obj = @as(*ObjString, @ptrCast(@alignCast(obj)));
                try self.writeString(str_obj.chars);
            },
            .OBJ_LINKED_LIST => {
                try self.serializeArray(obj, inline_context);
            },
            .OBJ_FVECTOR => {
                const fvec = @as(*FloatVector, @ptrCast(@alignCast(obj)));
                try self.serializeFloatVector(fvec);
            },
            .OBJ_HASH_TABLE => {
                if (inline_context) {
                    try self.serializeInlineTable(obj);
                } else {
                    return SerdeError.UnsupportedType; // Regular tables can't be nested inline
                }
            },
            else => {
                return SerdeError.NotSupported;
            },
        }
    }

    fn writeString(self: *Self, str: []const u8) !void {
        try self.output.append(self.allocator, '"');
        try self.writeEscapedString(str);
        try self.output.append(self.allocator, '"');
    }

    fn writeEscapedString(self: *Self, str: []const u8) !void {
        for (str) |char| {
            switch (char) {
                '"' => try self.output.appendSlice(self.allocator, "\\\""),
                '\\' => try self.output.appendSlice(self.allocator, "\\\\"),
                '\n' => try self.output.appendSlice(self.allocator, "\\n"),
                '\r' => try self.output.appendSlice(self.allocator, "\\r"),
                '\t' => try self.output.appendSlice(self.allocator, "\\t"),
                0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F, 0x7F => {
                    try std.fmt.format(self.output.writer(self.allocator), "\\u{d:0>4}", .{char});
                },
                else => try self.output.append(self.allocator, char),
            }
        }
    }

    fn serializeArray(self: *Self, obj: *Obj, inline_context: bool) !void {
        _ = inline_context;
        const list = @as(*LinkedList, @ptrCast(@alignCast(obj)));

        try self.output.append(self.allocator, '[');

        var current = list.head;
        var first = true;

        while (current) |node| {
            if (!first) {
                try self.output.appendSlice(self.allocator, ", ");
            }
            first = false;

            // For now, just serialize as string representation
            switch (node.data.type) {
                .VAL_INT => {
                    try std.fmt.format(self.output.writer(self.allocator), "{d}", .{node.data.as.num_int});
                },
                .VAL_DOUBLE => {
                    try std.fmt.format(self.output.writer(self.allocator), "{d}", .{node.data.as.num_double});
                },
                .VAL_BOOL => {
                    const bool_str = if (node.data.as.boolean) "true" else "false";
                    try self.output.appendSlice(self.allocator, bool_str);
                },
                .VAL_OBJ => {
                    if (node.data.as.obj) |obj_ptr| {
                        if (obj_ptr.type == .OBJ_STRING) {
                            const str_obj = @as(*ObjString, @ptrCast(@alignCast(obj_ptr)));
                            try self.writeString(str_obj.chars);
                        } else {
                            try self.output.appendSlice(self.allocator, "\"[object]\"");
                        }
                    }
                },
                else => {
                    try self.output.appendSlice(self.allocator, "\"[value]\"");
                },
            }

            current = node.next;
        }

        try self.output.append(self.allocator, ']');
    }

    fn serializeFloatVector(self: *Self, fvec: *FloatVector) !void {
        try self.output.append(self.allocator, '[');

        for (fvec.data[0..fvec.size], 0..) |value, i| {
            if (i > 0) try self.output.appendSlice(self.allocator, ", ");
            try std.fmt.format(self.output.writer(self.allocator), "{d}", .{value});
        }

        try self.output.append(self.allocator, ']');
    }

    fn serializeInlineTable(self: *Self, obj: *Obj) !void {
        const hash_table = @as(*ObjHashTable, @ptrCast(@alignCast(obj)));

        try self.output.appendSlice(self.allocator, "{ ");

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

                const key = pair.key.as_string().chars;
                try self.writeKey(key);
                try self.output.appendSlice(self.allocator, " = ");

                // Simple value serialization for inline tables
                switch (pair.value.type) {
                    .VAL_INT => {
                        try std.fmt.format(self.output.writer(self.allocator), "{d}", .{pair.value.as.num_int});
                    },
                    .VAL_DOUBLE => {
                        try std.fmt.format(self.output.writer(self.allocator), "{d}", .{pair.value.as.num_double});
                    },
                    .VAL_BOOL => {
                        const bool_str = if (pair.value.as.boolean) "true" else "false";
                        try self.output.appendSlice(self.allocator, bool_str);
                    },
                    .VAL_OBJ => {
                        if (pair.value.as.obj) |obj_ptr| {
                            if (obj_ptr.type == .OBJ_STRING) {
                                const str_obj = @as(*ObjString, @ptrCast(@alignCast(obj_ptr)));
                                try self.writeString(str_obj.chars);
                            }
                        }
                    },
                    else => {},
                }
            }
            current = node.next;
        }

        try self.output.appendSlice(self.allocator, " }");
    }

    pub fn supportsType(self: *Self, value_type: ValueType) bool {
        _ = self;
        return switch (value_type) {
            .VAL_NIL => false, // TOML doesn't have null
            .VAL_BOOL, .VAL_INT, .VAL_DOUBLE, .VAL_COMPLEX, .VAL_OBJ => true,
        };
    }
};

/// TOML Deserializer implementation
pub const TomlDeserializer = struct {
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

        var parser = TomlParser.init(data, self.allocator) catch {
            return SerdeError.ParseError;
        };

        return parser.parseDocument() catch |err| {
            return switch (err) {
                error.UnterminatedString => SerdeError.ParseError,
                error.UnexpectedCharacter => SerdeError.ParseError,
                error.UnexpectedToken => SerdeError.ParseError,
                error.ExpectedKey => SerdeError.ParseError,
                error.ExpectedValue => SerdeError.ParseError,
                error.InvalidString => SerdeError.ParseError,
                error.InvalidInteger => SerdeError.ParseError,
                error.InvalidFloat => SerdeError.ParseError,
                error.InvalidUnicodeEscape => SerdeError.ParseError,
                error.NotATable => SerdeError.ParseError,
                error.KeyAlreadyExists => SerdeError.ParseError,
                error.OutOfMemory => SerdeError.OutOfMemory,
                else => SerdeError.ParseError,
            };
        };
    }

    pub fn canDeserialize(self: *Self, data: []const u8) bool {
        _ = self;

        // Basic TOML detection - look for key = value patterns
        var i: usize = 0;
        var found_equals = false;

        while (i < data.len) {
            const char = data[i];
            switch (char) {
                ' ', '\t', '\r', '\n' => {
                    i += 1;
                    continue;
                },
                '[' => {
                    // Table header - likely TOML
                    return true;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    // Could be a key
                    while (i < data.len) {
                        const key_char = data[i];
                        switch (key_char) {
                            'a'...'z', 'A'...'Z', '0'...'9', '_', '-' => i += 1,
                            ' ', '\t' => {
                                // Skip whitespace
                                while (i < data.len and (data[i] == ' ' or data[i] == '\t')) {
                                    i += 1;
                                }
                                break;
                            },
                            '=' => {
                                found_equals = true;
                                break;
                            },
                            else => return false,
                        }
                    }
                    if (found_equals) return true;
                    break;
                },
                '#' => {
                    // Comment - skip to end of line
                    while (i < data.len and data[i] != '\n') {
                        i += 1;
                    }
                },
                else => return false,
            }
            i += 1;
        }

        return found_equals;
    }
};

// Format detection function
fn detectTomlFormat(data: []const u8) bool {
    var deserializer = TomlDeserializer.init(data, std.heap.page_allocator);
    return deserializer.canDeserialize(data);
}

// High-level functions that integrate with the Serde registry
pub fn serializeToml(
    value: Value,
    options: SerializeOptions,
    allocator: std.mem.Allocator,
) SerdeError![]const u8 {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var serializer = TomlSerializer.init(allocator);
    defer serializer.deinit();

    return serializer.serialize(value, options, &context);
}

pub fn deserializeToml(
    data: []const u8,
    options: DeserializeOptions,
    allocator: std.mem.Allocator,
) SerdeError!Value {
    var context = SerdeContext.init(allocator);
    defer context.deinit(allocator);

    var deserializer = TomlDeserializer.init(data, allocator);
    return deserializer.deserialize(data, options, &context);
}

// Register TOML format with the global registry
pub fn registerTomlFormat(allocator: std.mem.Allocator) !void {
    const registry = serde.getGlobalRegistry(allocator);
    const extensions = [_][]const u8{".toml"};

    try registry.registerFormat(
        "toml",
        &extensions,
        serializeToml,
        deserializeToml,
        detectTomlFormat,
    );
}
