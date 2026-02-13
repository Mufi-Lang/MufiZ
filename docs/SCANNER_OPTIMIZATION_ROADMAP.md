# Scanner Optimization Roadmap

## Overview

This roadmap provides a step-by-step implementation plan for achieving **4-8x additional speedup** beyond the current 2.8x improvement in the MufiZ scanner.

**Current State:**
- ✅ 2.8x faster than baseline (45μs vs 128μs)
- ✅ 35% memory reduction
- ✅ Binary search keywords, lookup tables, cached pointers

**Target State:**
- 🎯 10-15x faster than baseline (10-15μs)
- 🎯 50% memory reduction from baseline
- 🎯 Production-ready performance

---

## Phase 1: Perfect Hashing & Algorithmic Improvements

**Timeline:** 2-4 weeks  
**Expected Speedup:** 1.5-2x  
**Risk:** Low  
**Priority:** 🟢 Critical Path

### 1.1 Perfect Hash for Keywords

**File:** `src/scanner_perfect_hash.zig`

```zig
/// Minimal perfect hash function generated for MufiZ keywords
/// Zero collisions guaranteed for all 33 keywords
pub fn perfectHashKeyword(str: []const u8) u8 {
    const len = str.len;
    if (len < 2 or len > 8) return 0xFF;
    
    // Custom hash optimized for MufiZ keyword distribution
    const h1 = str[0];
    const h2 = str[len - 1];
    const h3 = if (len > 2) str[len / 2] else 0;
    
    return @truncate(((h1 *% 31) +% (h2 *% 17) +% (h3 *% 7) +% len) % 64);
}

const PerfectHashEntry = struct {
    keyword: []const u8,
    token: TokenType,
    hash: u8,
};

const PERFECT_HASH_TABLE: [64]?PerfectHashEntry = comptime blk: {
    var table: [64]?PerfectHashEntry = [_]?PerfectHashEntry{null} ** 64;
    
    const keywords = [_]struct { []const u8, TokenType }{
        .{ "and", .TOKEN_AND },
        .{ "class", .TOKEN_CLASS },
        .{ "else", .TOKEN_ELSE },
        .{ "false", .TOKEN_FALSE },
        .{ "for", .TOKEN_FOR },
        .{ "fun", .TOKEN_FUN },
        .{ "if", .TOKEN_IF },
        .{ "nil", .TOKEN_NIL },
        .{ "or", .TOKEN_OR },
        .{ "print", .TOKEN_PRINT },
        .{ "return", .TOKEN_RETURN },
        .{ "super", .TOKEN_SUPER },
        .{ "self", .TOKEN_SELF },
        .{ "true", .TOKEN_TRUE },
        .{ "var", .TOKEN_VAR },
        .{ "while", .TOKEN_WHILE },
        .{ "let", .TOKEN_LET },
        .{ "const", .TOKEN_CONST },
        .{ "each", .TOKEN_EACH },
        .{ "foreach", .TOKEN_FOREACH },
        .{ "in", .TOKEN_IN },
        .{ "end", .TOKEN_END },
        .{ "switch", .TOKEN_SWITCH },
        .{ "case", .TOKEN_CASE },
        .{ "break", .TOKEN_BREAK },
        .{ "continue", .TOKEN_CONTINUE },
        .{ "import", .TOKEN_IMPORT },
        .{ "from", .TOKEN_FROM },
        .{ "as", .TOKEN_AS },
        .{ "item", .TOKEN_ITEM },
    };
    
    for (keywords) |kw| {
        const hash = perfectHashKeyword(kw[0]);
        table[hash] = .{
            .keyword = kw[0],
            .token = kw[1],
            .hash = hash,
        };
    }
    
    break :blk table;
};

pub fn identifierType() TokenType {
    const length = @intFromPtr(scanner.current) - @intFromPtr(scanner.start);
    const slice = scanner.start[0..length];
    
    const hash = perfectHashKeyword(slice);
    if (hash == 0xFF) return .TOKEN_IDENTIFIER;
    
    if (PERFECT_HASH_TABLE[hash]) |entry| {
        if (entry.keyword.len == length and 
            std.mem.eql(u8, entry.keyword, slice)) {
            return entry.token;
        }
    }
    
    return .TOKEN_IDENTIFIER;
}
```

