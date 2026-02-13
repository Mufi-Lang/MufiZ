const std = @import("std");
const parallel = @import("parallel/scanner_parallel.zig");
const scanner = @import("scanner_optimized.zig");
const testing = std.testing;

test "parallel scanner: simple sequential input" {
    const source = "var x = 42;";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_VAR, stream.tokens[0].type);
}

test "parallel scanner: empty input" {
    const source = "";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    try testing.expectEqual(@as(usize, 1), stream.tokens.len);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, stream.tokens[0].type);
}

test "parallel scanner: keywords and identifiers" {
    const source = "fun test() { var x = 10; return x; }";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_FUN, stream.tokens[0].type);
}

test "parallel scanner: large input with multiple chunks" {
    const allocator = testing.allocator;

    // Create a large source file
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer source_list.deinit(allocator);

    // Generate 1000 lines of code
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try source_list.appendSlice(allocator, "fun test");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "() { var x = ");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "; return x; }\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    // Configure for multiple threads with realistic sizes
    const config = parallel.ParallelConfig{
        .num_threads = 4,
        .min_chunk_size = 8192,
        .target_chunk_size = 16384,
        .parallel_threshold = 4096, // Lower for testing
    };

    var stream = try parallel.scanParallel(allocator, source, config);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 1000);
}

test "parallel scanner: strings and escapes" {
    const source =
        \\var greeting = "Hello, World!";
        \\var path = "C:\\Users\\test";
    ;

    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_string = false;
    for (stream.tokens) |token| {
        if (token.type == .TOKEN_STRING) {
            found_string = true;
            break;
        }
    }
    try testing.expect(found_string);
}

test "parallel scanner: numbers" {
    const source = "var a = 42; var b = 3.14; var c = 100;";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var int_count: usize = 0;
    var double_count: usize = 0;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_INT) int_count += 1;
        if (token.type == .TOKEN_DOUBLE) double_count += 1;
    }

    try testing.expect(int_count >= 2);
    try testing.expect(double_count >= 1);
}

test "parallel scanner: comments" {
    const source =
        \\// This is a comment
        \\var x = 10;
        \\/# Multi-line
        \\   comment #/
        \\var y = 20;
    ;

    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    // Comments should be skipped, so we should only have var, identifiers, etc.
    var var_count: usize = 0;
    for (stream.tokens) |token| {
        if (token.type == .TOKEN_VAR) var_count += 1;
    }
    try testing.expectEqual(@as(usize, 2), var_count);
}

test "parallel scanner: operators" {
    const source = "x = a + b - c * d / e;";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_plus = false;
    var found_minus = false;
    var found_star = false;
    var found_slash = false;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_PLUS) found_plus = true;
        if (token.type == .TOKEN_MINUS) found_minus = true;
        if (token.type == .TOKEN_STAR) found_star = true;
        if (token.type == .TOKEN_SLASH) found_slash = true;
    }

    try testing.expect(found_plus);
    try testing.expect(found_minus);
    try testing.expect(found_star);
    try testing.expect(found_slash);
}

test "parallel scanner: control flow" {
    const source =
        \\if (x > 0) {
        \\    print(x);
        \\} else {
        \\    print("negative");
        \\}
    ;

    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_if = false;
    var found_else = false;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_IF) found_if = true;
        if (token.type == .TOKEN_ELSE) found_else = true;
    }

    try testing.expect(found_if);
    try testing.expect(found_else);
}

test "parallel scanner: function definition" {
    const source =
        \\fun fibonacci(n) {
        \\    if (n <= 1) return n;
        \\    return fibonacci(n - 1) + fibonacci(n - 2);
        \\}
    ;

    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_FUN, stream.tokens[0].type);
}

test "parallel scanner: complex expression" {
    const source = "result = (a + b) * (c - d) / (e + f);";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var paren_count: usize = 0;
    for (stream.tokens) |token| {
        if (token.type == .TOKEN_LEFT_PAREN or token.type == .TOKEN_RIGHT_PAREN) {
            paren_count += 1;
        }
    }

    try testing.expect(paren_count >= 6);
}

test "parallel scanner: array syntax" {
    const source = "var arr = [1, 2, 3, 4, 5];";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_left_sq = false;
    var found_right_sq = false;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_LEFT_SQPAREN) found_left_sq = true;
        if (token.type == .TOKEN_RIGHT_SQPAREN) found_right_sq = true;
    }

    try testing.expect(found_left_sq);
    try testing.expect(found_right_sq);
}

