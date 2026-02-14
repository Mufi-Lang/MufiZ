const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const mem_utils = @import("mem_utils.zig");

pub const ErrorCategory = enum {
    SYNTAX,
    SEMANTIC,
    RUNTIME,
    TYPE,
    MEMORY,
    IO,
    NETWORK,
    SYSTEM,
};

pub const ErrorSeverity = enum {
    ERROR,
    WARNING,
    INFO,
    HINT,
};

pub const ErrorCode = enum {
    // Syntax errors
    UNEXPECTED_TOKEN,
    UNTERMINATED_STRING,
    UNTERMINATED_COMMENT,
    INVALID_CHARACTER,
    MISSING_SEMICOLON,
    MISMATCHED_BRACKETS,
    EXPECTED_EXPRESSION,
    INVALID_ASSIGNMENT,

    // Semantic errors
    UNDEFINED_VARIABLE,
    REDEFINED_VARIABLE,
    UNDEFINED_FUNCTION,
    UNDEFINED_PROPERTY,
    WRONG_ARGUMENT_COUNT,
    INVALID_OPERATION,

    // Type errors
    TYPE_MISMATCH,
    INVALID_CAST,
    INCOMPATIBLE_TYPES,

    // Runtime errors
    STACK_OVERFLOW,
    INDEX_OUT_OF_BOUNDS,
    NULL_REFERENCE,
    DIVISION_BY_ZERO,

    // Memory errors
    OUT_OF_MEMORY,
    MEMORY_LEAK,

    // Limits
    TOO_MANY_CONSTANTS,
    TOO_MANY_LOCALS,
    TOO_MANY_ARGUMENTS,
    LOOP_TOO_LARGE,
    JUMP_TOO_LARGE,

    // Class/Object errors
    INVALID_SUPER_USAGE,
    INVALID_SELF_USAGE,
    CLASS_INHERITANCE_ERROR,
    METHOD_NOT_FOUND,

    // Control flow
    INVALID_RETURN,
    INVALID_BREAK,
    INVALID_CONTINUE,
};

pub const ErrorSuggestion = struct {
    message: []const u8,
    fix: ?[]const u8 = null,
    example: ?[]const u8 = null,
};

pub const ErrorInfo = struct {
    code: ErrorCode,
    category: ErrorCategory,
    severity: ErrorSeverity,
    line: u32,
    column: u32,
    length: u32,
    message: []const u8,
    suggestions: []const ErrorSuggestion,
    context: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
};

pub const ErrorManager = struct {
    allocator: Allocator,
    errors: std.ArrayList(ErrorInfo),
    has_error: bool,
    panic_mode: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .errors = undefined, // Disabled for Zig 0.15 compatibility
            .has_error = false,
            .panic_mode = false,
        };
    }

    pub fn deinit(self: *Self) void {
        // errors field is disabled in Zig 0.15 compatibility mode
        _ = self;
    }

    pub fn reportError(self: *Self, info: ErrorInfo) void {
        if (self.panic_mode) return;

        self.has_error = true;
        self.panic_mode = true;

        // self.errors.append(info) disabled for Zig 0.15
        // Just print the error directly for now
        self.printError(info);
    }

    pub fn reportErrorEnhanced(self: *Self, info: EnhancedErrorInfo) void {
        if (self.panic_mode) return;

        self.has_error = true;
        self.panic_mode = true;

        // Print using enhanced printer
        var printer = EnhancedErrorPrinter.init(self.allocator);
        printer.printError(info);
    }

    pub fn printError(self: *Self, info: ErrorInfo) void {
        _ = self;

        // Print error header with severity and category
        switch (info.severity) {
            .ERROR => print("\x1b[31mError\x1b[0m", .{}),
            .WARNING => print("\x1b[33mWarning\x1b[0m", .{}),
            .INFO => print("\x1b[36mInfo\x1b[0m", .{}),
            .HINT => print("\x1b[32mHint\x1b[0m", .{}),
        }

        print(" [{s}:{d}:{d}] ", .{ info.file_path orelse "unknown", info.line, info.column });

        // Print category
        switch (info.category) {
            .SYNTAX => print("(Syntax) ", .{}),
            .SEMANTIC => print("(Semantic) ", .{}),
            .RUNTIME => print("(Runtime) ", .{}),
            .TYPE => print("(Type) ", .{}),
            .MEMORY => print("(Memory) ", .{}),
            .IO => print("(I/O) ", .{}),
            .NETWORK => print("(Network) ", .{}),
            .SYSTEM => print("(System) ", .{}),
        }

        // Print main error message
        print("{s}\n", .{info.message});

        // Print context if available
        if (info.context) |context| {
            print("    {s}\n", .{context});

            // Print caret pointing to error location
            var i: u32 = 0;
            print("    ", .{});
            while (i < info.column - 1) : (i += 1) {
                print(" ", .{});
            }
            print("\x1b[31m", .{});
            var j: u32 = 0;
            while (j < info.length) : (j += 1) {
                print("^", .{});
            }
            print("\x1b[0m\n", .{});
        }

        // Print suggestions
        if (info.suggestions.len > 0) {
            print("\n", .{});
            for (info.suggestions) |suggestion| {
                print("  \x1b[36mSuggestion:\x1b[0m {s}\n", .{suggestion.message});

                if (suggestion.fix) |fix| {
                    print("    \x1b[32mFix:\x1b[0m {s}\n", .{fix});
                }

                if (suggestion.example) |example| {
                    print("    \x1b[33mExample:\x1b[0m {s}\n", .{example});
                }
            }
        }

        print("\n", .{});
    }

    pub fn reset(self: *Self) void {
        self.has_error = false;
        self.panic_mode = false;
        self.errors.clearRetainingCapacity();
    }

    pub fn hasError(self: *Self) bool {
        return self.has_error;
    }

    pub fn enterPanicMode(self: *Self) void {
        self.panic_mode = true;
    }

    pub fn exitPanicMode(self: *Self) void {
        self.panic_mode = false;
    }
};

