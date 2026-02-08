const std = @import("std");
const testing = std.testing;

/// MufiZ Synthetic Test Generator
/// Generates syntactically correct Mufi-Lang code snippets.
pub const TestGenerator = struct {
    allocator: std.mem.Allocator,
    random: std.Random,

    pub fn init(allocator: std.mem.Allocator, random: std.Random) TestGenerator {
        return .{ .allocator = allocator, .random = random };
    }

    /// Generates a random valid script.
    pub fn generateScript(self: *TestGenerator) ![]u8 {
        var output = std.ArrayList(u8).initCapacity(self.allocator, 0) catch unreachable;
        defer output.deinit(self.allocator);

        // Generate a few random statements
        const count = self.random.uintAtMost(usize, 5) + 1;
        for (0..count) |_| {
            try self.generateStatement(&output);
        }

        return output.toOwnedSlice(self.allocator);
    }

    fn generateStatement(self: *TestGenerator, output: *std.ArrayList(u8)) !void {
        const choice = self.random.uintAtMost(u8, 2);
        switch (choice) {
            0 => {
                // Print statement
                try output.appendSlice(self.allocator, "print(");
                try self.generateExpression(output);
                try output.appendSlice(self.allocator, ");\n");
            },
            1 => {
                // Variable declaration
                try output.appendSlice(self.allocator, "var x = ");
                try self.generateExpression(output);
                try output.appendSlice(self.allocator, ";\n");
            },
            else => {
                // Expression statement
                try self.generateExpression(output);
                try output.appendSlice(self.allocator, ";\n");
            },
        }
    }

    fn generateExpression(self: *TestGenerator, output: *std.ArrayList(u8)) !void {
        const choice = self.random.uintAtMost(u8, 2);
        switch (choice) {
            0 => {
                // Number
                const val = self.random.uintAtMost(u32, 100);
                var buf: [16]u8 = undefined;
                const slice = std.fmt.bufPrint(&buf, "{d}", .{val}) catch unreachable;
                try output.appendSlice(self.allocator, slice);
            },
            1 => {
                // String
                try output.appendSlice(self.allocator, "\"random_string\"");
            },
            else => {
                // Simple addition
                try output.appendSlice(self.allocator, "10 + 20");
            }
        }
    }
};

test "test generation" {
    var prng = std.Random.DefaultPrng.init(0);
    var gen = TestGenerator.init(testing.allocator, prng.random());
    
    const script = try gen.generateScript();
    defer testing.allocator.free(script);
    
    try testing.expect(script.len > 0);
    // Basic syntax check - should contain at least one semicolon
    try testing.expect(std.mem.indexOf(u8, script, ";") != null);
}