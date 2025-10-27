const std = @import("std");

const mem_utils = @import("mem_utils.zig");

// SIMD-optimized string operations for high-performance text processing
pub const SIMDString = struct {

    // SIMD-optimized string search using Boyer-Moore-like algorithm with SIMD acceleration
    pub fn findSIMD(haystack: []const u8, needle: []const u8) ?usize {
        if (needle.len == 0) return 0;
        if (haystack.len < needle.len) return null;

        const Vec16 = @Vector(16, u8);
        _ = Vec16; // autofix

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

    // SIMD-optimized single character search
    pub fn findCharSIMD(haystack: []const u8, needle_char: u8) ?usize {
        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized character search starting from a specific position
    pub fn findCharSIMDFrom(haystack: []const u8, needle_char: u8) ?usize {
        return findCharSIMD(haystack, needle_char);
    }

    // SIMD-optimized string equality check
    pub fn equalsSIMD(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        if (a.len == 0) return true;

        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized string comparison (lexicographic)
    pub fn compareSIMD(a: []const u8, b: []const u8) i32 {
        const min_len = @min(a.len, b.len);
        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized case-insensitive string comparison
    pub fn compareIgnoreCaseSIMD(a: []const u8, b: []const u8) i32 {
        const min_len = @min(a.len, b.len);
        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized string to lowercase conversion
    pub fn toLowerSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len) return;

        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized string to uppercase conversion
    pub fn toUpperSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len) return;

        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized whitespace trimming
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

    // SIMD-optimized character counting
    pub fn countCharSIMD(haystack: []const u8, needle_char: u8) usize {
        const Vec16 = @Vector(16, u8);
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

    // SIMD-optimized string reverse
    pub fn reverseSIMD(input: []const u8, output: []u8) void {
        if (input.len != output.len or input.len == 0) return;

        const Vec16 = @Vector(16, u8);
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

    // Helper function to reverse a 16-byte vector
    fn reverseVec16(vec: @Vector(16, u8)) @Vector(16, u8) {
        return @Vector(16, u8){
            vec[15], vec[14], vec[13], vec[12],
            vec[11], vec[10], vec[9],  vec[8],
            vec[7],  vec[6],  vec[5],  vec[4],
            vec[3],  vec[2],  vec[1],  vec[0],
        };
    }
};

// Test functions for SIMD string operations
test "SIMD string search" {
    const haystack = "Hello, world! This is a test string.";
    const needle = "world";

    const result = SIMDString.findSIMD(haystack, needle);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == 7);
}

test "SIMD character search" {
    const haystack = "Hello, world!";
    const needle = 'o';

    const result = SIMDString.findCharSIMD(haystack, needle);
    try std.testing.expect(result != null);
    try std.testing.expect(result.? == 4);
}

test "SIMD string equality" {
    const a = "Hello, world!";
    const b = "Hello, world!";
    const c = "Hello, World!";

    try std.testing.expect(SIMDString.equalsSIMD(a, b));
    try std.testing.expect(!SIMDString.equalsSIMD(a, c));
}

test "SIMD string comparison" {
    const a = "apple";
    const b = "banana";
    const c = "apple";

    try std.testing.expect(SIMDString.compareSIMD(a, b) < 0);
    try std.testing.expect(SIMDString.compareSIMD(b, a) > 0);
    try std.testing.expect(SIMDString.compareSIMD(a, c) == 0);
}

test "SIMD case conversion" {
    const input = "Hello, World! 123";
    var lower_output: [input.len]u8 = undefined;
    var upper_output: [input.len]u8 = undefined;

    SIMDString.toLowerSIMD(input, &lower_output);
    SIMDString.toUpperSIMD(input, &upper_output);

    try std.testing.expectEqualStrings("hello, world! 123", &lower_output);
    try std.testing.expectEqualStrings("HELLO, WORLD! 123", &upper_output);
}