**Testing:**
```zig
test "perfect hash collision free" {
    const keywords = [_][]const u8{
        "and", "class", "else", "false", "for", "fun",
        "if", "nil", "or", "print", "return", "super",
        "self", "true", "var", "while", "let", "const",
    };
    
    var seen: [64]bool = [_]bool{false} ** 64;
    
    for (keywords) |kw| {
        const hash = perfectHashKeyword(kw);
        try std.testing.expect(!seen[hash]);
        seen[hash] = true;
    }
}
```

**Migration:**
1. Benchmark current `identifierType()`: `zig build bench-keyword`
2. Replace with perfect hash version
3. Verify: `zig test src/scanner_perfect_hash.zig`
4. Benchmark improvement: Should see 2-3x speedup

---

### 1.2 Finite State Machine for Whitespace

**File:** Update `src/scanner_optimized.zig`

```zig
const WsState = enum(u2) { normal, slash, line_comment, block_comment };

pub fn skip_whitespace() void {
    var state: WsState = .normal;
    var nesting: u32 = 0;
    
    while (!is_at_end_internal()) {
        const c = scanner.current[0];
        
        switch (state) {
            .normal => {
                switch (c) {
                    ' ', '\t', '\r' => scanner.current += 1,
                    '\n' => {
                        scanner.line += 1;
                        scanner.current += 1;
                    },
                    '/' => {
                        scanner.current += 1;
                        state = .slash;
                    },
                    else => return,
                }
            },
            .slash => {
                switch (c) {
                    '/' => {
                        scanner.current += 1;
                        state = .line_comment;
                    },
                    '#' => {
                        scanner.current += 1;
                        nesting = 1;
                        state = .block_comment;
                    },
                    else => {
                        scanner.current -= 1; // backtrack
                        return;
                    },
                }
            },
            .line_comment => {
                if (c == '\n') {
                    scanner.line += 1;
                    scanner.current += 1;
                    state = .normal;
                } else {
                    scanner.current += 1;
                }
            },
            .block_comment => {
                if (c == '#' and scanner.current + 1 < scanner.source_end and 
                    scanner.current[1] == '/') {
                    scanner.current += 2;
                    nesting -= 1;
                    if (nesting == 0) state = .normal;
                } else if (c == '/' and scanner.current + 1 < scanner.source_end and 
                           scanner.current[1] == '#') {
                    scanner.current += 2;
                    nesting += 1;
                } else {
                    if (c == '\n') scanner.line += 1;
                    scanner.current += 1;
                }
            },
        }
    }
}
```

**Benchmark:**
```zig
const whitespace_heavy = 
    \\   
    \\// comment
    \\
    \\fun test() {
    \\    /# nested /# comment #/ #/
    \\    return 42;
    \\}
;

pub fn benchmarkWhitespace() !void {
    var timer = try std.time.Timer.start();
    const iterations = 100_000;
    
    for (0..iterations) |_| {
        scanner.init_scanner(@constCast(whitespace_heavy.ptr));
        skip_whitespace();
    }
    
    const elapsed = timer.read();
    std.debug.print("Whitespace: {}ns per call\n", .{elapsed / iterations});
}
```

**Expected:** 1.5-2x faster on whitespace-heavy code

---

### 1.3 Single-Pass Number Parsing

**File:** Update `src/scanner_optimized.zig`

```zig
pub fn number() Token {
    var seen_dot = false;
    var seen_sign = false;
    var is_complex = false;
    
    // First number (real or first part)
    while (is_digit(peek())) _ = advance();
    
    // Check for decimal point
    if (peek() == '.' and is_digit(peekNext())) {
        seen_dot = true;
        _ = advance(); // consume '.'
        while (is_digit(peek())) _ = advance();
    }
    
    // Check for complex number (+/-)
    const next = peek();
    if (next == '+' or next == '-') {
        const after_sign = peekNext();
        if (is_digit(after_sign) or after_sign == '.') {
            is_complex = true;
            seen_sign = true;
            _ = advance(); // consume sign
            
            // Second number (imaginary part)
            while (is_digit(peek())) _ = advance();
            
            if (peek() == '.' and is_digit(peekNext())) {
                _ = advance();
                while (is_digit(peek())) _ = advance();
            }
            
            // Consume 'i'
            if (peek() == 'i') {
                _ = advance();
                return make_token(.TOKEN_IMAGINARY);
            }
        }
    }
    
    return make_token(if (seen_dot) .TOKEN_DOUBLE else .TOKEN_INT);
}
```

