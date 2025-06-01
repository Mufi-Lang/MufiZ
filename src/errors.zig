const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

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
            .errors = std.ArrayList(ErrorInfo).init(allocator),
            .has_error = false,
            .panic_mode = false,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.errors.deinit();
    }
    
    pub fn reportError(self: *Self, info: ErrorInfo) void {
        if (self.panic_mode) return;
        
        self.has_error = true;
        self.panic_mode = true;
        
        self.errors.append(info) catch {
            // Fallback to simple print if we can't store the error
            self.printError(info);
            return;
        };
        
        self.printError(info);
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
    pub fn unexpectedToken(actual: []const u8, expected: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Unexpected token '{s}', expected '{s}'", .{ actual, expected }) catch "Unexpected token";
        
        return ErrorInfo{
            .code = .UNEXPECTED_TOKEN,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(actual.len),
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = std.fmt.allocPrint(std.heap.page_allocator, "Replace '{s}' with '{s}'", .{ actual, expected }) catch "Check syntax" },
            },
        };
    }
    
    pub fn undefinedVariable(name: []const u8, similar_names: []const []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Undefined variable '{s}'", .{name}) catch "Undefined variable";
        
        var suggestions = std.ArrayList(ErrorSuggestion).init(std.heap.page_allocator);
        suggestions.append(.{ .message = "Declare the variable before using it" }) catch {};
        
        if (similar_names.len > 0) {
            const suggestion_msg = std.fmt.allocPrint(std.heap.page_allocator, "Did you mean '{s}'?", .{similar_names[0]}) catch "Check spelling";
            suggestions.append(.{ .message = suggestion_msg }) catch {};
            
            // Add fix suggestion if there's a close match
            const fix_msg = std.fmt.allocPrint(std.heap.page_allocator, "Replace '{s}' with '{s}'", .{ name, similar_names[0] }) catch "Fix variable name";
            suggestions.append(.{ .message = fix_msg }) catch {};
        } else {
            // No similar names found, provide more general suggestions
            suggestions.append(.{ .message = "Check the variable name spelling" }) catch {};
            suggestions.append(.{ .message = "Ensure the variable is in the correct scope" }) catch {};
        }
        
        // Add context-specific suggestions
        if (name.len <= 2) {
            suggestions.append(.{ .message = "Variable names should be descriptive and longer than 2 characters" }) catch {};
        }
        
        suggestions.append(.{ 
            .message = "Example variable declaration", 
            .example = std.fmt.allocPrint(std.heap.page_allocator, "var {s} = value;", .{name}) catch "var myVar = value;" 
        }) catch {};
        
        return ErrorInfo{
            .code = .UNDEFINED_VARIABLE,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(name.len),
            .message = message,
            .suggestions = suggestions.toOwnedSlice() catch &[_]ErrorSuggestion{},
        };
    }
    
    pub fn wrongArgumentCount(function_name: []const u8, expected: u32, actual: u32) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Function '{s}' expects {d} arguments, but {d} were provided", .{ function_name, expected, actual }) catch "Wrong argument count";
        
        const fix_msg = if (actual > expected) 
            std.fmt.allocPrint(std.heap.page_allocator, "Remove {} argument{s}", .{ actual - expected, if (actual - expected == 1) "" else "s" }) catch "Adjust arguments"
        else 
            std.fmt.allocPrint(std.heap.page_allocator, "Add {} argument{s}", .{ expected - actual, if (expected - actual == 1) "" else "s" }) catch "Adjust arguments";
        
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
                .{ 
                    .message = "Use 'super' to call parent class methods",
                    .example = "super.methodName(args)"
                },
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
                .{ 
                    .message = "Limit recursion depth",
                    .example = "if (depth > MAX_DEPTH) return;"
                },
            },
        };
    }
    
    pub fn indexOutOfBounds(index: i32, size: i32) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Index {d} is out of bounds for size {d}", .{ index, size }) catch "Index out of bounds";
        
        return ErrorInfo{
            .code = .INDEX_OUT_OF_BOUNDS,
            .category = .RUNTIME,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = 1,
            .message = message,
            .suggestions = &[_]ErrorSuggestion{
                .{ .message = std.fmt.allocPrint(std.heap.page_allocator, "Valid indices are 0 to {d}", .{size - 1}) catch "Check bounds" },
                .{ .message = "Check array/vector size before accessing elements" },
                .{ 
                    .message = "Use bounds checking",
                    .example = "if (index >= 0 && index < size) { ... }"
                },
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
                .{ 
                    .message = "Use defensive programming",
                    .example = "if (divisor != 0) { result = dividend / divisor; }"
                },
            },
        };
    }
    
    pub fn undefinedMethod(className: []const u8, methodName: []const u8, availableMethods: []const []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Undefined method '{s}' on class '{s}'", .{ methodName, className }) catch "Undefined method";
        
        var suggestions = std.ArrayList(ErrorSuggestion).init(std.heap.page_allocator);
        suggestions.append(.{ .message = "Check the method name spelling" }) catch {};
        
        if (availableMethods.len > 0) {
            const similar = findSimilarNames(methodName, availableMethods, std.heap.page_allocator);
            if (similar.len > 0) {
                const suggestion_msg = std.fmt.allocPrint(std.heap.page_allocator, "Did you mean '{s}'?", .{similar[0]}) catch "Check available methods";
                suggestions.append(.{ .message = suggestion_msg }) catch {};
                
                const fix_msg = std.fmt.allocPrint(std.heap.page_allocator, "Replace '{s}' with '{s}'", .{ methodName, similar[0] }) catch "Fix method name";
                suggestions.append(.{ .message = fix_msg }) catch {};
            } else {
                // Show available methods if no close match
                const methods_list = std.mem.join(std.heap.page_allocator, ", ", availableMethods) catch "method1, method2";
                const available_msg = std.fmt.allocPrint(std.heap.page_allocator, "Available methods: {s}", .{methods_list}) catch "Check available methods";
                suggestions.append(.{ .message = available_msg }) catch {};
            }
        }
        
        suggestions.append(.{ .message = "Ensure the method is defined in the class or its parent classes" }) catch {};
        suggestions.append(.{ 
            .message = "Example method call", 
            .example = std.fmt.allocPrint(std.heap.page_allocator, "obj.{s}()", .{methodName}) catch "obj.method()" 
        }) catch {};
        
        return ErrorInfo{
            .code = .METHOD_NOT_FOUND,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .line = 0,
            .column = 0,
            .length = @intCast(methodName.len),
            .message = message,
            .suggestions = suggestions.toOwnedSlice() catch &[_]ErrorSuggestion{},
        };
    }
    
    pub fn invalidCharacter(char: u8, context: []const u8) ErrorInfo {
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Invalid character '{c}' (ASCII {d}) {s}", .{ char, char, context }) catch "Invalid character";
        
        var suggestions = std.ArrayList(ErrorSuggestion).init(std.heap.page_allocator);
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

// Utility functions for common error patterns
pub fn levenshteinDistance(a: []const u8, b: []const u8) u32 {
    if (a.len == 0) return @intCast(b.len);
    if (b.len == 0) return @intCast(a.len);
    
    var matrix = std.ArrayList(std.ArrayList(u32)).init(std.heap.page_allocator);
    defer {
        for (matrix.items) |row| {
            row.deinit();
        }
        matrix.deinit();
    }
    
    // Initialize matrix
    var i: usize = 0;
    while (i <= a.len) : (i += 1) {
        var row = std.ArrayList(u32).init(std.heap.page_allocator);
        var j: usize = 0;
        while (j <= b.len) : (j += 1) {
            if (i == 0) {
                row.append(@intCast(j)) catch return 999;
            } else if (j == 0) {
                row.append(@intCast(i)) catch return 999;
            } else {
                row.append(0) catch return 999;
            }
        }
        matrix.append(row) catch return 999;
    }
    
    // Fill matrix
    i = 1;
    while (i <= a.len) : (i += 1) {
        var j: usize = 1;
        while (j <= b.len) : (j += 1) {
            const cost: u32 = if (a[i-1] == b[j-1]) 0 else 1;
            const deletion = matrix.items[i-1].items[j] + 1;
            const insertion = matrix.items[i].items[j-1] + 1;
            const substitution = matrix.items[i-1].items[j-1] + cost;
            
            matrix.items[i].items[j] = @min(deletion, @min(insertion, substitution));
        }
    }
    
    return matrix.items[a.len].items[b.len];
}

pub fn findSimilarNames(name: []const u8, candidates: []const []const u8, allocator: Allocator) []const []const u8 {
    var similar = std.ArrayList([]const u8).init(allocator);
    
    for (candidates) |candidate| {
        const distance = levenshteinDistance(name, candidate);
        if (distance <= 2 and distance > 0) { // Allow up to 2 character differences
            similar.append(candidate) catch break;
        }
    }
    
    return similar.toOwnedSlice() catch &[_][]const u8{};
}