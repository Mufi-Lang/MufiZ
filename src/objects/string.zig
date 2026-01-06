const std = @import("std");

const debug_opts = @import("debug");

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

// Global empty string singleton to prevent repeated allocations
var empty_string_singleton: ?*String = null;

/// String struct with bounded methods, following the FloatVector/LinkedList pattern
pub const String = struct {
    obj: Obj,
    length: usize,
    chars: []u8,
    hash: u64,
    // Track which allocator was used for the chars to enable safe freeing
    chars_allocator_type: AllocatorType,

    const Self = *@This();

    pub const AllocatorType = enum {
        GPA, // General Purpose Allocator (main allocator)
        Arena, // VM Arena Allocator (for literals/constants)
    };

    /// Creates a new string by taking ownership of the given character buffer
    /// The allocator parameter specifies which allocator was used to allocate chars
    pub fn takeWithAllocator(chars: []u8, length: usize, allocator: std.mem.Allocator) Self {
        const hash = String.hashChars(chars, length);

        // Check if string already exists in intern table
        if (findString(chars, length, hash)) |interned| {
            // Now we can safely free the incoming buffer with the correct allocator
            // since we're tracking allocator types properly
            if (chars.len > 0) {
                // Free the buffer with the provided allocator
                mem_utils.free(allocator, chars);
            }
            return interned;
        }

        // Determine allocator type
        const allocator_type = if (isSameAllocator(allocator, mem_utils.getAllocator()))
            AllocatorType.GPA
        else
            AllocatorType.Arena;

        return allocateString(.{
            .chars = chars,
            .length = length,
            .hash = hash,
            .allocator_type = allocator_type,
        });
    }

    /// Creates a new string by taking ownership of the given character buffer
    /// Uses the default allocator - kept for backward compatibility
    pub fn take(chars: []u8, length: usize) Self {
        const allocator = mem_utils.getAllocator();
        return takeWithAllocator(chars, length, allocator);
    }

    /// Creates a new string by copying the given characters
    pub fn copy(chars: []const u8, length: usize) Self {
        if (length == 0) {
            // Return singleton empty string if it exists
            if (empty_string_singleton) |empty| {
                return empty;
            }

            // Check if empty string already exists in intern table first
            const hash = hashChars(&[_]u8{}, 0);
            if (findString(&[_]u8{}, 0, hash)) |interned| {
                empty_string_singleton = interned;
                return interned;
            }

            // Only create new empty string if none exists - use a static buffer to avoid allocation
            const empty_chars: []u8 = &[_]u8{}; // Static empty slice
            const empty = allocateString(.{
                .chars = empty_chars,
                .length = 0,
                .hash = hash,
                .allocator_type = AllocatorType.GPA,
            });
            empty_string_singleton = empty;
            return empty;
        }

        const hash = hashChars(chars, length);

        // Check if string already exists in intern table
        if (findString(chars, length, hash)) |interned| {
            return interned;
        }

        // Allocate memory for the new string
        const allocator = mem_utils.getAllocator();
        const heapChars_slice = mem_utils.alloc(allocator, u8, length + 1) catch {
            @panic("Failed to allocate memory for string");
        };
        @memcpy(heapChars_slice[0..length], chars[0..length]);
        heapChars_slice[length] = 0; // Null terminate

        return allocateString(.{
            .chars = heapChars_slice[0..length],
            .length = length,
            .hash = hash,
            .allocator_type = AllocatorType.GPA,
        });
    }

    /// Creates a new string using arena allocation for literals/constants
    pub fn copyLiteral(chars: []const u8, length: usize) Self {
        if (length == 0) {
            // Return existing empty string singleton if available
            if (empty_string_singleton) |empty| {
                return empty;
            }

            // Check if empty string already exists in intern table first
            const hash = hashChars(&[_]u8{}, 0);
            if (findString(&[_]u8{}, 0, hash)) |interned| {
                empty_string_singleton = interned;
                return interned;
            }

            // Only create new empty string if none exists - use a static buffer to avoid allocation
            const empty_chars: []u8 = &[_]u8{}; // Static empty slice
            const empty = allocateString(.{
                .chars = empty_chars,
                .length = 0,
                .hash = hash,
                .allocator_type = AllocatorType.Arena,
            });
            empty_string_singleton = empty;
            return empty;
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
            .allocator_type = AllocatorType.Arena,
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
        const allocator = mem_utils.getAllocator();
        const chars_slice = mem_utils.alloc(allocator, u8, newLength + 1) catch @panic("Failed to allocate string for concat");

        @memcpy(chars_slice[0..self.length], self.chars[0..self.length]);
        @memcpy(chars_slice[self.length..newLength], other.chars[0..other.length]);
        chars_slice[newLength] = 0; // Null terminate

        return String.take(chars_slice[0..newLength], newLength);
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
        const allocator = mem_utils.getAllocator();
        const chars_slice = mem_utils.alloc(allocator, u8, self.length + 1) catch @panic("Failed to allocate string for toLower");

        for (0..self.length) |i| {
            chars_slice[i] = std.ascii.toLower(self.chars[i]);
        }
        chars_slice[self.length] = 0; // Null terminate

        return String.take(chars_slice[0..self.length], self.length);
    }

    /// Converts string to uppercase (creates a new string)
    pub fn toUpper(self: Self) Self {
        const allocator = mem_utils.getAllocator();
        const chars_slice = mem_utils.alloc(allocator, u8, self.length + 1) catch @panic("Failed to allocate string for toUpper");

        for (0..self.length) |i| {
            chars_slice[i] = std.ascii.toUpper(self.chars[i]);
        }
        chars_slice[self.length] = 0; // Null terminate

        return String.take(chars_slice[0..self.length], self.length);
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
        const allocator = mem_utils.getAllocator();
        const chars_slice = mem_utils.alloc(allocator, u8, newLength + 1) catch @panic("Failed to allocate string for replace");

        // Build new string
        var srcPos: usize = 0;
        var dstPos: usize = 0;

        while (srcPos <= self.length - needle.length) {
            if (std.mem.eql(u8, self.chars[srcPos .. srcPos + needle.length], needle.chars[0..needle.length])) {
                @memcpy(chars_slice[dstPos .. dstPos + replacement.length], replacement.chars[0..replacement.length]);
                dstPos += replacement.length;
                srcPos += needle.length;
            } else {
                chars_slice[dstPos] = self.chars[srcPos];
                dstPos += 1;
                srcPos += 1;
            }
        }

        // Copy remaining characters
        while (srcPos < self.length) {
            chars_slice[dstPos] = self.chars[srcPos];
            dstPos += 1;
            srcPos += 1;
        }

        chars_slice[newLength] = 0; // Null terminate
        return String.take(chars_slice[0..newLength], newLength);
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

    // ============================================================================
    // SIMD-Optimized String Operations
    // ============================================================================
    // The following methods use SIMD (Single Instruction Multiple Data) 
    // instructions to process multiple bytes in parallel for improved performance.

    const Vec16 = @Vector(16, u8);

    /// SIMD-optimized substring search
    /// Returns the index of the first occurrence of needle in haystack, or null if not found
    pub fn findSIMD(haystack: []const u8, needle: []const u8) ?usize {
        if (needle.len == 0) return 0;
        if (haystack.len < needle.len) return null;

        // For small needles, use optimized SIMD search
        if (needle.len == 1) {
            return findCharSIMD(haystack, needle[0]);
        }

        // For larger needles, use first character search + verification
        const first_char = needle[0];
        var pos: usize = 0;

        while (pos <= haystack.len - needle.len) {
            // Find next occurrence of first character using SIMD
            if (findCharSIMDFrom(haystack[pos..], first_char)) |offset| {
                const candidate_pos = pos + offset;

                // Verify full match using SIMD comparison
                if (candidate_pos + needle.len <= haystack.len) {
                    if (equalsSIMD(haystack[candidate_pos .. candidate_pos + needle.len], needle)) {
                        return candidate_pos;
                    }
                }
                pos = candidate_pos + 1;
            } else {
                break;
            }
        }

        return null;
    }

    /// SIMD-optimized single character search
    pub fn findCharSIMD(haystack: []const u8, needle_char: u8) ?usize {
        const needle_vec: Vec16 = @splat(needle_char);

        var i: usize = 0;
        const vec_iterations = haystack.len / 16;

        // Process 16 bytes at a time using unaligned reads
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;

            // Use unaligned reads by copying bytes into array first
            var haystack_bytes: [16]u8 = undefined;
            @memcpy(&haystack_bytes, haystack[offset .. offset + 16]);
            const haystack_vec: Vec16 = haystack_bytes;

            // Compare all 16 bytes at once
            const comparison = haystack_vec == needle_vec;

            // Check if any byte matched
            if (@reduce(.Or, comparison)) {
                // Find the exact position
                for (0..16) |j| {
                    if (comparison[j]) {
                        return offset + j;
                    }
                }
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..haystack.len) |j| {
            if (haystack[j] == needle_char) {
                return j;
            }
        }

        return null;
    }

    /// SIMD-optimized character search starting from a specific position
    pub fn findCharSIMDFrom(haystack: []const u8, needle_char: u8) ?usize {
        return findCharSIMD(haystack, needle_char);
    }

    /// SIMD-optimized string equality check
    pub fn equalsSIMD(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        if (a.len == 0) return true;

        const vec_iterations = a.len / 16;

        var i: usize = 0;

        // Compare 16 bytes at a time using unaligned reads
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;

            // Use unaligned reads
            var bytes_a: [16]u8 = undefined;
            var bytes_b: [16]u8 = undefined;
            @memcpy(&bytes_a, a[offset .. offset + 16]);
            @memcpy(&bytes_b, b[offset .. offset + 16]);
            const vec_a: Vec16 = bytes_a;
            const vec_b: Vec16 = bytes_b;

            const comparison = vec_a == vec_b;

            // If any byte is different, strings are not equal
            if (!@reduce(.And, comparison)) {
                return false;
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..a.len) |j| {
            if (a[j] != b[j]) {
                return false;
            }
        }

        return true;
    }

    /// SIMD-optimized string comparison (lexicographic)
    pub fn compareSIMD(a: []const u8, b: []const u8) i32 {
        const min_len = @min(a.len, b.len);
        const vec_iterations = min_len / 16;

        var i: usize = 0;

        // Compare 16 bytes at a time using unaligned reads
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;

            // Use unaligned reads
            var bytes_a: [16]u8 = undefined;
            var bytes_b: [16]u8 = undefined;
            @memcpy(&bytes_a, a[offset .. offset + 16]);
            @memcpy(&bytes_b, b[offset .. offset + 16]);
            const vec_a: Vec16 = bytes_a;
            const vec_b: Vec16 = bytes_b;

            const comparison = vec_a == vec_b;

            // If any bytes are different, find the first difference
            if (!@reduce(.And, comparison)) {
                for (0..16) |j| {
                    if (!comparison[j]) {
                        const idx = offset + j;
                        return if (a[idx] < b[idx]) -1 else 1;
                    }
                }
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..min_len) |j| {
            if (a[j] != b[j]) {
                return if (a[j] < b[j]) -1 else 1;
            }
        }

        // All compared bytes are equal, check lengths
        if (a.len == b.len) return 0;
        return if (a.len < b.len) -1 else 1;
    }

    /// SIMD-optimized case-insensitive string comparison
    pub fn compareIgnoreCaseSIMD(a: []const u8, b: []const u8) i32 {
        const min_len = @min(a.len, b.len);
        const vec_iterations = min_len / 16;

        // ASCII case conversion masks
        const lower_mask: Vec16 = @splat(0x20); // bit to set for lowercase
        const alpha_mask_lower: Vec16 = @splat('A');
        const alpha_mask_upper: Vec16 = @splat('Z');

        var i: usize = 0;

        // Compare 16 bytes at a time with case conversion using unaligned reads
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;

            // Use unaligned reads
            var bytes_a: [16]u8 = undefined;
            var bytes_b: [16]u8 = undefined;
            @memcpy(&bytes_a, a[offset .. offset + 16]);
            @memcpy(&bytes_b, b[offset .. offset + 16]);
            var vec_a: Vec16 = bytes_a;
            var vec_b: Vec16 = bytes_b;

            // Convert to lowercase using SIMD
            const is_upper_a = (vec_a >= alpha_mask_lower) & (vec_a <= alpha_mask_upper);
            const is_upper_b = (vec_b >= alpha_mask_lower) & (vec_b <= alpha_mask_upper);

            vec_a = vec_a | @select(u8, is_upper_a, lower_mask, @as(Vec16, @splat(0)));
            vec_b = vec_b | @select(u8, is_upper_b, lower_mask, @as(Vec16, @splat(0)));

            const comparison = vec_a == vec_b;

            // If any bytes are different, find the first difference
            if (!@reduce(.And, comparison)) {
                for (0..16) |j| {
                    if (!comparison[j]) {
                        return if (vec_a[j] < vec_b[j]) -1 else 1;
                    }
                }
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..min_len) |j| {
            const char_a = std.ascii.toLower(a[j]);
            const char_b = std.ascii.toLower(b[j]);
            if (char_a != char_b) {
                return if (char_a < char_b) -1 else 1;
            }
        }

        // All compared bytes are equal, check lengths
        if (a.len == b.len) return 0;
        return if (a.len < b.len) -1 else 1;
    }

    /// SIMD-optimized string to lowercase conversion
    pub fn toLowerSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len) return;

        const vec_iterations = input.len / 16;

        // ASCII case conversion masks
        const lower_mask: Vec16 = @splat(0x20);
        const alpha_mask_lower: Vec16 = @splat('A');
        const alpha_mask_upper: Vec16 = @splat('Z');

        var i: usize = 0;

        // Process 16 bytes at a time
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;
            if (offset + 16 <= input.len) {
                // Use unaligned reads
                var input_bytes: [16]u8 = undefined;
                @memcpy(&input_bytes, input[offset .. offset + 16]);
                const input_vec: Vec16 = input_bytes;

                // Check which characters are uppercase letters
                const is_upper = (input_vec >= alpha_mask_lower) & (input_vec <= alpha_mask_upper);

                // Convert to lowercase by setting the 0x20 bit for uppercase letters
                const output_vec = input_vec | @select(u8, is_upper, lower_mask, @as(Vec16, @splat(0)));

                // Copy result back
                const result_bytes: [16]u8 = output_vec;
                @memcpy(output[offset .. offset + 16], &result_bytes);
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..input.len) |j| {
            output[j] = std.ascii.toLower(input[j]);
        }
    }

    /// SIMD-optimized string to uppercase conversion
    pub fn toUpperSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len) return;

        const vec_iterations = input.len / 16;

        // ASCII case conversion masks
        const upper_mask: Vec16 = @splat(0xDF); // mask to clear the 0x20 bit
        const alpha_mask_lower: Vec16 = @splat('a');
        const alpha_mask_upper: Vec16 = @splat('z');

        var i: usize = 0;

        // Process 16 bytes at a time
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;
            if (offset + 16 <= input.len) {
                // Use unaligned reads
                var input_bytes: [16]u8 = undefined;
                @memcpy(&input_bytes, input[offset .. offset + 16]);
                const input_vec: Vec16 = input_bytes;

                // Check which characters are lowercase letters
                const is_lower = (input_vec >= alpha_mask_lower) & (input_vec <= alpha_mask_upper);

                // Convert to uppercase by clearing the 0x20 bit for lowercase letters
                const output_vec = @select(u8, is_lower, input_vec & upper_mask, input_vec);

                // Copy result back
                const result_bytes: [16]u8 = output_vec;
                @memcpy(output[offset .. offset + 16], &result_bytes);
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..input.len) |j| {
            output[j] = std.ascii.toUpper(input[j]);
        }
    }

    /// SIMD-optimized whitespace trimming
    pub fn trimWhitespaceSIMD(input: []const u8) []const u8 {
        if (input.len == 0) return input;

        // Find start of non-whitespace
        var start: usize = 0;
        while (start < input.len and std.ascii.isWhitespace(input[start])) {
            start += 1;
        }

        if (start == input.len) return input[0..0]; // All whitespace

        // Find end of non-whitespace
        var end: usize = input.len;
        while (end > start and std.ascii.isWhitespace(input[end - 1])) {
            end -= 1;
        }

        return input[start..end];
    }

    /// SIMD-optimized character counting
    pub fn countCharSIMD(haystack: []const u8, needle_char: u8) usize {
        const needle_vec: Vec16 = @splat(needle_char);

        var count: usize = 0;
        var i: usize = 0;
        const vec_iterations = haystack.len / 16;

        // Process 16 bytes at a time using unaligned reads
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 16;

            // Use unaligned reads
            var haystack_bytes: [16]u8 = undefined;
            @memcpy(&haystack_bytes, haystack[offset .. offset + 16]);
            const haystack_vec: Vec16 = haystack_bytes;

            // Compare all 16 bytes at once
            const comparison = haystack_vec == needle_vec;

            // Count matches using horizontal add
            for (0..16) |j| {
                if (comparison[j]) count += 1;
            }
        }

        // Handle remaining bytes
        const remaining_start = vec_iterations * 16;
        for (remaining_start..haystack.len) |j| {
            if (haystack[j] == needle_char) {
                count += 1;
            }
        }

        return count;
    }

    /// SIMD-optimized string reverse
    pub fn reverseSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len or input.len == 0) return;

        const len = input.len;

        // For strings shorter than 32 bytes, use simple approach
        if (len < 32) {
            for (0..len) |i| {
                output[i] = input[len - 1 - i];
            }
            return;
        }

        // Process from both ends toward the middle
        var front: usize = 0;
        var back: usize = len;

        // Process 16-byte chunks from both ends using unaligned reads
        while (back - front >= 32) {
            // Load from front and back using unaligned reads
            var front_bytes: [16]u8 = undefined;
            var back_bytes: [16]u8 = undefined;
            @memcpy(&front_bytes, input[front .. front + 16]);
            @memcpy(&back_bytes, input[back - 16 .. back]);
            const front_vec: Vec16 = front_bytes;
            const back_vec: Vec16 = back_bytes;

            // Reverse the vectors and store them swapped
            const reversed_front = reverseVec16(front_vec);
            const reversed_back = reverseVec16(back_vec);

            // Copy results back
            const reversed_front_bytes: [16]u8 = reversed_front;
            const reversed_back_bytes: [16]u8 = reversed_back;
            @memcpy(output[back - 16 .. back], &reversed_front_bytes);
            @memcpy(output[front .. front + 16], &reversed_back_bytes);

            front += 16;
            back -= 16;
        }

        // Handle remaining bytes in the middle
        while (front < back) {
            back -= 1;
            output[len - 1 - front] = input[front];
            output[len - 1 - back] = input[back];
            front += 1;
        }
    }

    /// Helper function to reverse a 16-byte vector
    fn reverseVec16(vec: @Vector(16, u8)) @Vector(16, u8) {
        return @Vector(16, u8){
            vec[15], vec[14], vec[13], vec[12],
            vec[11], vec[10], vec[9],  vec[8],
            vec[7],  vec[6],  vec[5],  vec[4],
            vec[3],  vec[2],  vec[1],  vec[0],
        };
    }
};

// Parameters for allocating a string
const AllocStringParams = struct {
    chars: []u8,
    length: usize,
    hash: u64,
    allocator_type: String.AllocatorType,
};

// Allocates a new string object
fn allocateString(params: AllocStringParams) *String {
    const string = @as(*String, @ptrCast(@alignCast(allocateObject(@sizeOf(String), .OBJ_STRING))));
    string.length = params.length;
    string.chars = params.chars;
    string.hash = params.hash;
    string.chars_allocator_type = params.allocator_type;

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

// Helper function to check if an allocator is the main GPA allocator
fn isMainAllocator(allocator: std.mem.Allocator, main_allocator: std.mem.Allocator) bool {
    // Compare vtable pointers - main allocator should have consistent vtable
    return @intFromPtr(allocator.vtable) == @intFromPtr(main_allocator.vtable);
}

// Helper function to safely check if two allocators are the same
fn isSameAllocator(a: std.mem.Allocator, b: std.mem.Allocator) bool {
    // Compare both the function pointer and the context pointer
    return (@intFromPtr(a.ptr) == @intFromPtr(b.ptr)) and
        (@intFromPtr(a.vtable) == @intFromPtr(b.vtable));
}