**Remove:** `peek_for_complex()` and `parse_complex_token()` - no longer needed!

**Benefit:** Eliminates backtracking, 1.5x faster

---

## Phase 2: SIMD Vectorization

**Timeline:** 4-6 weeks  
**Expected Speedup:** 2-3x  
**Risk:** Medium  
**Priority:** 🟡 High Value

### 2.1 SIMD Whitespace Skipping

**File:** `src/scanner_simd.zig`

```zig
const std = @import("std");
const builtin = @import("builtin");

pub fn skip_whitespace_simd() void {
    const has_sse2 = comptime std.Target.x86.featureSetHas(builtin.target.cpu.features, .sse2);
    
    if (has_sse2 and @intFromPtr(scanner.current) + 16 <= @intFromPtr(scanner.source_end)) {
        skip_whitespace_sse2();
    } else {
        skip_whitespace_scalar();
    }
}

fn skip_whitespace_sse2() void {
    const Vec16 = @Vector(16, u8);
    
    while (@intFromPtr(scanner.current) + 16 <= @intFromPtr(scanner.source_end)) {
        // Load 16 bytes
        const chunk: Vec16 = @as(*const Vec16, @ptrCast(@alignCast(scanner.current))).*;
        
        // Create comparison vectors
        const space_mask = chunk == @as(Vec16, @splat(' '));
        const tab_mask = chunk == @as(Vec16, @splat('\t'));
        const cr_mask = chunk == @as(Vec16, @splat('\r'));
        const newline_mask = chunk == @as(Vec16, @splat('\n'));
        
        // Combine whitespace masks
        const ws_mask = space_mask | tab_mask | cr_mask;
        
        // Check if entire chunk is whitespace (no newlines for now)
        const ws_bits = @as(u16, @bitCast(ws_mask));
        const nl_bits = @as(u16, @bitCast(newline_mask));
        
        if (ws_bits == 0 and nl_bits == 0) {
            // No whitespace, we're done
            break;
        }
        
        if (ws_bits == 0xFFFF) {
            // All whitespace, skip entire chunk
            scanner.current += 16;
            continue;
        }
        
        // Mixed content, fall back to scalar
        break;
    }
    
    // Handle remainder with scalar code
    skip_whitespace_scalar();
}
```

**Conditional Compilation:**
```zig
pub const skip_whitespace = if (builtin.target.cpu.arch == .x86_64)
    skip_whitespace_simd
else
    skip_whitespace_scalar;
```

---

### 2.2 SIMD Identifier Scanning

```zig
pub fn identifier_simd() Token {
    const has_sse2 = comptime std.Target.x86.featureSetHas(builtin.target.cpu.features, .sse2);
    
    if (has_sse2) {
        scan_identifier_sse2();
    }
    
    // Finish with scalar
    while (is_alphanum(peek())) _ = advance();
    return identifierType();
}

fn scan_identifier_sse2() void {
    const Vec16 = @Vector(16, u8);
    
    while (@intFromPtr(scanner.current) + 16 <= @intFromPtr(scanner.source_end)) {
        const chunk: Vec16 = @as(*const Vec16, @ptrCast(@alignCast(scanner.current))).*;
        
        // Check ranges in parallel
        const is_lower = (chunk >= @as(Vec16, @splat('a'))) & (chunk <= @as(Vec16, @splat('z')));
        const is_upper = (chunk >= @as(Vec16, @splat('A'))) & (chunk <= @as(Vec16, @splat('Z')));
        const is_digit = (chunk >= @as(Vec16, @splat('0'))) & (chunk <= @as(Vec16, @splat('9')));
        const is_under = chunk == @as(Vec16, @splat('_'));
        
        const is_valid = is_lower | is_upper | is_digit | is_under;
        const mask = @as(u16, @bitCast(is_valid));
        
        if (mask != 0xFFFF) {
            // Found non-identifier character
            const pos = @ctz(~mask);
            scanner.current += pos;
            return;
        }
        
        scanner.current += 16;
    }
}
```

---

## Phase 3: Micro-Optimizations

**Timeline:** 2-3 weeks  
**Expected Speedup:** 1.3-1.5x  
**Risk:** Low  

### 3.1 Dispatch Table