// Predefined error templates with suggestions
pub const ErrorTemplates = struct {
    /// Helper function to format strings using the global allocator
    /// This reduces repetition of std.fmt.allocPrint(mem_utils.getAllocator(), ...) pattern
    inline fn fmt(comptime format: []const u8, args: anytype) []const u8 {
        return std.fmt.allocPrint(mem_utils.getAllocator(), format, args) catch format;
    }

    pub fn unexpectedToken(actual: []const u8, expected: []const u8) ErrorInfo {
        const message = fmt("Unexpected token '{s}', expected '{s}'", .{ actual, expected });

        return ErrorInfo{
            .code = .UNEXPECTED_TOKEN,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(actual.len),
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = fmt("Replace '{s}' with '{s}'", .{ actual, expected }) },
            },
        };
    }

    pub fn undefinedVariable(name: []const u8, similar_names: []const []const u8) ErrorInfo {
        const message = fmt("Undefined variable '{s}'", .{name});

        var suggestions = std.ArrayList(ErrorSuggestion).initCapacity(mem_utils.getAllocator(), 0) catch unreachable;
        suggestions.append(mem_utils.getAllocator(), .{ .message = "Declare the variable before using it" }) catch {};

        if (similar_names.len > 0) {
            const suggestion_msg = fmt("Did you mean '{s}'?", .{similar_names[0]});
            suggestions.append(mem_utils.getAllocator(), .{ .message = suggestion_msg }) catch {};
            defer suggestions.deinit(mem_utils.getAllocator());

            // Add fix suggestion if there's a close match
            const fix_msg = fmt("Replace '{s}' with '{s}'", .{ name, similar_names[0] });
            suggestions.append(mem_utils.getAllocator(), .{ .message = fix_msg }) catch {};
        } else {
            // No similar names found, provide more general suggestions
            suggestions.append(mem_utils.getAllocator(), .{ .message = "Check the variable name spelling" }) catch {};
            suggestions.append(mem_utils.getAllocator(), .{ .message = "Ensure the variable is in the correct scope" }) catch {};
        }

        // Add context-specific suggestions
        if (name.len <= 2) {
            suggestions.append(mem_utils.getAllocator(), .{ .message = "Variable names should be descriptive and longer than 2 characters" }) catch {};
        }

        suggestions.append(mem_utils.getAllocator(), .{ .message = "Example variable declaration", .example = fmt("var {s} = value;", .{name}) }) catch {};

        return ErrorInfo{
            .code = .UNDEFINED_VARIABLE,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(name.len),
            .message = message,
            .suggestions = suggestions.toOwnedSlice(mem_utils.getAllocator()) catch &[_]ErrorSuggestion{},
        };
    }

    pub fn wrongArgumentCount(function_name: []const u8, expected: u32, actual: u32) ErrorInfo {
        const message = fmt("Function '{s}' expects {d} arguments, but {d} were provided", .{ function_name, expected, actual });

        const fix_msg = if (actual > expected)
            fmt("Remove {} argument{s}", .{ actual - expected, if (actual - expected == 1) "" else "s" })
        else
            fmt("Add {} argument{s}", .{ expected - actual, if (expected - actual == 1) "" else "s" });

        return ErrorInfo{
            .code = .WRONG_ARGUMENT_COUNT,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(function_name.len),
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = fix_msg },
                .{ .message = "Check the function signature for the correct number of parameters" },
            },
        };
    }

    pub fn tooManyLocals() ErrorInfo {
        return ErrorInfo{
            .code = .TOO_MANY_LOCALS,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = "Too many local variables in function (maximum 256)",
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = "Reduce the number of local variables" },
                .{ .message = "Consider breaking the function into smaller functions" },
                .{ .message = "Use data structures to group related variables" },
            },
        };
    }

    pub fn invalidSuperUsage() ErrorInfo {
        return ErrorInfo{
            .code = .INVALID_SUPER_USAGE,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 5,
            .message = "Cannot use 'super' outside of a class or in a class with no superclass",
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = "Use 'super' only inside methods of a derived class" },
                .{ .message = "Ensure the class inherits from another class" },
                .{ .message = "Use 'super' to call parent class methods", .example = "super.methodName(args)" },
            },
        };
    }

    pub fn stackOverflow() ErrorInfo {
        return ErrorInfo{
            .code = .STACK_OVERFLOW,
            .category = .RUNTIME,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = "Stack overflow - too many function calls",
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = "Check for infinite recursion" },
                .{ .message = "Add a base case to recursive functions" },
                .{ .message = "Consider using iteration instead of recursion" },
                .{ .message = "Limit recursion depth", .example = "if (depth > MAX_DEPTH) return;" },
            },
        };
    }

    pub fn indexOutOfBounds(index: i32, size: i32) ErrorInfo {
        const message = fmt("Index {d} is out of bounds for size {d}", .{ index, size });

        return ErrorInfo{
            .code = .INDEX_OUT_OF_BOUNDS,
            .category = .RUNTIME,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = fmt("Valid indices are 0 to {d}", .{size - 1}) },
                .{ .message = "Check array/vector size before accessing elements" },
                .{ .message = "Use bounds checking", .example = "if (index >= 0 && index < size) { ... }" },
            },
        };
    }

    pub fn missingToken(expected: []const u8, context: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Expected '{s}' {s}", .{ expected, context }) catch "Missing token";

        return ErrorInfo{
            .code = .UNEXPECTED_TOKEN,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = std.fmt.allocPrint(std.heap.page_allocator, "Add '{s}' {s}", .{ expected, context }) catch "Add missing token" },
                .{ .message = "Check for matching brackets, braces, or parentheses" },
            },
        };
    }

    pub fn invalidReturnContext(context: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Cannot return {s}", .{context}) catch "Invalid return";

        return ErrorInfo{
            .code = .INVALID_RETURN,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 6, // "return".len
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = "Use return statements only inside functions" },
                .{ .message = "Remove the return statement if not needed" },
                .{ .example = "fun example() { return value; }" },
            },
        };
    }

    pub fn typeMismatch(expected: []const u8, actual: []const u8, operation: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Type mismatch in {s}: expected {s}, got {s}", .{ operation, expected, actual }) catch "Type mismatch";

        return ErrorInfo{
            .code = .TYPE_MISMATCH,
            .category = .TYPE,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = std.fmt.allocPrint(std.heap.page_allocator, "Convert {s} to {s}", .{ actual, expected }) catch "Convert types" },
                .{ .message = "Check that all operands are of compatible types" },
                .{ .example = "number + number, string + string" },
            },
        };
    }

    pub fn divisionByZero() ErrorInfo {
        return ErrorInfo{
            .code = .DIVISION_BY_ZERO,
            .category = .RUNTIME,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = "Division by zero",
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = "Check that the divisor is not zero before division" },
                .{ .message = "Add a condition to handle zero values" },
                .{ .message = "Use defensive programming", .example = "if (divisor != 0) { result = dividend / divisor; }" },
            },
        };
    }

    pub fn undefinedMethod(className: []const u8, methodName: []const u8, availableMethods: []const []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Undefined method '{s}' on class '{s}'", .{ methodName, className }) catch "Undefined method";

        var suggestions = std.ArrayList(ErrorSuggestion).initCapacity(std.heap.page_allocator, 0) catch unreachable;
        suggestions.append(std.heap.page_allocator, .{ .message = "Check the method name spelling" }) catch {};

        if (availableMethods.len > 0) {
            const similar = findSimilarNames(methodName, availableMethods, std.heap.page_allocator);
            if (similar.len > 0) {
                const suggestion_msg = std.fmt.allocPrint(std.heap.page_allocator, "Did you mean '{s}'?", .{similar[0]}) catch "Check available methods";
                suggestions.append(std.heap.page_allocator, .{ .message = suggestion_msg }) catch {};
                defer suggestions.deinit(std.heap.page_allocator);

                const fix_msg = std.fmt.allocPrint(std.heap.page_allocator, "Replace '{s}' with '{s}'", .{ methodName, similar[0] }) catch "Fix method name";
                suggestions.append(std.heap.page_allocator, .{ .message = fix_msg }) catch {};
            } else {
                // Show available methods if no close match
                const methods_list = std.mem.join(std.heap.page_allocator, ", ", availableMethods) catch "method1, method2";
                const available_msg = std.fmt.allocPrint(std.heap.page_allocator, "Available methods: {s}", .{methods_list}) catch "Check class methods";
                suggestions.append(std.heap.page_allocator, .{ .message = available_msg }) catch {};
            }
        }

        suggestions.append(std.heap.page_allocator, .{ .message = "Ensure the method is defined in the class or its parent classes" }) catch {};
        suggestions.append(std.heap.page_allocator, .{ .message = "Example method call", .example = std.fmt.allocPrint(std.heap.page_allocator, "object.{s}()", .{methodName}) catch "object.method()" }) catch {};

        return ErrorInfo{
            .code = .METHOD_NOT_FOUND,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(methodName.len),
            .message = message,
            .suggestions = suggestions.toOwnedSlice(std.heap.page_allocator) catch &[_]ErrorSuggestion{},
        };
    }

    pub fn invalidCharacter(char: u8, context: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Invalid character '{c}' (ASCII {d}) {s}", .{ char, char, context }) catch "Invalid character";

        var suggestions = undefined; // Disabled for Zig 0.15
        suggestions.append(.{ .message = "Remove or replace the invalid character" }) catch {};

        // Provide specific suggestions based on character
        switch (char) {
            '@' => suggestions.append(.{ .message = "Use 'at' or remove the @ symbol" }) catch {},
            '#' => suggestions.append(.{ .message = "Comments start with // not #" }) catch {},
            '$' => suggestions.append(.{ .message = "Variable names cannot start with $" }) catch {},
            '`' => suggestions.append(.{ .message = "Use double quotes \" for strings" }) catch {},
            else => suggestions.append(.{ .message = "Check if you meant to use a different symbol" }) catch {},
        }

        return ErrorInfo{
            .code = .INVALID_CHARACTER,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = message,
            .suggestions = suggestions.toOwnedSlice() catch &[_]ErrorSuggestion{},
        };
    }
};

