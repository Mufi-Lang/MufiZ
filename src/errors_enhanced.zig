const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

// ============================================================================
// Enhanced Error Structures
// ============================================================================

/// Represents a span of code in the source file
pub const ErrorSpan = struct {
    line_start: u32,
    column_start: u32,
    line_end: u32,
    column_end: u32,
    label: ?[]const u8 = null,
    is_primary: bool = true,
};

/// Informational note about an error
pub const ErrorNote = struct {
    message: []const u8,
    span: ?ErrorSpan = null,
};

/// How reliable a code suggestion is
pub const Applicability = enum {
    MachineApplicable, // Safe to auto-apply
    MaybeIncorrect, // Probably correct but needs review
    HasPlaceholders, // Contains placeholders like <expr>
    Unspecified, // Manual intervention required
};

/// A concrete code change suggestion
pub const CodeSuggestion = struct {
    original: []const u8,
    replacement: []const u8,
    span: ErrorSpan,
    applicability: Applicability,
};

/// Actionable help for fixing an error
pub const ErrorHelp = struct {
    message: []const u8,
    code_suggestion: ?CodeSuggestion = null,
};

/// Enhanced error information structure
pub const EnhancedErrorInfo = struct {
    // Basic info
    code: []const u8, // e.g., "E001"
    category: []const u8, // "syntax", "semantic", "type", etc.
    severity: []const u8, // "error", "warning", "info", "hint"
    message: []const u8,

    // Location info
    primary_span: ErrorSpan,
    secondary_spans: []const ErrorSpan = &[_]ErrorSpan{},

    // Structured feedback
    notes: []const ErrorNote = &[_]ErrorNote{},
    help: []const ErrorHelp = &[_]ErrorHelp{},

    // Metadata
    error_number: ?u32 = null,
    file_path: ?[]const u8 = null,
    source_code: ?[]const u8 = null,
};

// ============================================================================
// Enhanced Error Printer
// ============================================================================

