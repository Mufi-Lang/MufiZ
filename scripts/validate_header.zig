const std = @import("std");

const ExportedFunction = struct {
    name: []const u8,
    line: usize,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🔍 Validating C header against c_api.zig exports...\n\n", .{});

    // Read c_api.zig and extract exported functions
    const c_api_content = try std.fs.cwd().readFileAlloc(allocator, "src/c_api.zig", 10 * 1024 * 1024);
    defer allocator.free(c_api_content);

    var zig_exports = std.ArrayList(ExportedFunction).initCapacity(allocator, 0) catch unreachable;
    defer zig_exports.deinit(allocator);

    try extractExportedFunctions(c_api_content, &zig_exports, allocator);

    std.debug.print("Found {} exported functions in src/c_api.zig:\n", .{zig_exports.items.len});
    for (zig_exports.items) |func| {
        std.debug.print("  - {s} (line {})\n", .{ func.name, func.line });
    }
    std.debug.print("\n", .{});

    // Read generated header
    const header_content = try std.fs.cwd().readFileAlloc(allocator, "zig-out/include/mufiz.h", 10 * 1024 * 1024);
    defer allocator.free(header_content);

    var header_decls = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable;
    defer header_decls.deinit(allocator);

    try extractHeaderDeclarations(header_content, &header_decls, allocator);

    std.debug.print("Found {} function declarations in zig-out/include/mufiz.h:\n", .{header_decls.items.len});
    for (header_decls.items) |decl| {
        std.debug.print("  - {s}\n", .{decl});
    }
    std.debug.print("\n", .{});

    // Validate that all exports have declarations
    var all_valid = true;
    var missing_count: usize = 0;

    std.debug.print("🔬 Validation Results:\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

    for (zig_exports.items) |func| {
        const found = findInHeader(func.name, header_decls.items);
        if (found) {
            std.debug.print("✅ {s}\n", .{func.name});
        } else {
            std.debug.print("❌ {s} - MISSING IN HEADER (line {} in c_api.zig)\n", .{ func.name, func.line });
            all_valid = false;
            missing_count += 1;
        }
    }

    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

    if (all_valid) {
        std.debug.print("\n✅ SUCCESS: All exported functions have header declarations!\n", .{});
        std.debug.print("   Total functions validated: {}\n", .{zig_exports.items.len});
        std.process.exit(0);
    } else {
        std.debug.print("\n❌ FAILURE: {} function(s) missing from header!\n", .{missing_count});
        std.debug.print("   Please update scripts/gen_header.zig to include all exports.\n", .{});
        std.process.exit(1);
    }
}

fn extractExportedFunctions(
    content: []const u8,
    exports: *std.ArrayList(ExportedFunction),
    allocator: std.mem.Allocator,
) !void {
    var line_num: usize = 1;
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed, "export fn ")) {
            // Extract function name
            const after_fn = trimmed[10..]; // Skip "export fn "
            if (std.mem.indexOf(u8, after_fn, "(")) |paren_pos| {
                const func_name = after_fn[0..paren_pos];
                const name_copy = try allocator.dupe(u8, func_name);
                try exports.append(allocator, .{
                    .name = name_copy,
                    .line = line_num,
                });
            }
        }
    }
}

fn extractHeaderDeclarations(
    content: []const u8,
    declarations: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !void {
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Look for MUFIZ_API function declarations
        if (std.mem.indexOf(u8, trimmed, "MUFIZ_API") != null) {
            // Skip macro definitions
            if (std.mem.indexOf(u8, trimmed, "#define MUFIZ_API") != null) {
                continue;
            }

            // Extract function name from declaration
            // Format: MUFIZ_API return_type function_name(params);
            const after_api = if (std.mem.indexOf(u8, trimmed, "MUFIZ_API ")) |pos|
                trimmed[pos + 10 ..]
            else
                continue;

            // Skip return type to get function name
            var token_iter = std.mem.tokenizeAny(u8, after_api, " \t*");
            _ = token_iter.next(); // Skip return type (might be int32_t, void, etc.)

            if (token_iter.next()) |func_part| {
                // Extract just the function name (before parenthesis)
                if (std.mem.indexOf(u8, func_part, "(")) |paren_pos| {
                    const func_name = func_part[0..paren_pos];
                    const name_copy = try allocator.dupe(u8, func_name);
                    try declarations.append(allocator, name_copy);
                }
            }
        }
    }
}

fn findInHeader(func_name: []const u8, header_decls: []const []const u8) bool {
    for (header_decls) |decl| {
        if (std.mem.eql(u8, func_name, decl)) {
            return true;
        }
    }
    return false;
}