pub fn findSimilarNames(name: []const u8, candidates: []const []const u8, allocator: Allocator) []const []const u8 {
    _ = allocator;
    // For Zig 0.15, just return a hardcoded similar name if it exists
    for (candidates) |candidate| {
        // Basic similarity check - matching prefix is a close match
        if (candidate.len > 2 and name.len > 2) {
            if (std.mem.startsWith(u8, candidate, name[0..1])) {
                return &[_][]const u8{candidate};
            }
        }
    }
    return &[_][]const u8{};
}

// ============================================================================
// ENHANCED ERROR SYSTEM (Phase 1)
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

    /// Free all allocated memory in this error info
    pub fn deinit(self: EnhancedErrorInfo, allocator: Allocator) void {
        // Free main message
        allocator.free(self.message);

        // Free primary span label if allocated
        if (self.primary_span.label) |label| {
            allocator.free(label);
        }

        // Free secondary spans and their labels
        for (self.secondary_spans) |span| {
            if (span.label) |label| {
                allocator.free(label);
            }
        }
        if (self.secondary_spans.len > 0) {
            allocator.free(self.secondary_spans);
        }

        // Free notes and their messages
        for (self.notes) |note| {
            allocator.free(note.message);
        }
        if (self.notes.len > 0) {
            allocator.free(self.notes);
        }

        // Free help items and their messages
        for (self.help) |help_item| {
            allocator.free(help_item.message);
            // Note: code_suggestion.replacement is typically a pointer to existing data,
            // not allocated, so we don't free it
        }
        if (self.help.len > 0) {
            allocator.free(self.help);
        }
    }
};

// ============================================================================
// LEVENSHTEIN DISTANCE ALGORITHM
// ============================================================================

/// Calculate the Levenshtein distance between two strings
/// This is used for better "did you mean" suggestions
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