pub const EnhancedErrorPrinter = struct {
    allocator: Allocator,
    use_color: bool = true,
    context_lines: u32 = 2,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn printError(self: *Self, info: EnhancedErrorInfo) void {
        self.printHeader(info);
        self.printLocation(info);

        if (info.source_code) |source| {
            self.printSourceContext(source, info);
        }

        self.printNotes(info.notes);
        self.printHelp(info.help);

        if (info.error_number) |num| {
            self.printExplainHint(num);
        }

        print("\n", .{});
    }

    fn printHeader(self: *Self, info: EnhancedErrorInfo) void {
        // Print severity with color
        if (self.use_color) {
            const color = self.getSeverityColor(info.severity);
            print("\x1b[{s};1m{s}\x1b[0m", .{ color, info.severity });
        } else {
            print("{s}", .{info.severity});
        }

        // Print error code
        if (info.error_number) |num| {
            if (self.use_color) {
                print("\x1b[1m[E{d:0>3}]\x1b[0m", .{num});
            } else {
                print("[E{d:0>3}]", .{num});
            }
        }

        print(": {s}\n", .{info.message});
    }

    fn printLocation(self: *Self, info: EnhancedErrorInfo) void {
        if (info.file_path) |path| {
            if (self.use_color) {
                print("  \x1b[36m-->\x1b[0m {s}:{d}:{d}\n", .{
                    path,
                    info.primary_span.line_start,
                    info.primary_span.column_start,
                });
            } else {
                print("  --> {s}:{d}:{d}\n", .{
                    path,
                    info.primary_span.line_start,
                    info.primary_span.column_start,
                });
            }
        }
    }

    fn printSourceContext(self: *Self, source: []const u8, info: EnhancedErrorInfo) void {
        var lines = std.mem.splitSequence(u8, source, "\n");
        var line_num: u32 = 1;

        const context_start = if (info.primary_span.line_start > self.context_lines)
            info.primary_span.line_start - self.context_lines
        else
            1;
        const context_end = info.primary_span.line_end + self.context_lines;

        // Print gutter
        self.printGutter();

        while (lines.next()) |line| : (line_num += 1) {
            if (line_num < context_start) continue;
            if (line_num > context_end) break;

            // Print line
            self.printSourceLine(line, line_num, info.primary_span.line_start);

            // Print primary span underline
            if (line_num >= info.primary_span.line_start and line_num <= info.primary_span.line_end) {
                self.printSpanUnderline(line, info.primary_span, true);
            }

            // Print secondary span underlines
            for (info.secondary_spans) |span| {
                if (line_num >= span.line_start and line_num <= span.line_end) {
                    self.printSpanUnderline(line, span, false);
                }
            }
        }

        // Print closing gutter
        self.printGutter();
    }

    fn printGutter(self: *Self) void {
        if (self.use_color) {
            print("   \x1b[36m|\x1b[0m\n", .{});
        } else {
            print("   |\n", .{});
        }
    }

    fn printSourceLine(self: *Self, line: []const u8, line_num: u32, highlight_line: u32) void {
        const is_highlight = line_num == highlight_line;

        if (self.use_color) {
            if (is_highlight) {
                print("\x1b[36m{d:>4} |\x1b[0m ", .{line_num});
            } else {
                print("{d:>4} | ", .{line_num});
            }
        } else {
            print("{d:>4} | ", .{line_num});
        }

        print("{s}\n", .{line});
    }

    fn printSpanUnderline(self: *Self, line: []const u8, span: ErrorSpan, is_primary: bool) void {
        print("     | ", .{});

        // Print spaces before underline
        var i: u32 = 1;
        while (i < span.column_start) : (i += 1) {
            print(" ", .{});
        }

        // Print underline with color
        if (self.use_color) {
            if (is_primary) {
                print("\x1b[31;1m", .{}); // Bright red for primary
            } else {
                print("\x1b[33;1m", .{}); // Bright yellow for secondary
            }
        }

        // Calculate underline length
        const length = if (span.line_start == span.line_end)
            span.column_end - span.column_start + 1
        else
            line.len - span.column_start + 1;

        var j: u32 = 0;
        while (j < length) : (j += 1) {
            print("^", .{});
        }

        if (self.use_color) {
            print("\x1b[0m", .{});
        }

        // Print label if available
        if (span.label) |label| {
            print(" {s}", .{label});
        }

        print("\n", .{});
    }

    fn printNotes(self: *Self, notes: []const ErrorNote) void {
        if (notes.len == 0) return;

        print("\n", .{});
        for (notes) |note| {
            if (self.use_color) {
                print("  \x1b[36m=\x1b[0m \x1b[1mnote:\x1b[0m {s}\n", .{note.message});
            } else {
                print("  = note: {s}\n", .{note.message});
            }
        }
    }

    fn printHelp(self: *Self, help: []const ErrorHelp) void {
        if (help.len == 0) return;

        print("\n", .{});
        for (help) |help_item| {
            if (self.use_color) {
                print("  \x1b[36m=\x1b[0m \x1b[1mhelp:\x1b[0m {s}\n", .{help_item.message});
            } else {
                print("  = help: {s}\n", .{help_item.message});
            }

            if (help_item.code_suggestion) |suggestion| {
                self.printCodeSuggestion(suggestion);
            }
        }
    }

    fn printCodeSuggestion(self: *Self, suggestion: CodeSuggestion) void {
        // Print the replacement as a diff-style suggestion
        if (self.use_color) {
            print("     |\n", .{});
            print("     | \x1b[32m{s}\x1b[0m\n", .{suggestion.replacement});
        } else {
            print("     |\n", .{});
            print("     | {s}\n", .{suggestion.replacement});
        }
    }

    fn printExplainHint(self: *Self, error_num: u32) void {
        print("\n", .{});
        if (self.use_color) {
            print("  \x1b[36m=\x1b[0m \x1b[2mfor more information about this error, try `mufiz --explain E{d:0>3}`\x1b[0m\n", .{error_num});
        } else {
            print("  = for more information about this error, try `mufiz --explain E{d:0>3}`\n", .{error_num});
        }
    }

    fn getSeverityColor(self: *Self, severity: []const u8) []const u8 {
        _ = self;
        if (std.mem.eql(u8, severity, "error")) return "31";
        if (std.mem.eql(u8, severity, "warning")) return "33";
        if (std.mem.eql(u8, severity, "info")) return "36";
        if (std.mem.eql(u8, severity, "hint")) return "32";
        return "37";
    }
};

