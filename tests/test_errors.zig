const std = @import("std");
const testing = std.testing;
const errors = @import("../src/errors.zig");
const compiler = @import("../src/compiler.zig");
const vm = @import("../src/vm.zig");

test "ErrorManager initialization and basic functionality" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var errorManager = errors.ErrorManager.init(allocator);
    defer errorManager.deinit();
    
    // Test initial state
    try testing.expect(!errorManager.hasError());
    try testing.expect(!errorManager.panic_mode);
    
    // Test error reporting
    const errorInfo = errors.ErrorInfo{
        .code = .UNDEFINED_VARIABLE,
        .category = .SEMANTIC,
        .severity = .ERROR,
        .line = 10,
        .column = 5,
        .length = 8,
        .message = "Undefined variable 'testVar'",
        .suggestions = &[_]errors.ErrorSuggestion{
            .{ .message = "Declare the variable before using it" },
        },
    };
    
    errorManager.reportError(errorInfo);
    
    try testing.expect(errorManager.hasError());
    try testing.expect(errorManager.panic_mode);
    try testing.expect(errorManager.errors.items.len == 1);
}

test "ErrorTemplates - undefined variable with suggestions" {
    const similar_names = [_][]const u8{ "userName", "userInfo" };
    const errorInfo = errors.ErrorTemplates.undefinedVariable("usrName", &similar_names);
    
    try testing.expect(errorInfo.code == .UNDEFINED_VARIABLE);
    try testing.expect(errorInfo.category == .SEMANTIC);
    try testing.expect(errorInfo.severity == .ERROR);
    try testing.expect(errorInfo.suggestions.len > 0);
}

test "ErrorTemplates - wrong argument count" {
    const errorInfo = errors.ErrorTemplates.wrongArgumentCount("add", 2, 1);
    
    try testing.expect(errorInfo.code == .WRONG_ARGUMENT_COUNT);
    try testing.expect(errorInfo.category == .SEMANTIC);
    try testing.expect(errorInfo.severity == .ERROR);
    try testing.expect(errorInfo.suggestions.len >= 2);
}

test "ErrorTemplates - stack overflow" {
    const errorInfo = errors.ErrorTemplates.stackOverflow();
    
    try testing.expect(errorInfo.code == .STACK_OVERFLOW);
    try testing.expect(errorInfo.category == .RUNTIME);
    try testing.expect(errorInfo.severity == .ERROR);
    
    // Check that suggestions contain recursion-related advice
    var hasRecursionSuggestion = false;
    for (errorInfo.suggestions) |suggestion| {
        if (std.mem.indexOf(u8, suggestion.message, "recursion") != null) {
            hasRecursionSuggestion = true;
            break;
        }
    }
    try testing.expect(hasRecursionSuggestion);
}

test "ErrorTemplates - index out of bounds" {
    const errorInfo = errors.ErrorTemplates.indexOutOfBounds(5, 3);
    
    try testing.expect(errorInfo.code == .INDEX_OUT_OF_BOUNDS);
    try testing.expect(errorInfo.category == .RUNTIME);
    try testing.expect(errorInfo.severity == .ERROR);
    