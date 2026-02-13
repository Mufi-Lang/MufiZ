const std = @import("std");

const keywords = [_][]const u8{
    "and",  "as",    "break",  "case",  "class", "const",   "continue",
    "each", "else",  "end",    "false", "for",   "foreach", "from",
    "fun",  "if",    "import", "in",    "item",  "let",     "nil",
    "or",   "print", "return", "self",  "super", "switch",  "true",
    "var",  "while",
};

const HASH_SIZE = 64;

fn perfectHash(str: []const u8, m1: u32, m2: u32, m3: u32, m4: u32) u8 {
    if (str.len == 0) return 0;
    const len = str.len;
    const first = str[0];
    const last = str[len - 1];
    const middle = if (len > 2) str[len / 2] else first;

    const hash = (@as(u32, first) *% m1) +%
        (@as(u32, last) *% m2) +%
        (@as(u32, middle) *% m3) +%
        (@as(u32, @intCast(len)) *% m4);
    return @truncate(hash & 63);
}

fn testMultipliers(m1: u32, m2: u32, m3: u32, m4: u32) bool {
    var used = [_]bool{false} ** HASH_SIZE;

    for (keywords) |kw| {
        const hash = perfectHash(kw, m1, m2, m3, m4);
        if (used[hash]) {
            return false; // Collision
        }
        used[hash] = true;
    }

    return true; // No collisions!
}

pub fn main() !void {
    std.debug.print("Searching for perfect hash multipliers...\n", .{});
    std.debug.print("Keywords: {d}\n", .{keywords.len});
    std.debug.print("Hash table size: {d}\n\n", .{HASH_SIZE});

    var found: u32 = 0;
    const primes = [_]u32{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97 };

    // Try all combinations of 4 primes (can be the same)
    for (primes) |m1| {
        for (primes) |m2| {
            for (primes) |m3| {
                for (primes) |m4| {
                    if (testMultipliers(m1, m2, m3, m4)) {
                        found += 1;
                        std.debug.print("✓ Found #{d}: m1={d}, m2={d}, m3={d}, m4={d}\n", .{ found, m1, m2, m3, m4 });

                        if (found == 1) {
                            std.debug.print("\nFirst working combination:\n", .{});
                            std.debug.print("const HASH_MULT_FIRST = {d};\n", .{m1});
                            std.debug.print("const HASH_MULT_LAST = {d};\n", .{m2});
                            std.debug.print("const HASH_MULT_MID = {d};\n", .{m3});
                            std.debug.print("const HASH_MULT_LEN = {d};\n\n", .{m4});

                            // Show the distribution
                            std.debug.print("Hash distribution:\n", .{});
                            for (keywords) |kw| {
                                const hash = perfectHash(kw, m1, m2, m3, m4);
                                std.debug.print("  {s:<10} -> {d:>2}\n", .{ kw, hash });
                            }
                            std.debug.print("\n", .{});
                        }

                        if (found >= 5) {
                            std.debug.print("\nFound {d} working combinations. Using the first one.\n", .{found});
                            return;
                        }
                    }
                }
            }
        }
    }

    if (found == 0) {
        std.debug.print("ERROR: No collision-free hash function found!\n", .{});
        std.debug.print("Try: 1) Increasing HASH_SIZE, 2) Using more primes, 3) Different hash formula\n", .{});
    }
}