// ============================================================================
// Levenshtein Distance for Similarity Matching
// ============================================================================

pub fn levenshteinDistance(s1: []const u8, s2: []const u8, allocator: Allocator) !usize {
    const len1 = s1.len;
    const len2 = s2.len;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    // Create matrix for dynamic programming
    var matrix = try allocator.alloc([]usize, len1 + 1);
    defer {
        for (matrix) |row| allocator.free(row);
        allocator.free(matrix);
    }

    for (matrix, 0..) |*row, i| {
        row.* = try allocator.alloc(usize, len2 + 1);
        row.*[0] = i;
    }

    for (0..len2 + 1) |j| {
        matrix[0][j] = j;
    }

    for (1..len1 + 1) |i| {
        for (1..len2 + 1) |j| {
            const cost: usize = if (s1[i - 1] == s2[j - 1]) 0 else 1;
            matrix[i][j] = @min(@min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1), matrix[i - 1][j - 1] + cost);
        }
    }

    return matrix[len1][len2];
}

pub const SimilarName = struct {
    name: []const u8,
    distance: usize,
};

pub fn findSimilarNames(
    name: []const u8,
    candidates: []const []const u8,
    allocator: Allocator,
    max_distance: usize,
) ![]const []const u8 {
    var matches = std.ArrayList(SimilarName).init(allocator);
    defer matches.deinit();

    for (candidates) |candidate| {
        const distance = try levenshteinDistance(name, candidate, allocator);

        // Consider it similar if distance is small relative to name length
        const threshold = @max(max_distance, name.len / 3);
        if (distance <= threshold) {
            try matches.append(.{
                .name = candidate,
                .distance = distance,
            });
        }
    }

    // Sort by distance (closest first)
    std.mem.sort(SimilarName, matches.items, {}, struct {
        fn lessThan(_: void, a: SimilarName, b: SimilarName) bool {
            return a.distance < b.distance;
        }
    }.lessThan);

    // Extract just the names
    var result = try allocator.alloc([]const u8, matches.items.len);
    for (matches.items, 0..) |match, i| {
        result[i] = match.name;
    }

    return result;
}

// ============================================================================
// Enhanced Error Templates
// ============================================================================

