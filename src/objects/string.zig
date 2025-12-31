const std = @import("std");

const debug_opts = @import("debug");

const reallocate = @import("../memory.zig").reallocate;
const mem_utils = @import("../mem_utils.zig");
const string_hash = @import("../string_hash.zig");
const allocateObject = @import("../object.zig").allocateObject;
const LinkedList = @import("../object.zig").LinkedList;
const Table = @import("../table.zig").Table;
const tableSet = @import("../table.zig").tableSet;
const Value = @import("../value.zig").Value;
const vm_h = @import("../vm.zig");
const push = vm_h.push;
const pop = vm_h.pop;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

/// String struct with bounded methods, following the FloatVector/LinkedList pattern
pub const String = struct {
    obj: Obj,
    length: usize,
    chars: []u8,
    hash: u64,

    const Self = *@This();

    /// Creates a new string by taking ownership of the given character buffer
    pub fn take(chars: []u8, length: usize) Self {
        const hash = String.hashChars(chars, length);

        // Check if string already exists in intern table
        if (findString(chars, length, hash)) |interned| {
            _ = reallocate(@as(?*anyopaque, @ptrCast(chars.ptr)), length, 0);
            return interned;
        }

        return allocateString(.{
            .chars = chars,
            .length = length,
            .hash = hash,
        });
    }

    /// Creates a new string by copying the given characters
    pub fn copy(chars: []const u8, length: usize) Self {
        if (length == 0) {
            // Return the empty string singleton
            const emptyChars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, 1))));
            emptyChars[0] = 0; // Null terminate
            return allocateString(.{
                .chars = emptyChars[0..0], // Empty slice
                .length = 0,
                .hash = hashChars(&[_]u8{}, 0),
            });
        }

        const hash = hashChars(chars, length);

        // Check if string already exists in intern table
        if (findString(chars, length, hash)) |interned| {
            return interned;
        }

        // Allocate memory for the new string
        const heapCharsPtr = reallocate(null, 0, length + 1);
        if (heapCharsPtr == null) {
            // This shouldn't happen since reallocate exits on failure, but just in case
            @panic("Failed to allocate memory for string");
        }
        const heapChars = @as([*]u8, @ptrCast(@alignCast(heapCharsPtr)));
        @memcpy(heapChars[0..length], chars[0..length]);
        heapChars[length] = 0; // Null terminate

        return allocateString(.{
            .chars = heapChars[0..length],
            .length = length,
            .hash = hash,
        });
    }

    /// Creates a new string using arena allocation for literals/constants
    pub fn copyLiteral(chars: []const u8, length: usize) Self {
        if (length == 0) {
            // Return the empty string singleton
            const vm_allocator = mem_utils.getVMArenaAllocator();
            const emptyChars = vm_allocator.alloc(u8, 1) catch @panic("Failed to allocate empty string");
            emptyChars[0] = 0; // Null terminate
            return allocateString(.{
                .chars = emptyChars[0..0], // Empty slice
                .length = 0,
                .hash = hashChars(&[_]u8{}, 0),
            });
        }

        const hash = hashChars(chars, length);

        // Check if string already exists in intern table
        if (findString(chars, length, hash)) |interned| {
            return interned;
        }

        // Use arena allocation for literals/constants
        const vm_allocator = mem_utils.getVMArenaAllocator();
        const heapChars = vm_allocator.alloc(u8, length + 1) catch @panic("Failed to allocate literal string");
        @memcpy(heapChars[0..length], chars[0..length]);
        heapChars[length] = 0; // Null terminate

        return allocateString(.{
            .chars = heapChars[0..length],
            .length = length,
            .hash = hash,
        });
    }

    /// Creates a string from a null-terminated C string
    pub fn fromCString(cstr: [*:0]const u8) Self {
        const length = std.mem.len(cstr);
        return String.copy(@as([]const u8, @ptrCast(cstr[0..length])), length);
    }

    /// Creates a string from a Zig string literal
    pub fn fromLiteral(str: []const u8) Self {
        return String.copy(str, str.len);
    }

    /// Concatenates two strings
    pub fn concat(self: Self, other: Self) Self {
        const newLength = self.length + other.length;
        const chars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, newLength))));

        @memcpy(chars[0..self.length], self.chars[0..self.length]);
        @memcpy(chars[self.length..newLength], other.chars[0..other.length]);

        return String.take(chars[0..newLength], newLength);
    }

    /// Returns a substring (creates a new string)
    pub fn substring(self: Self, start: usize, end: usize) Self {
        if (start >= self.length) return String.copy(&[_]u8{}, 0);

        const actualEnd = @min(end, self.length);
        const actualStart = @min(start, actualEnd);
        const length = actualEnd - actualStart;

        return String.copy(self.chars[actualStart..actualEnd], length);
    }

    /// Checks if this string equals another string
    pub fn equals(self: Self, other: Self) bool {
        if (self == other) return true; // Same object
        if (self.length != other.length) return false;
        if (self.hash != other.hash) return false;
        return std.mem.eql(u8, self.chars[0..self.length], other.chars[0..other.length]);
    }

    /// Checks if this string equals a raw string
    pub fn equalsRaw(self: Self, chars: []const u8) bool {
        if (self.length != chars.len) return false;
        return std.mem.eql(u8, self.chars[0..self.length], chars);
    }

    /// Checks if this string starts with another string
    pub fn startsWith(self: Self, prefix: Self) bool {
        if (prefix.length > self.length) return false;
        return std.mem.eql(u8, self.chars[0..prefix.length], prefix.chars[0..prefix.length]);
    }

    /// Checks if this string ends with another string
    pub fn endsWith(self: Self, suffix: Self) bool {
        if (suffix.length > self.length) return false;
        const start = self.length - suffix.length;
        return std.mem.eql(u8, self.chars[start..self.length], suffix.chars[0..suffix.length]);
    }

    /// Finds the index of a substring (-1 if not found)
    pub fn indexOf(self: Self, needle: Self) i32 {
        if (needle.length > self.length) return -1;

        const maxPos = self.length - needle.length;
        for (0..maxPos + 1) |i| {
            if (std.mem.eql(u8, self.chars[i .. i + needle.length], needle.chars[0..needle.length])) {
                return @intCast(i);
            }
        }

        return -1;
    }

    /// Checks if string contains a substring
    pub fn contains(self: Self, needle: Self) bool {
        return self.indexOf(needle) != -1;
    }

    /// Converts string to lowercase (creates a new string)
    pub fn toLower(self: Self) Self {
        const chars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, self.length))));

        for (0..self.length) |i| {
            chars[i] = std.ascii.toLower(self.chars[i]);
        }

        return String.take(chars[0..self.length], self.length);
    }

    /// Converts string to uppercase (creates a new string)
    pub fn toUpper(self: Self) Self {
        const chars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, self.length))));

        for (0..self.length) |i| {
            chars[i] = std.ascii.toUpper(self.chars[i]);
        }

        return String.take(chars[0..self.length], self.length);
    }

    /// Trims whitespace from both ends (creates a new string)
    pub fn trim(self: Self) Self {
        var start: usize = 0;
        var end: usize = self.length;

        // Trim from start
        while (start < self.length and std.ascii.isWhitespace(self.chars[start])) {
            start += 1;
        }

        // Trim from end
        while (end > start and std.ascii.isWhitespace(self.chars[end - 1])) {
            end -= 1;
        }

        if (start == 0 and end == self.length) return self;
        return self.substring(start, end);
    }

    /// Splits string by a delimiter (returns a LinkedList of strings)
    pub fn split(self: Self, delimiter: Self) *LinkedList {
        const list = LinkedList.init();

        if (delimiter.length == 0) {
            list.push(Value.init_obj(@ptrCast(self)));
            return list;
        }

        var start: usize = 0;
        var pos: usize = 0;

        while (pos <= self.length - delimiter.length) {
            if (std.mem.eql(u8, self.chars[pos .. pos + delimiter.length], delimiter.chars[0..delimiter.length])) {
                const part = self.substring(start, pos);
                list.push(Value.init_obj(@ptrCast(part)));
                start = pos + delimiter.length;
                pos = start;
            } else {
                pos += 1;
            }
        }

        // Add the last part
        const lastPart = self.substring(start, self.length);
        list.push(Value.init_obj(@ptrCast(lastPart)));

        return list;
    }

    /// Replaces all occurrences of a substring (creates a new string)
    pub fn replace(self: Self, needle: Self, replacement: Self) Self {
        if (needle.length == 0) return self;

        // Count occurrences
        var count: usize = 0;
        var pos: usize = 0;
        while (pos <= self.length - needle.length) {
            if (std.mem.eql(u8, self.chars[pos .. pos + needle.length], needle.chars[0..needle.length])) {
                count += 1;
                pos += needle.length;
            } else {
                pos += 1;
            }
        }

        if (count == 0) return self;

        // Calculate new length
        const newLength = self.length - (count * needle.length) + (count * replacement.length);
        const chars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, newLength))));

        // Build new string
        var srcPos: usize = 0;
        var dstPos: usize = 0;

        while (srcPos <= self.length - needle.length) {
            if (std.mem.eql(u8, self.chars[srcPos .. srcPos + needle.length], needle.chars[0..needle.length])) {
                @memcpy(chars[dstPos .. dstPos + replacement.length], replacement.chars[0..replacement.length]);
                dstPos += replacement.length;
                srcPos += needle.length;
            } else {
                chars[dstPos] = self.chars[srcPos];
                dstPos += 1;
                srcPos += 1;
            }
        }

        // Copy remaining characters
        while (srcPos < self.length) {
            chars[dstPos] = self.chars[srcPos];
            dstPos += 1;
            srcPos += 1;
        }

        return String.take(chars[0..newLength], newLength);
    }

    /// Gets a character at the given index
    pub fn charAt(self: Self, index: usize) ?u8 {
        if (index >= self.length) return null;
        return self.chars[index];
    }

    /// Converts string to integer
    pub fn toInt(self: Self) ?i64 {
        return std.fmt.parseInt(i64, self.chars[0..self.length], 10) catch null;
    }

    /// Converts string to float
    pub fn toFloat(self: Self) ?f64 {
        return std.fmt.parseFloat(f64, self.chars[0..self.length]) catch null;
    }

    /// Prints the string
    pub fn print(self: Self) void {
        for (0..self.length) |i| {
            std.debug.print("{c}", .{self.chars[i]});
        }
    }

    /// Prints the string with quotes (for debugging)
    pub fn printQuoted(self: Self) void {
        std.debug.print("\"", .{});
        for (0..self.length) |i| {
            const c = self.chars[i];
            switch (c) {
                '\n' => std.debug.print("\\n", .{}),
                '\r' => std.debug.print("\\r", .{}),
                '\t' => std.debug.print("\\t", .{}),
                '\\' => std.debug.print("\\\\", .{}),
                '"' => std.debug.print("\\\"", .{}),
                else => std.debug.print("{c}", .{c}),
            }
        }
        std.debug.print("\"", .{});
    }

    /// Hashes a string of characters using optimized hash functions
    /// Uses the string_hash module for best performance and distribution
    pub fn hashChars(chars: []const u8, length: usize) u64 {
        if (length == 0) return 0;

        // Use the optimized string hash utilities
        // Auto-selects the best hash algorithm based on string length
        return string_hash.StringHash.hashFast(chars[0..length]);
    }

    /// Iterator for characters
    pub fn iterator(self: Self) CharIterator {
        return CharIterator{
            .string = self,
            .index = 0,
        };
    }

    pub const CharIterator = struct {
        string: Self,
        index: usize,

        pub fn next(self: *CharIterator) ?u8 {
            if (self.index >= self.string.length) return null;
            const char = self.string.chars[self.index];
            self.index += 1;
            return char;
        }
    };
};

// Parameters for allocating a string
const AllocStringParams = struct {
    chars: []u8,
    length: usize,
    hash: u64,
};

// Allocates a new string object
fn allocateString(params: AllocStringParams) *String {
    const string = @as(*String, @ptrCast(@alignCast(allocateObject(@sizeOf(String), .OBJ_STRING))));
    string.length = params.length;
    string.chars = params.chars;
    string.hash = params.hash;

    // Intern the string
    push(Value.init_obj(@ptrCast(string)));
    _ = tableSet(&vm.strings, string, Value.init_nil());
    _ = pop();

    return string;
}

// Finds a string in the intern table
fn findString(chars: []const u8, length: usize, hash: u64) ?*String {
    const tableFindString = @import("../table.zig").tableFindString;

    if (vm_h.vm.strings.count == 0) return null;
    return tableFindString(&vm_h.vm.strings, chars.ptr, length, hash);
}

// VM imports for string interning
const vm = &vm_h.vm;