test "parallel scanner: specific thread count" {
    const source = "var x = 1; var y = 2; var z = 3;";

    const config = parallel.ParallelConfig{
        .num_threads = 2,
        .min_chunk_size = 10,
        .target_chunk_size = 20,
        .parallel_threshold = 0, // Force parallel even for tiny input
    };

    var stream = try parallel.scanParallel(testing.allocator, source, config);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
}

test "parallel scanner: minimum chunk size enforcement" {
    const source = "var x = 42;";

    const config = parallel.ParallelConfig{
        .num_threads = 10,
        .min_chunk_size = 1024, // Larger than source
        .target_chunk_size = 2048,
        .parallel_threshold = 0, // Would normally skip parallel
    };

    var stream = try parallel.scanParallel(testing.allocator, source, config);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
}

test "parallel scanner: whitespace handling" {
    const source = "   var    x   =   42   ;   ";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    // Whitespace should be skipped
    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_VAR, stream.tokens[0].type);
}

test "parallel scanner: compound operators" {
    const source = "x += 5; y -= 3; z *= 2; w /= 4;";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_plus_equal = false;
    var found_minus_equal = false;
    var found_star_equal = false;
    var found_slash_equal = false;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_PLUS_EQUAL) found_plus_equal = true;
        if (token.type == .TOKEN_MINUS_EQUAL) found_minus_equal = true;
        if (token.type == .TOKEN_STAR_EQUAL) found_star_equal = true;
        if (token.type == .TOKEN_SLASH_EQUAL) found_slash_equal = true;
    }

    try testing.expect(found_plus_equal);
    try testing.expect(found_minus_equal);
    try testing.expect(found_star_equal);
    try testing.expect(found_slash_equal);
}

test "parallel scanner: comparison operators" {
    const source = "a == b; c != d; e < f; g > h; i <= j; k >= l;";
    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    var found_equal_equal = false;
    var found_bang_equal = false;
    var found_less = false;
    var found_greater = false;
    var found_less_equal = false;
    var found_greater_equal = false;

    for (stream.tokens) |token| {
        if (token.type == .TOKEN_EQUAL_EQUAL) found_equal_equal = true;
        if (token.type == .TOKEN_BANG_EQUAL) found_bang_equal = true;
        if (token.type == .TOKEN_LESS) found_less = true;
        if (token.type == .TOKEN_GREATER) found_greater = true;
        if (token.type == .TOKEN_LESS_EQUAL) found_less_equal = true;
        if (token.type == .TOKEN_GREATER_EQUAL) found_greater_equal = true;
    }

    try testing.expect(found_equal_equal);
    try testing.expect(found_bang_equal);
    try testing.expect(found_less);
    try testing.expect(found_greater);
    try testing.expect(found_less_equal);
    try testing.expect(found_greater_equal);
}

test "parallel scanner: real-world program" {
    const source =
        \\fun factorial(n) {
        \\    if (n <= 1) {
        \\        return 1;
        \\    }
        \\    return n * factorial(n - 1);
        \\}
        \\
        \\fun main() {
        \\    var result = factorial(5);
        \\    print(result);
        \\}
    ;

    var stream = try parallel.scan(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 20);

    // Should end with EOF
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, stream.tokens[stream.tokens.len - 1].type);
}

test "parallel scanner: smart scanning for small input" {
    const source = "var x = 42;";

    // Smart scan should choose sequential for small input
    var stream = try parallel.scanSmart(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_VAR, stream.tokens[0].type);
}

test "parallel scanner: sequential only" {
    const source = "fun test() { return 42; }";

    var stream = try parallel.scanSequentialOnly(testing.allocator, source);
    defer stream.deinit();

    try testing.expect(stream.tokens.len > 0);
    try testing.expectEqual(scanner.TokenType.TOKEN_FUN, stream.tokens[0].type);
}

test "parallel scanner: adaptive threshold behavior" {
    // Test that smart scanning works for small inputs (should use sequential)
    const small_source = "var x = 42; var y = 100;";
    var stream1 = try parallel.scanSmart(testing.allocator, small_source);
    defer stream1.deinit();
    try testing.expect(stream1.tokens.len > 0);

    // Test that sequential only works
    var stream2 = try parallel.scanSequentialOnly(testing.allocator, small_source);
    defer stream2.deinit();
    try testing.expect(stream2.tokens.len > 0);
}