pub const EnhancedTemplates = struct {
    pub fn undefinedVariable(
        name: []const u8,
        line: u32,
        column: u32,
        length: u32,
        available_vars: []const []const u8,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        const similar = try findSimilarNames(name, available_vars, allocator, 2);
        defer allocator.free(similar);

        var help_list = std.ArrayList(ErrorHelp).init(allocator);

        if (similar.len > 0) {
            const did_you_mean = try std.fmt.allocPrint(allocator, "did you mean `{s}`?", .{similar[0]});

            try help_list.append(.{
                .message = did_you_mean,
                .code_suggestion = .{
                    .original = name,
                    .replacement = similar[0],
                    .span = .{
                        .line_start = line,
                        .column_start = column,
                        .line_end = line,
                        .column_end = column + length,
                    },
                    .applicability = .MaybeIncorrect,
                },
            });
        } else {
            try help_list.append(.{
                .message = "declare the variable before using it",
            });
        }

        var notes = std.ArrayList(ErrorNote).init(allocator);
        if (available_vars.len > 0) {
            const vars_list = try std.mem.join(allocator, ", ", available_vars);
            const note_msg = try std.fmt.allocPrint(allocator, "available variables in scope: {s}", .{vars_list});
            try notes.append(.{ .message = note_msg });
        }

        return EnhancedErrorInfo{
            .code = "E001",
            .category = "semantic",
            .severity = "error",
            .message = try std.fmt.allocPrint(allocator, "cannot find value `{s}` in this scope", .{name}),
            .error_number = 1,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + length,
                .label = "not found in this scope",
                .is_primary = true,
            },
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(),
            .notes = try notes.toOwnedSlice(),
        };
    }

    pub fn typeMismatch(
        expected: []const u8,
        found: []const u8,
        expr_line: u32,
        expr_column: u32,
        expr_length: u32,
        expected_line: ?u32,
        expected_column: ?u32,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).init(allocator);

        if (expected_line) |exp_line| {
            if (expected_column) |exp_col| {
                try secondary_spans.append(.{
                    .line_start = exp_line,
                    .column_start = exp_col,
                    .line_end = exp_line,
                    .column_end = exp_col + expected.len,
                    .label = try std.fmt.allocPrint(allocator, "expected `{s}` because of this", .{expected}),
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).init(allocator);

        // Add type-specific conversion help
        if (std.mem.eql(u8, expected, "string") and std.mem.eql(u8, found, "number")) {
            try help_list.append(.{
                .message = "convert the number to a string using toString()",
            });
        } else if (std.mem.eql(u8, expected, "number") and std.mem.eql(u8, found, "string")) {
            try help_list.append(.{
                .message = "parse the string to a number using parseInt() or parseFloat()",
            });
        }

        return EnhancedErrorInfo{
            .code = "E002",
            .category = "type",
            .severity = "error",
            .message = try std.fmt.allocPrint(allocator, "mismatched types: expected `{s}`, found `{s}`", .{ expected, found }),
            .error_number = 2,
            .primary_span = .{
                .line_start = expr_line,
                .column_start = expr_column,
                .line_end = expr_line,
                .column_end = expr_column + expr_length,
                .label = try std.fmt.allocPrint(allocator, "expected `{s}`, found `{s}`", .{ expected, found }),
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(),
        };
    }

    pub fn redefinedVariable(
        name: []const u8,
        current_line: u32,
        current_column: u32,
        current_length: u32,
        previous_line: u32,
        previous_column: u32,
        previous_length: u32,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = try allocator.alloc(ErrorSpan, 1);
        secondary_spans[0] = .{
            .line_start = previous_line,
            .column_start = previous_column,
            .line_end = previous_line,
            .column_end = previous_column + previous_length,
            .label = "previous definition here",
            .is_primary = false,
        };

        var notes = try allocator.alloc(ErrorNote, 1);
        notes[0] = .{ .message = "variables must have unique names within the same scope" };

        var help_list = std.ArrayList(ErrorHelp).init(allocator);
        try help_list.append(.{ .message = "choose a different name for this variable" });
        try help_list.append(.{ .message = "or remove the previous definition if no longer needed" });

        return EnhancedErrorInfo{
            .code = "E003",
            .category = "semantic",
            .severity = "error",
            .message = try std.fmt.allocPrint(allocator, "the name `{s}` is defined multiple times", .{name}),
            .error_number = 3,
            .primary_span = .{
                .line_start = current_line,
                .column_start = current_column,
                .line_end = current_line,
                .column_end = current_column + current_length,
                .label = try std.fmt.allocPrint(allocator, "`{s}` redefined here", .{name}),
                .is_primary = true,
            },
            .secondary_spans = secondary_spans,
            .source_code = source,
            .file_path = file_path,
            .notes = notes,
            .help = try help_list.toOwnedSlice(),
        };
    }
};

// ============================================================================
// Test/Demo
// ============================================================================

pub fn demo() !void {
    const allocator = std.heap.page_allocator;

    const source =
        \\var count = 0;
        \\var total = 100;
        \\
        \\print(coun);
        \\
    ;

    const available_vars = [_][]const u8{ "count", "total" };

    const error_info = try EnhancedTemplates.undefinedVariable(
        "coun",
        4,
        7,
        4,
        &available_vars,
        source,
        "test.mz",
        allocator,
    );

    var printer = EnhancedErrorPrinter.init(allocator);
    printer.printError(error_info);
}