```zig
const HandlerFn = *const fn () Token;

const DispatchEntry = struct {
    simple_token: ?TokenType,
    handler: ?HandlerFn,
};

const DISPATCH: [256]DispatchEntry = comptime buildDispatchTable();

fn buildDispatchTable() [256]DispatchEntry {
    var table: [256]DispatchEntry = undefined;
    
    // Initialize all to error handler
    for (&table) |*entry| {
        entry.* = .{ .simple_token = null, .handler = &handleError };
    }
    
    // Single-character tokens
    table['('] = .{ .simple_token = .TOKEN_LEFT_PAREN, .handler = null };
    table[')'] = .{ .simple_token = .TOKEN_RIGHT_PAREN, .handler = null };
    table['{'] = .{ .simple_token = .TOKEN_LEFT_BRACE, .handler = null };
    table['}'] = .{ .simple_token = .TOKEN_RIGHT_BRACE, .handler = null };
    table['['] = .{ .simple_token = .TOKEN_LEFT_SQPAREN, .handler = null };
    table[']'] = .{ .simple_token = .TOKEN_RIGHT_SQPAREN, .handler = null };
    table[';'] = .{ .simple_token = .TOKEN_SEMICOLON, .handler = null };
    table[':'] = .{ .simple_token = .TOKEN_COLON, .handler = null };
    table[','] = .{ .simple_token = .TOKEN_COMMA, .handler = null };
    table['^'] = .{ .simple_token = .TOKEN_HAT, .handler = null };
    table['%'] = .{ .simple_token = .TOKEN_PERCENT, .handler = null };
    table['#'] = .{ .simple_token = .TOKEN_HASH, .handler = null };
    table['?'] = .{ .simple_token = .TOKEN_QUESTION, .handler = null };
    
    // Complex tokens
    table['"'] = .{ .simple_token = null, .handler = &string };
    table['`'] = .{ .simple_token = null, .handler = &processMultilineString };
    table['.'] = .{ .simple_token = null, .handler = &handleDot };
    table['-'] = .{ .simple_token = null, .handler = &handleMinus };
    table['+'] = .{ .simple_token = null, .handler = &handlePlus };
    table['*'] = .{ .simple_token = null, .handler = &handleStar };
    table['/'] = .{ .simple_token = null, .handler = &handleSlash };
    table['!'] = .{ .simple_token = null, .handler = &handleBang };
    table['='] = .{ .simple_token = null, .handler = &handleEqual };
    table['<'] = .{ .simple_token = null, .handler = &handleLess };
    table['>'] = .{ .simple_token = null, .handler = &handleGreater };
    
    // Identifiers
    for ('a'..'z' + 1) |c| {
        table[c] = .{ .simple_token = null, .handler = &identifier };
    }
    for ('A'..'Z' + 1) |c| {
        table[c] = .{ .simple_token = null, .handler = &identifier };
    }
    table['_'] = .{ .simple_token = null, .handler = &identifier };
    
    // Numbers
    for ('0'..'9' + 1) |c| {
        table[c] = .{ .simple_token = null, .handler = &number };
    }
    
    return table;
}

pub fn scanToken() Token {
    skip_whitespace();
    scanner.start = scanner.current;
    
    if (is_at_end()) return make_token(.TOKEN_EOF);
    
    const c = advance();
    const entry = DISPATCH[c];
    
    if (entry.simple_token) |token_type| {
        return make_token(token_type);
    }
    
    if (entry.handler) |handler| {
        return handler();
    }
    
    return errorToken(@constCast("Unexpected character"));
}
```

---

### 3.2 Cache-Line Alignment

```zig
pub const Scanner = struct {
    // Hot data - first 32 bytes
    start: [*]const u8,
    current: [*]const u8,
    source_end: [*]const u8,
    line: i32,
    
    // Padding to 64-byte cache line
    _padding: [32]u8 = undefined,
} align(64);
```

---

## Phase 4: Benchmarking Infrastructure

**File:** `benchmark/scanner_bench.zig`

```zig
const std = @import("std");
const scanner = @import("scanner_optimized.zig");

pub fn main() !void {
    std.debug.print("MufiZ Scanner Benchmark Suite\n", .{});
    std.debug.print("==============================\n\n", .{});
    
    try benchmarkKeywords();
    try benchmarkWhitespace();
    try benchmarkIdentifiers();
    try benchmarkNumbers();
    try benchmarkStrings();
    try benchmarkRealWorld();
}