/// Find similar names using Levenshtein distance
pub fn findSimilarNamesEnhanced(
    name: []const u8,
    candidates: []const []const u8,
    allocator: Allocator,
    max_distance: usize,
) ![]const []const u8 {
    var matches = std.ArrayList(SimilarName).initCapacity(allocator, 0) catch unreachable;
    defer matches.deinit(allocator);

    for (candidates) |candidate| {
        const distance = try levenshteinDistance(name, candidate, allocator);

        // Consider it similar if distance is small relative to name length
        const threshold = @max(max_distance, name.len / 3);
        if (distance <= threshold) {
            try matches.append(allocator, .{
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
// ENHANCED ERROR PRINTER
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
            span.column_end - span.column_start
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
        _ = suggestion;
        if (self.use_color) {
            print("     |\n", .{});
            // print("     | \x1b[32m{s}\x1b[0m\n", .{suggestion.replacement});
        } else {
            print("     |\n", .{});
            // print("     | {s}\n", .{suggestion.replacement});
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
// ENHANCED ERROR TEMPLATES
// ============================================================================

pub const EnhancedTemplates = struct {
    /// Create an undefined variable error with enhanced formatting
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
        const similar = try findSimilarNamesEnhanced(name, available_vars, allocator, 2);
        defer allocator.free(similar);

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        if (similar.len > 0) {
            const did_you_mean = try std.fmt.allocPrint(allocator, "did you mean `{s}`?", .{similar[0]});

            try help_list.append(allocator, .{
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
            try help_list.append(allocator, .{
                .message = "declare the variable before using it",
            });
        }

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);
        // Only show similar variables if we found any, otherwise show a limited subset
        if (similar.len > 0) {
            const vars_list = try std.mem.join(allocator, ", ", similar);
            const note_msg = try std.fmt.allocPrint(allocator, "similar variables available: {s}", .{vars_list});
            try notes.append(allocator, .{ .message = note_msg });
        } else if (available_vars.len > 0 and available_vars.len <= 10) {
            // Only show all variables if there are 10 or fewer
            const vars_list = try std.mem.join(allocator, ", ", available_vars);
            const note_msg = try std.fmt.allocPrint(allocator, "available variables in scope: {s}", .{vars_list});
            try notes.append(allocator, .{ .message = note_msg });
        } else if (available_vars.len > 10) {
            const note_msg = try std.fmt.allocPrint(allocator, "{d} variables available in scope (use a more specific name)", .{available_vars.len});
            try notes.append(allocator, .{ .message = note_msg });
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
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create a type mismatch error with enhanced formatting
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
        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (expected_line) |exp_line| {
            if (expected_column) |exp_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = exp_line,
                    .column_start = exp_col,
                    .line_end = exp_line,
                    .column_end = exp_col + @as(u32, @intCast(expected.len)),
                    .label = try std.fmt.allocPrint(allocator, "expected `{s}` because of this", .{expected}),
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        // Add type-specific conversion help
        if (std.mem.eql(u8, expected, "string") and std.mem.eql(u8, found, "number")) {
            try help_list.append(allocator, .{
                .message = "convert the number to a string using toString()",
            });
        } else if (std.mem.eql(u8, expected, "number") and std.mem.eql(u8, found, "string")) {
            try help_list.append(allocator, .{
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
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
        };
    }

    /// Create a redefined variable error with enhanced formatting
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

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);
        try help_list.append(allocator, .{ .message = "choose a different name for this variable" });
        try help_list.append(allocator, .{ .message = "or remove the previous definition if no longer needed" });

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
            .help = try help_list.toOwnedSlice(allocator),
        };
    }

    /// Create a wrong argument count error with enhanced formatting
    pub fn wrongArgumentCount(
        function_name: []const u8,
        expected: u32,
        actual: u32,
        call_line: u32,
        call_column: u32,
        call_length: u32,
        def_line: ?u32,
        def_column: ?u32,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (def_line) |d_line| {
            if (def_column) |d_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = d_line,
                    .column_start = d_col,
                    .line_end = d_line,
                    .column_end = d_col + @as(u32, @intCast(function_name.len)),
                    .label = "defined here",
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        const fix_msg = if (actual > expected)
            try std.fmt.allocPrint(allocator, "remove {} argument{s}", .{ actual - expected, if (actual - expected == 1) "" else "s" })
        else
            try std.fmt.allocPrint(allocator, "add {} argument{s}", .{ expected - actual, if (expected - actual == 1) "" else "s" });

        try help_list.append(allocator, .{ .message = fix_msg });
        try help_list.append(allocator, .{ .message = "check the function signature for the correct number of parameters" });

        const message = if (actual > expected)
            try std.fmt.allocPrint(allocator, "this function takes {d} argument{s} but {d} {s} supplied", .{
                expected,
                if (expected == 1) "" else "s",
                actual,
                if (actual == 1) "was" else "were",
            })
        else
            try std.fmt.allocPrint(allocator, "this function takes {d} argument{s} but {d} {s} supplied", .{
                expected,
                if (expected == 1) "" else "s",
                actual,
                if (actual == 1) "was" else "were",
            });

        return EnhancedErrorInfo{
            .code = "E004",
            .category = "semantic",
            .severity = "error",
            .message = message,
            .error_number = 4,
            .primary_span = .{
                .line_start = call_line,
                .column_start = call_column,
                .line_end = call_line,
                .column_end = call_column + call_length,
                .label = if (actual > expected) "too many arguments" else "not enough arguments",
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
        };
    }

    /// Create an unterminated string error with enhanced formatting
    pub fn unterminatedString(
        line: u32,
        column: u32,
        length: u32,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        try help_list.append(allocator, .{ .message = "add a closing quote at the end of the string" });
        try help_list.append(allocator, .{ .message = "for multi-line strings, use proper escaping or concatenation" });

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);
        try notes.append(allocator, .{ .message = "string literals must be on a single line unless escaped" });

        return EnhancedErrorInfo{
            .code = "E005",
            .category = "syntax",
            .severity = "error",
            .message = "unterminated string literal",
            .error_number = 5,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + length,
                .label = "missing closing quote",
                .is_primary = true,
            },
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create a stack overflow error with enhanced formatting
    pub fn stackOverflow(
        line: u32,
        column: u32,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        try help_list.append(allocator, .{ .message = "check for infinite recursion" });
        try help_list.append(allocator, .{ .message = "ensure recursive calls work toward the base case" });
        try help_list.append(allocator, .{ .message = "consider using iteration instead of recursion" });

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);
        try notes.append(allocator, .{ .message = "this error occurs when too many function calls are nested" });

        return EnhancedErrorInfo{
            .code = "E006",
            .category = "runtime",
            .severity = "error",
            .message = "stack overflow",
            .error_number = 6,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + 1,
                .label = "recursive call without proper base case",
                .is_primary = true,
            },
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create an invalid super usage error with enhanced formatting
    pub fn invalidSuperUsage(
        line: u32,
        column: u32,
        class_def_line: ?u32,
        class_def_column: ?u32,
        class_name: []const u8,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (class_def_line) |c_line| {
            if (class_def_column) |c_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = c_line,
                    .column_start = c_col,
                    .line_end = c_line,
                    .column_end = c_col + @as(u32, @intCast(class_name.len)),
                    .label = try std.fmt.allocPrint(allocator, "`super` cannot be used in classes without inheritance", .{}),
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        try help_list.append(allocator, .{ .message = "remove the `super` call if not needed" });
        try help_list.append(allocator, .{ .message = try std.fmt.allocPrint(allocator, "or make `{s}` inherit from a parent class", .{class_name}) });

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);
        try notes.append(allocator, .{ .message = "`super` can only be used in classes that extend another class" });

        return EnhancedErrorInfo{
            .code = "E007",
            .category = "semantic",
            .severity = "error",
            .message = "invalid use of `super` keyword",
            .error_number = 7,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + 5,
                .label = try std.fmt.allocPrint(allocator, "`super` used here, but `{s}` has no parent class", .{class_name}),
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create a too many locals error with enhanced formatting
    pub fn tooManyLocals(
        line: u32,
        column: u32,
        variable_name: []const u8,
        function_def_line: ?u32,
        function_def_column: ?u32,
        function_name: []const u8,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (function_def_line) |f_line| {
            if (function_def_column) |f_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = f_line,
                    .column_start = f_col,
                    .line_end = f_line,
                    .column_end = f_col + @as(u32, @intCast(function_name.len)),
                    .label = "function defined here",
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        try help_list.append(allocator, .{ .message = "extract some of this logic into helper functions" });
        try help_list.append(allocator, .{ .message = "use arrays or objects to group related data" });

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);
        try notes.append(allocator, .{ .message = "MufiZ currently supports a maximum of 256 local variables per function" });

        return EnhancedErrorInfo{
            .code = "E008",
            .category = "semantic",
            .severity = "error",
            .message = "function has too many local variables",
            .error_number = 8,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + @as(u32, @intCast(variable_name.len)),
                .label = "exceeds maximum of 256 local variables",
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create a method not found error with enhanced formatting
    pub fn methodNotFound(
        method_name: []const u8,
        class_name: []const u8,
        line: u32,
        column: u32,
        class_def_line: ?u32,
        class_def_column: ?u32,
        available_methods: []const []const u8,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        const similar = try findSimilarNamesEnhanced(method_name, available_methods, allocator, 2);
        defer allocator.free(similar);

        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (class_def_line) |c_line| {
            if (class_def_column) |c_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = c_line,
                    .column_start = c_col,
                    .line_end = c_line,
                    .column_end = c_col + @as(u32, @intCast(class_name.len)),
                    .label = "method should be defined here",
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        if (similar.len > 0) {
            const did_you_mean = try std.fmt.allocPrint(allocator, "did you mean `{s}`?", .{similar[0]});
            try help_list.append(allocator, .{ .message = did_you_mean });
        } else {
            try help_list.append(allocator, .{ .message = "check the method name spelling" });
        }

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);

        if (available_methods.len > 0) {
            const methods_list = try std.mem.join(allocator, ", ", available_methods);
            const note_msg = try std.fmt.allocPrint(allocator, "available methods: {s}", .{methods_list});
            try notes.append(allocator, .{ .message = note_msg });
        }

        return EnhancedErrorInfo{
            .code = "E009",
            .category = "semantic",
            .severity = "error",
            .message = try std.fmt.allocPrint(allocator, "no method named `{s}` found for class `{s}`", .{ method_name, class_name }),
            .error_number = 9,
            .primary_span = .{
                .line_start = line,
                .column_start = column,
                .line_end = line,
                .column_end = column + @as(u32, @intCast(method_name.len)),
                .label = if (similar.len > 0)
                    try std.fmt.allocPrint(allocator, "help: a method with a similar name exists: `{s}`", .{similar[0]})
                else
                    "method not found",
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }

    /// Create an index out of bounds error with enhanced formatting
    pub fn indexOutOfBounds(
        index: i32,
        size: i32,
        access_line: u32,
        access_column: u32,
        array_def_line: ?u32,
        array_def_column: ?u32,
        array_name: []const u8,
        source: []const u8,
        file_path: []const u8,
        allocator: Allocator,
    ) !EnhancedErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).initCapacity(allocator, 0) catch unreachable;
        defer secondary_spans.deinit(allocator);

        if (array_def_line) |a_line| {
            if (array_def_column) |a_col| {
                try secondary_spans.append(allocator, .{
                    .line_start = a_line,
                    .column_start = a_col,
                    .line_end = a_line,
                    .column_end = a_col + @as(u32, @intCast(array_name.len)),
                    .label = try std.fmt.allocPrint(allocator, "vector has {d} elements (indices 0-{d})", .{ size, size - 1 }),
                    .is_primary = false,
                });
            }
        }

        var help_list = std.ArrayList(ErrorHelp).initCapacity(allocator, 0) catch unreachable;
        defer help_list.deinit(allocator);

        try help_list.append(allocator, .{ .message = try std.fmt.allocPrint(allocator, "check the index is within bounds before accessing", .{}) });
        try help_list.append(allocator, .{ .message = try std.fmt.allocPrint(allocator, "use: if (index < {s}.length()) {{ ... }}", .{array_name}) });

        var notes = std.ArrayList(ErrorNote).initCapacity(allocator, 0) catch unreachable;
        defer notes.deinit(allocator);

        const valid_indices = if (size == 0)
            try std.fmt.allocPrint(allocator, "vector `{s}` is empty, no valid indices", .{array_name})
        else if (size == 1)
            try std.fmt.allocPrint(allocator, "vector `{s}` has length {d}, so the only valid index is 0", .{ array_name, size })
        else
            try std.fmt.allocPrint(allocator, "vector `{s}` has length {d}, so valid indices are 0 through {d}", .{ array_name, size, size - 1 });

        try notes.append(allocator, .{ .message = valid_indices });

        return EnhancedErrorInfo{
            .code = "E010",
            .category = "runtime",
            .severity = "error",
            .message = try std.fmt.allocPrint(allocator, "index out of bounds: the index {d} is out of bounds for vector of length {d}", .{ index, size }),
            .error_number = 10,
            .primary_span = .{
                .line_start = access_line,
                .column_start = access_column,
                .line_end = access_line,
                .column_end = access_column + 1,
                .label = try std.fmt.allocPrint(allocator, "index {d} is too large", .{index}),
                .is_primary = true,
            },
            .secondary_spans = try secondary_spans.toOwnedSlice(allocator),
            .source_code = source,
            .file_path = file_path,
            .help = try help_list.toOwnedSlice(allocator),
            .notes = try notes.toOwnedSlice(allocator),
        };
    }
};

// ============================================================================
// PHASE 3: JSON SERIALIZATION FOR LSP/IDE INTEGRATION
// ============================================================================

/// JSON serializer for LSP diagnostic output
pub const JsonDiagnosticSerializer = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) JsonDiagnosticSerializer {
        return .{ .allocator = allocator };
    }

    /// Serialize an EnhancedErrorInfo to JSON format for LSP
    pub fn serializeError(self: *JsonDiagnosticSerializer, error_info: EnhancedErrorInfo) ![]const u8 {
        var buffer: std.ArrayList(u8) = .{};
        try buffer.ensureTotalCapacity(self.allocator, 0);
        errdefer buffer.deinit(self.allocator);
        const writer = buffer.writer(self.allocator);

        try writer.writeAll("{");

        // Code
        try writer.print("\"code\":\"{s}\",", .{error_info.code});

        // Message
        try writer.writeAll("\"message\":\"");
        try self.writeEscapedString(writer, error_info.message);
        try writer.writeAll("\",");

        // Severity
        try writer.print("\"severity\":\"{s}\",", .{error_info.severity});

        // Category
        try writer.print("\"category\":\"{s}\",", .{error_info.category});

        // Source file
        if (error_info.file_path) |path| {
            try writer.writeAll("\"source\":\"");
            try self.writeEscapedString(writer, path);
            try writer.writeAll("\",");
        }

        // Primary span
        try writer.writeAll("\"range\":{");
        try writer.print("\"start\":{{\"line\":{d},\"character\":{d}}},", .{
            error_info.primary_span.line_start - 1, // LSP is 0-indexed
            error_info.primary_span.column_start - 1,
        });
        try writer.print("\"end\":{{\"line\":{d},\"character\":{d}}}", .{
            error_info.primary_span.line_end - 1,
            error_info.primary_span.column_end - 1,
        });
        try writer.writeAll("},");

        // Related information (secondary spans)
        if (error_info.secondary_spans.len > 0) {
            try writer.writeAll("\"relatedInformation\":[");
            for (error_info.secondary_spans, 0..) |span, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll("{");
                try writer.writeAll("\"location\":{");
                if (error_info.file_path) |path| {
                    try writer.writeAll("\"uri\":\"file://");
                    try self.writeEscapedString(writer, path);
                    try writer.writeAll("\",");
                }
                try writer.writeAll("\"range\":{");
                try writer.print("\"start\":{{\"line\":{d},\"character\":{d}}},", .{
                    span.line_start - 1,
                    span.column_start - 1,
                });
                try writer.print("\"end\":{{\"line\":{d},\"character\":{d}}}", .{
                    span.line_end - 1,
                    span.column_end - 1,
                });
                try writer.writeAll("}},");
                try writer.writeAll("\"message\":\"");
                if (span.label) |label| {
                    try self.writeEscapedString(writer, label);
                }
                try writer.writeAll("\"}");
            }
            try writer.writeAll("],");
        }

        // Code actions (help with suggestions)
        if (error_info.help.len > 0) {
            try writer.writeAll("\"codeActions\":[");
            for (error_info.help, 0..) |help_item, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll("{\"title\":\"");
                try self.writeEscapedString(writer, help_item.message);
                try writer.writeAll("\"");

                if (help_item.code_suggestion) |suggestion| {
                    try writer.writeAll(",\"edit\":{\"changes\":[{");
                    try writer.writeAll("\"range\":{");
                    try writer.print("\"start\":{{\"line\":{d},\"character\":{d}}},", .{
                        suggestion.span.line_start - 1,
                        suggestion.span.column_start - 1,
                    });
                    try writer.print("\"end\":{{\"line\":{d},\"character\":{d}}}", .{
                        suggestion.span.line_end - 1,
                        suggestion.span.column_end - 1,
                    });
                    try writer.writeAll("},\"newText\":\"");
                    try self.writeEscapedString(writer, suggestion.replacement);
                    try writer.writeAll("\"}]}");
                }
                try writer.writeAll("}");
            }
            try writer.writeAll("],");
        }

        // Notes
        if (error_info.notes.len > 0) {
            try writer.writeAll("\"notes\":[");
            for (error_info.notes, 0..) |note, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll("\"");
                try self.writeEscapedString(writer, note.message);
                try writer.writeAll("\"");
            }
            try writer.writeAll("]");
        } else {
            // Remove trailing comma if no notes
            const len = buffer.items.len;
            if (len > 0 and buffer.items[len - 1] == ',') {
                try buffer.resize(self.allocator, len - 1);
            }
        }

        try writer.writeAll("}");
        return try buffer.toOwnedSlice(self.allocator);
    }

    /// Serialize multiple errors as a JSON array
    pub fn serializeErrors(self: *JsonDiagnosticSerializer, errors: []const EnhancedErrorInfo) ![]const u8 {
        var buffer: std.ArrayList(u8) = .{};
        try buffer.ensureTotalCapacity(self.allocator, 0);
        errdefer buffer.deinit(self.allocator);
        const writer = buffer.writer(self.allocator);

        try writer.writeAll("{\"diagnostics\":[");
        for (errors, 0..) |error_info, i| {
            if (i > 0) try writer.writeAll(",");
            const json = try self.serializeError(error_info);
            defer self.allocator.free(json);
            try writer.writeAll(json);
        }
        try writer.writeAll("]}");

        return try buffer.toOwnedSlice(self.allocator);
    }

    fn writeEscapedString(self: *JsonDiagnosticSerializer, writer: anytype, str: []const u8) !void {
        _ = self;
        for (str) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
    }
};

// ============================================================================
// PHASE 3: COMPILER INTEGRATION HELPERS
// ============================================================================

/// Helper functions to easily integrate enhanced errors into the compiler
pub const CompilerIntegration = struct {
    /// Convert a token position to error span
    pub fn tokenToSpan(token_line: u32, token_column: u32, token_length: u32) ErrorSpan {
        return .{
            .line_start = token_line,
            .column_start = token_column,
            .line_end = token_line,
            .column_end = token_column + token_length,
            .is_primary = true,
        };
    }

    /// Quick helper to report undefined variable from compiler
    pub fn reportUndefinedVariable(
        manager: *ErrorManager,
        name: []const u8,
        line: u32,
        column: u32,
        length: u32,
        available_vars: []const []const u8,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.undefinedVariable(
            name,
            line,
            column,
            length,
            available_vars,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }

    /// Quick helper to report type mismatch from compiler
    pub fn reportTypeMismatch(
        manager: *ErrorManager,
        expected: []const u8,
        found: []const u8,
        expr_line: u32,
        expr_column: u32,
        expr_length: u32,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.typeMismatch(
            expected,
            found,
            expr_line,
            expr_column,
            expr_length,
            null,
            null,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }

    /// Quick helper to report redefined variable from compiler
    pub fn reportRedefinedVariable(
        manager: *ErrorManager,
        name: []const u8,
        current_line: u32,
        current_column: u32,
        current_length: u32,
        previous_line: u32,
        previous_column: u32,
        previous_length: u32,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.redefinedVariable(
            name,
            current_line,
            current_column,
            current_length,
            previous_line,
            previous_column,
            previous_length,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }

    /// Quick helper to report wrong argument count from compiler
    pub fn reportWrongArgumentCount(
        manager: *ErrorManager,
        function_name: []const u8,
        expected: u32,
        actual: u32,
        call_line: u32,
        call_column: u32,
        call_length: u32,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.wrongArgumentCount(
            function_name,
            expected,
            actual,
            call_line,
            call_column,
            call_length,
            null,
            null,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }

    /// Quick helper to report too many locals from compiler
    pub fn reportTooManyLocals(
        manager: *ErrorManager,
        variable_name: []const u8,
        line: u32,
        column: u32,
        function_name: []const u8,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.tooManyLocals(
            line,
            column,
            variable_name,
            null,
            null,
            function_name,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }

    /// Quick helper to report method not found from compiler
    pub fn reportMethodNotFound(
        manager: *ErrorManager,
        method_name: []const u8,
        class_name: []const u8,
        line: u32,
        column: u32,
        available_methods: []const []const u8,
        source: []const u8,
        file_path: []const u8,
    ) !void {
        const error_info = try EnhancedTemplates.methodNotFound(
            method_name,
            class_name,
            line,
            column,
            null,
            null,
            available_methods,
            source,
            file_path,
            manager.allocator,
        );
        manager.reportErrorEnhanced(error_info);
    }
};

// ============================================================================
// PHASE 3: ERROR EXPLANATION SYSTEM
// ============================================================================

/// System for providing detailed error explanations via `--explain E###`
pub const ErrorExplainer = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) ErrorExplainer {
        return .{ .allocator = allocator };
    }

    /// Get detailed explanation for an error code
    pub fn explain(self: *ErrorExplainer, error_code: []const u8) ![]const u8 {
        _ = self;

        // Map error codes to explanations
        if (std.mem.eql(u8, error_code, "E001")) {
            return getE001Explanation();
        } else if (std.mem.eql(u8, error_code, "E002")) {
            return getE002Explanation();
        } else if (std.mem.eql(u8, error_code, "E003")) {
            return getE003Explanation();
        } else if (std.mem.eql(u8, error_code, "E004")) {
            return getE004Explanation();
        } else if (std.mem.eql(u8, error_code, "E005")) {
            return getE005Explanation();
        } else if (std.mem.eql(u8, error_code, "E006")) {
            return getE006Explanation();
        } else if (std.mem.eql(u8, error_code, "E007")) {
            return getE007Explanation();
        } else if (std.mem.eql(u8, error_code, "E008")) {
            return getE008Explanation();
        } else if (std.mem.eql(u8, error_code, "E009")) {
            return getE009Explanation();
        } else if (std.mem.eql(u8, error_code, "E010")) {
            return getE010Explanation();
        }

        return "Error code not found. Available codes: E001-E010";
    }

    fn getE001Explanation() []const u8 {
        return 
        \\E001: Undefined Variable
        \\
        \\This error occurs when you try to use a variable that hasn't been declared
        \\or is not in the current scope.
        \\
        \\Example of erroneous code:
        \\
        \\  var x = 10;
        \\  print(y);  // Error: y is not defined
        \\
        \\To fix this error:
        \\
        \\1. Declare the variable before using it:
        \\   var y = 20;
        \\   print(y);
        \\
        \\2. Check for typos in the variable name:
        \\   var value = 10;
        \\   print(value);  // Not 'vlaue' or 'valu'
        \\
        \\3. Ensure the variable is in scope:
        \\   if (true) {
        \\       var local = 5;
        \\   }
        \\   // local is not accessible here
        \\
        \\The compiler will suggest similar variable names if it finds any close matches.
        ;
    }

    fn getE002Explanation() []const u8 {
        return 
        \\E002: Type Mismatch
        \\
        \\This error occurs when an expression's type doesn't match what was expected.
        \\
        \\Example of erroneous code:
        \\
        \\  var x: number = "hello";  // Error: expected number, found string
        \\
        \\Common causes:
        \\
        \\1. Assigning wrong type to a variable
        \\2. Passing wrong type to a function
        \\3. Returning wrong type from a function
        \\4. Using incompatible types in operations
        \\
        \\To fix this error:
        \\
        \\1. Use the correct type:
        \\   var x: number = 42;
        \\
        \\2. Convert between types explicitly:
        \\   var x: string = toString(42);
        \\   var y: number = parseInt("42");
        \\
        \\3. Check function signatures for expected types
        ;
    }

    fn getE003Explanation() []const u8 {
        return 
        \\E003: Redefined Variable
        \\
        \\This error occurs when you try to declare a variable with a name that's
        \\already been used in the same scope.
        \\
        \\Example of erroneous code:
        \\
        \\  var x = 10;
        \\  var x = 20;  // Error: x is already defined
        \\
        \\To fix this error:
        \\
        \\1. Use a different name:
        \\   var x = 10;
        \\   var y = 20;
        \\
        \\2. Reassign instead of redeclaring:
        \\   var x = 10;
        \\   x = 20;  // OK: reassignment
        \\
        \\3. Use const if the value shouldn't change:
        \\   const x = 10;
        \\   // x = 20;  // Would be an error
        \\
        \\Note: Variables in different scopes can have the same name:
        \\
        \\  var x = 10;
        \\  if (true) {
        \\      var x = 20;  // OK: different scope
        \\  }
        ;
    }

    fn getE004Explanation() []const u8 {
        return 
        \\E004: Wrong Argument Count
        \\
        \\This error occurs when you call a function with the wrong number of arguments.
        \\
        \\Example of erroneous code:
        \\
        \\  fun add(a, b) {
        \\      return a + b;
        \\  }
        \\
        \\  add(1, 2, 3);  // Error: expected 2 arguments, got 3
        \\  add(1);        // Error: expected 2 arguments, got 1
        \\
        \\To fix this error:
        \\
        \\1. Provide the correct number of arguments:
        \\   add(1, 2);  // OK
        \\
        \\2. Check the function definition for parameter count
        \\
        \\3. Consider using default parameters or variadic arguments if the
        \\   function should accept varying numbers of arguments
        \\
        \\4. If you need different argument counts, consider function overloading
        \\   or optional parameters (if supported)
        ;
    }

    fn getE005Explanation() []const u8 {
        return 
        \\E005: Unterminated String
        \\
        \\This error occurs when a string literal is not properly closed with a
        \\matching quote.
        \\
        \\Example of erroneous code:
        \\
        \\  var message = "Hello, world;  // Error: missing closing quote
        \\
        \\To fix this error:
        \\
        \\1. Add the closing quote:
        \\   var message = "Hello, world";
        \\
        \\2. For multi-line strings, use proper escaping:
        \\   var message = "Hello,\n" +
        \\                 "world";
        \\
        \\3. Check for unescaped quotes within the string:
        \\   var message = "He said \"Hello\"";  // Escape inner quotes
        \\
        \\4. Ensure you're using matching quote types:
        \\   var message = "Hello";  // Both double quotes
        \\   var other = 'Hello';    // Both single quotes (if supported)
        ;
    }

    fn getE006Explanation() []const u8 {
        return 
        \\E006: Stack Overflow
        \\
        \\This error occurs when there are too many nested function calls, usually
        \\due to infinite recursion.
        \\
        \\Example of erroneous code:
        \\
        \\  fun factorial(n) {
        \\      return n * factorial(n - 1);  // Error: no base case!
        \\  }
        \\
        \\To fix this error:
        \\
        \\1. Add a base case to stop recursion:
        \\   fun factorial(n) {
        \\       if (n <= 1) return 1;  // Base case
        \\       return n * factorial(n - 1);
        \\   }
        \\
        \\2. Ensure recursive calls work toward the base case:
        \\   fun countdown(n) {
        \\       if (n <= 0) return;
        \\       print(n);
        \\       countdown(n - 1);  // Decreasing toward base case
        \\   }
        \\
        \\3. Consider using iteration instead:
        \\   fun factorial(n) {
        \\       var result = 1;
        \\       for (var i = 2; i <= n; i = i + 1) {
        \\           result = result * i;
        \\       }
        \\       return result;
        \\   }
        ;
    }

    fn getE007Explanation() []const u8 {
        return 
        \\E007: Invalid Super Usage
        \\
        \\This error occurs when you use the `super` keyword in a class that doesn't
        \\inherit from another class.
        \\
        \\Example of erroneous code:
        \\
        \\  class MyClass {
        \\      init() {
        \\          super.init();  // Error: MyClass has no superclass
        \\      }
        \\  }
        \\
        \\To fix this error:
        \\
        \\1. Make the class inherit from a parent class:
        \\   class MyClass < ParentClass {
        \\       init() {
        \\           super.init();  // OK: MyClass extends ParentClass
        \\       }
        \\   }
        \\
        \\2. Remove the super call if not needed:
        \\   class MyClass {
        \\       init() {
        \\           // Initialize without calling super
        \\       }
        \\   }
        \\
        \\3. Use `super` only in methods of derived classes to access parent
        \\   class methods or constructor
        ;
    }

    fn getE008Explanation() []const u8 {
        return 
        \\E008: Too Many Locals
        \\
        \\This error occurs when a function has more than the maximum allowed
        \\number of local variables (currently 256).
        \\
        \\Example of erroneous code:
        \\
        \\  fun bigFunction() {
        \\      var v1 = 1;
        \\      var v2 = 2;
        \\      // ... 254 more variables ...
        \\      var v257 = 257;  // Error: too many locals
        \\  }
        \\
        \\To fix this error:
        \\
        \\1. Refactor into smaller functions:
        \\   fun helper1() { /* some variables */ }
        \\   fun helper2() { /* more variables */ }
        \\   fun bigFunction() {
        \\       helper1();
        \\       helper2();
        \\   }
        \\
        \\2. Use arrays or objects to group related data:
        \\   var data = [val1, val2, val3, ...];
        \\   var config = { opt1: v1, opt2: v2, ... };
        \\
        \\3. Review if all variables are necessary - reduce temporary variables
        \\
        \\4. Consider restructuring your algorithm to use less local state
        ;
    }

    fn getE009Explanation() []const u8 {
        return 
        \\E009: Method Not Found
        \\
        \\This error occurs when you try to call a method that doesn't exist on a
        \\class or object.
        \\
        \\Example of erroneous code:
        \\
        \\  class MyClass {
        \\      greet() {
        \\          print("Hello");
        \\      }
        \\  }
        \\
        \\  var obj = MyClass();
        \\  obj.goodbye();  // Error: method 'goodbye' not found
        \\
        \\To fix this error:
        \\
        \\1. Check the spelling of the method name:
        \\   obj.greet();  // Correct method name
        \\
        \\2. Define the method if it's missing:
        \\   class MyClass {
        \\       greet() { print("Hello"); }
        \\       goodbye() { print("Goodbye"); }
        \\   }
        \\
        \\3. Verify the object type - make sure it's an instance of the expected class
        \\
        \\4. Check if the method is inherited from a parent class
        \\
        \\The compiler will suggest similar method names if available.
        ;
    }

    fn getE010Explanation() []const u8 {
        return 
        \\E010: Index Out of Bounds
        \\
        \\This error occurs when you try to access an array/vector element at an
        \\index that doesn't exist.
        \\
        \\Example of erroneous code:
        \\
        \\  var items = [1, 2, 3];
        \\  print(items[5]);  // Error: index 5 is out of bounds (length is 3)
        \\
        \\To fix this error:
        \\
        \\1. Check the index is within bounds:
        \\   if (index < items.length()) {
        \\       print(items[index]);
        \\   }
        \\
        \\2. Use valid indices (0 to length-1):
        \\   print(items[0]);  // First element
        \\   print(items[2]);  // Last element
        \\
        \\3. Be careful with loops:
        \\   for (var i = 0; i < items.length(); i = i + 1) {
        \\       print(items[i]);  // Use < not <=
        \\   }
        \\
        \\4. Handle empty arrays:
        \\   if (items.length() > 0) {
        \\       print(items[0]);
        \\   }
        \\
        \\Remember: Array indices in MufiZ are 0-based, meaning the first element
        \\is at index 0, and the last element is at index length-1.
        ;
    }

    /// Print explanation to stdout with formatting
    pub fn printExplanation(self: *ErrorExplainer, error_code: []const u8) !void {
        const explanation = try self.explain(error_code);
        print("\n{s}\n\n", .{explanation});
    }

    /// Check if an error code is valid
    pub fn isValidErrorCode(error_code: []const u8) bool {
        const valid_codes = [_][]const u8{
            "E001", "E002", "E003", "E004", "E005",
            "E006", "E007", "E008", "E009", "E010",
        };

        for (valid_codes) |code| {
            if (std.mem.eql(u8, error_code, code)) {
                return true;
            }
        }
        return false;
    }
};
