const std = @import("std");
const scanner_mod = @import("scanner");

// Re-export scanner for convenience  
const scanner = scanner_mod;

pub fn main() !void {
    std.debug.print("\n=================================\n", .{});
    std.debug.print("MufiZ Scanner Benchmark Suite\n", .{});
    std.debug.print("=================================\n\n", .{});
    
    benchmarkKeywords();
    benchmarkWhitespace();
    benchmarkIdentifiers();
    benchmarkNumbers();
    benchmarkStrings();
    benchmarkRealWorld();
    
    std.debug.print("\n=================================\n", .{});
    std.debug.print("Benchmark Complete\n", .{});
    std.debug.print("=================================\n", .{});
}

fn benchmarkKeywords() void {
    const source = "fun if else while for return class var let const and or";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 100_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Keywords:     {d:>8.2}μs per scan\n", .{per_scan});
}

fn benchmarkWhitespace() void {
    const source = 
        \\   
        \\// single line comment
        \\
        \\fun test() {
        \\    /# multi-line 
        \\       comment #/
        \\    return 42;
        \\}
    ;
    
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 100_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Whitespace:   {d:>8.2}μs per scan\n", .{per_scan});
}

fn benchmarkIdentifiers() void {
    const source = "identifier someVar anotherIdentifier veryLongIdentifierName x y z";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 100_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Identifiers:  {d:>8.2}μs per scan\n", .{per_scan});
}

fn benchmarkNumbers() void {
    const source = "42 3.14159 100 0.5 999 123.456";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 100_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Numbers:      {d:>8.2}μs per scan\n", .{per_scan});
}

fn benchmarkStrings() void {
    const source = "\"hello world\" \"test\" \"another string\"";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 100_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Strings:      {d:>8.2}μs per scan\n", .{per_scan});
}

fn benchmarkRealWorld() void {
    const source = 
        \\fun fibonacci(n) {
        \\    if (n <= 1) return n;
        \\    return fibonacci(n - 1) + fibonacci(n - 2);
        \\}
        \\
        \\fun main() {
        \\    var i = 0;
        \\    while (i < 10) {
        \\        print(fibonacci(i));
        \\        i = i + 1;
        \\    }
        \\}
    ;
    
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    
    var timer = std.time.Timer.start() catch return;
    const iterations: u32 = 50_000;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        scanner.init_scanner(&buf);
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;
    std.debug.print("Real-world:   {d:>8.2}μs per scan\n", .{per_scan});
}