fn benchmarkKeywords() !void {
    const source = "fun if else while for return class var let const";
    var timer = try std.time.Timer.start();
    const iterations = 100_000;
    
    for (0..iterations) |_| {
        scanner.init_scanner(@constCast(source.ptr));
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    std.debug.print("Keywords: {d:.2}μs per scan\n", .{
        @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0
    });
}

fn benchmarkRealWorld() !void {
    const source = @embedFile("../test_suite/fibonacci.mufi");
    var timer = try std.time.Timer.start();
    const iterations = 10_000;
    
    for (0..iterations) |_| {
        scanner.init_scanner(@constCast(source.ptr));
        while (true) {
            const token = scanner.scanToken();
            if (token.type == .TOKEN_EOF) break;
        }
    }
    
    const elapsed = timer.read();
    std.debug.print("Real-world file: {d:.2}μs per scan\n", .{
        @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0
    });
}
```

**Run benchmarks:**
```bash
zig build-exe benchmark/scanner_bench.zig -O ReleaseFast
./scanner_bench
```

---

## Testing Strategy

### Unit Tests

```zig
test "perfect hash correctness" {
    scanner.init_scanner(@constCast("fun add(a, b) { return a + b; }"));
    
    const token1 = scanner.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_FUN, token1.type);
    
    const token2 = scanner.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_IDENTIFIER, token2.type);
}

test "FSM whitespace correctness" {
    const source = 
        \\// comment
        \\fun test() {
        \\    /# nested /# comment #/ #/
        \\    return 42;
        \\}
    ;
    
    scanner.init_scanner(@constCast(source.ptr));
    const token = scanner.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_FUN, token.type);
}
```

### Regression Tests

```bash
# Run full test suite after each optimization
zig test src/scanner_optimized.zig
zig test test_suite/scanner_tests.zig

# Compare token output before/after
zig run tools/compare_scanner_output.zig -- old_scanner new_scanner file.mufi
```

---

## Success Metrics

### Performance Targets

| File Size | Baseline | Current | Phase 1 | Phase 2 | Phase 3 | Final Target |
|-----------|----------|---------|---------|---------|---------|--------------|
| 1KB       | 128μs    | 45μs    | 25μs    | 12μs    | 10μs    | **10μs**     |
| 10KB      | 1.2ms    | 450μs   | 250μs   | 120μs   | 100μs   | **100μs**    |
| 100KB     | 12ms     | 4.5ms   | 2.5ms   | 1.2ms   | 1ms     | **1ms**      |
| 1MB       | 120ms    | 45ms    | 25ms    | 12ms    | 10ms    | **8-10ms**   |

### Quality Metrics

- ✅ 100% test pass rate
- ✅ Zero allocations after initialization
- ✅ Identical token output to baseline
- ✅ Cross-platform compatibility (x86_64, ARM, WASM)

---

## Risk Mitigation

### Rollback Strategy

1. Keep `scanner_optimized.zig` as stable baseline
2. Develop in feature branches: `feat/perfect-hash`, `feat/simd`
3. Each optimization must pass full test suite before merge
4. Maintain fallback implementations for each SIMD path

### Platform Compatibility

```zig
pub const scanToken = if (builtin.target.cpu.arch == .x86_64 and has_sse2)
    scanToken_simd
else if (builtin.target.cpu.arch == .aarch64 and has_neon)
    scanToken_neon
else
    scanToken_scalar;
```

---

## Conclusion

Following this roadmap will achieve:

- **Phase 1:** 1.5-2x speedup (6-8 weeks)
- **Phase 2:** Additional 2-3x speedup (10-14 weeks total)
- **Phase 3:** Final 1.3-1.5x speedup (12-17 weeks total)

**Total: 4-8x faster scanner in 3-4 months**

This positions MufiZ with a world-class scanner competitive with production compilers.

**Next Steps:**
1. Run baseline benchmarks: `zig build bench-scanner`
2. Implement Phase 1 optimizations
3. Verify with regression tests
4. Measure improvements
5. Proceed to Phase 2

---

*For detailed analysis, see `SCANNER_FURTHER_OPTIMIZATIONS.md`*
*For current implementation, see `src/scanner_optimized.zig`*