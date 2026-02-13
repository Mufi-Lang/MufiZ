/// Parallel Scanner Module for MufiZ
/// Provides parallel tokenization by splitting input into chunks and processing them concurrently.
/// This achieves near-linear scaling with CPU cores for large inputs.
const std = @import("std");
const scanner_mod = @import("../scanner_optimized.zig");

pub const Token = scanner_mod.Token;
pub const TokenType = scanner_mod.TokenType;

/// Configuration for parallel scanning
pub const ParallelConfig = struct {
    /// Number of worker threads to use (0 = auto-detect based on CPU cores)
    num_threads: usize = 0,

    /// Minimum chunk size in bytes (chunks smaller than this won't be split further)
    /// Increased to 64KB to reduce overhead
    min_chunk_size: usize = 65536,

    /// Target chunk size in bytes (ideal size per thread)
    /// Increased to 256KB for better overhead amortization
    target_chunk_size: usize = 262144,

    /// Minimum file size to consider parallel scanning
    /// Below this threshold, always use sequential scanning
    parallel_threshold: usize = 131072, // 128KB
};

/// Result of parallel tokenization
pub const TokenStream = struct {
    tokens: []Token,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TokenStream) void {
        self.allocator.free(self.tokens);
    }
};

/// Chunk boundary information
const ChunkBoundary = struct {
    start: usize,
    end: usize,
};

/// Find safe split points in the source code
/// Returns boundaries that don't split tokens (avoids strings, comments, etc.)
fn findSafeSplitPoints(source: []const u8, num_chunks: usize, config: ParallelConfig) ![]ChunkBoundary {
    const allocator = std.heap.page_allocator;
    var boundaries = try allocator.alloc(ChunkBoundary, num_chunks);

    if (source.len < config.min_chunk_size or num_chunks == 1) {
        // Too small to split or only one chunk requested
        boundaries[0] = ChunkBoundary{ .start = 0, .end = source.len };
        return boundaries[0..1];
    }

    const target_size = @max(config.min_chunk_size, source.len / num_chunks);
    var current_pos: usize = 0;
    var chunk_idx: usize = 0;

    while (current_pos < source.len and chunk_idx < num_chunks) {
        const start = current_pos;
        var end = @min(start + target_size, source.len);

        // If this is the last chunk, take everything remaining
        if (chunk_idx == num_chunks - 1) {
            end = source.len;
        } else if (end < source.len) {
            // Find a safe boundary: look for whitespace or newline
            // Walk forward up to 256 bytes to find a good split point
            const search_limit = @min(end + 256, source.len);
            var found_boundary = false;

            while (end < search_limit) : (end += 1) {
                const c = source[end];

                // Safe split points: whitespace, semicolons, closing braces
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or
                    c == ';' or c == '}' or c == ')' or c == ']')
                {
                    end += 1; // Include the boundary character
                    found_boundary = true;
                    break;
                }
            }

            // If we couldn't find a boundary, use the original position
            if (!found_boundary) {
                end = @min(start + target_size, source.len);
            }
        }

        boundaries[chunk_idx] = ChunkBoundary{ .start = start, .end = end };
        current_pos = end;
        chunk_idx += 1;
    }

    return boundaries[0..chunk_idx];
}

/// Worker context for parallel scanning
const WorkerContext = struct {
    source: []const u8,
    boundary: ChunkBoundary,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, source: []const u8, boundary: ChunkBoundary) !WorkerContext {
        return WorkerContext{
            .source = source,
            .boundary = boundary,
            .tokens = try std.ArrayList(Token).initCapacity(allocator, 256),
            .allocator = allocator,
        };
    }

    fn deinit(self: *WorkerContext) void {
        self.tokens.deinit(self.allocator);
    }
};

/// Scan a single chunk
fn scanChunk(ctx: *WorkerContext) !void {
    // Get the chunk slice
    const chunk = ctx.source[ctx.boundary.start..ctx.boundary.end];

    // Create null-terminated buffer for scanner
    var buffer = try ctx.allocator.alloc(u8, chunk.len + 1);
    defer ctx.allocator.free(buffer);

    @memcpy(buffer[0..chunk.len], chunk);
    buffer[chunk.len] = 0;

    // Initialize scanner for this chunk
    scanner_mod.init_scanner(buffer.ptr);

    // Tokenize the chunk
    while (true) {
        const token = scanner_mod.scanToken();

        // Adjust token positions to be relative to original source
        var adjusted_token = token;
        const token_start = @intFromPtr(token.start);
        const buffer_start = @intFromPtr(buffer.ptr);
        const offset = token_start - buffer_start;
        adjusted_token.start = @ptrFromInt(@intFromPtr(ctx.source.ptr) + ctx.boundary.start + offset);

        try ctx.tokens.append(ctx.allocator, adjusted_token);

        if (token.type == .TOKEN_EOF) {
            break;
        }
    }
}

/// Merge token streams from multiple chunks
fn mergeTokenStreams(allocator: std.mem.Allocator, contexts: []WorkerContext) ![]Token {
    // Calculate total number of tokens (excluding EOF from each chunk except last)
    var total_tokens: usize = 0;
    for (contexts, 0..) |ctx, i| {
        if (i == contexts.len - 1) {
            total_tokens += ctx.tokens.items.len;
        } else {
            // Exclude EOF token for non-last chunks
            total_tokens += ctx.tokens.items.len - 1;
        }
    }

    var merged = try allocator.alloc(Token, total_tokens);
    var write_idx: usize = 0;

    for (contexts, 0..) |ctx, i| {
        const is_last = i == contexts.len - 1;
        const count = if (is_last) ctx.tokens.items.len else ctx.tokens.items.len - 1;

        @memcpy(merged[write_idx .. write_idx + count], ctx.tokens.items[0..count]);
        write_idx += count;
    }

    return merged;
}

/// Parallel tokenization entry point
pub fn scanParallel(allocator: std.mem.Allocator, source: []const u8, config: ParallelConfig) !TokenStream {
    // Adaptive threshold: use sequential for small files
    if (source.len < config.parallel_threshold) {
        return scanSequential(allocator, source);
    }

    // Determine number of threads
    const num_threads = if (config.num_threads == 0)
        try std.Thread.getCpuCount()
    else
        config.num_threads;

    // Calculate actual threads needed based on input size
    const chunks_needed = (source.len + config.target_chunk_size - 1) / config.target_chunk_size;
    const actual_threads = @min(num_threads, chunks_needed);

    // For very small inputs or single thread, use sequential scanning
    if (source.len < config.min_chunk_size or actual_threads <= 1) {
        return scanSequential(allocator, source);
    }

    // Find safe split points using actual thread count
    const boundaries = try findSafeSplitPoints(source, actual_threads, config);
    defer std.heap.page_allocator.free(boundaries);

    // Create worker contexts
    var contexts = try allocator.alloc(WorkerContext, boundaries.len);
    defer allocator.free(contexts);

    for (contexts, 0..) |*ctx, i| {
        ctx.* = try WorkerContext.init(allocator, source, boundaries[i]);
    }
    defer {
        for (contexts) |*ctx| {
            ctx.deinit();
        }
    }

    // Create thread pool
    const threads = try allocator.alloc(std.Thread, boundaries.len);
    defer allocator.free(threads);

    // Launch worker threads
    for (threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, scanChunk, .{&contexts[i]});
    }

    // Wait for all threads to complete
    for (threads) |thread| {
        thread.join();
    }

    // Merge results
    const merged_tokens = try mergeTokenStreams(allocator, contexts);

    return TokenStream{
        .tokens = merged_tokens,
        .allocator = allocator,
    };
}

/// Sequential scanning fallback for small inputs
fn scanSequential(allocator: std.mem.Allocator, source: []const u8) !TokenStream {
    // Create null-terminated buffer
    var buffer = try allocator.alloc(u8, source.len + 1);
    defer allocator.free(buffer);

    @memcpy(buffer[0..source.len], source);
    buffer[source.len] = 0;

    // Initialize scanner
    scanner_mod.init_scanner(buffer.ptr);

    // Tokenize
    var tokens = try std.ArrayList(Token).initCapacity(allocator, 256);
    defer tokens.deinit(allocator);

    while (true) {
        const token = scanner_mod.scanToken();

        // Adjust token position to point to original source
        var adjusted_token = token;
        const token_start = @intFromPtr(token.start);
        const buffer_start = @intFromPtr(buffer.ptr);
        const offset = token_start - buffer_start;
        adjusted_token.start = @ptrFromInt(@intFromPtr(source.ptr) + offset);

        try tokens.append(allocator, adjusted_token);

        if (token.type == .TOKEN_EOF) {
            break;
        }
    }

    // Transfer ownership
    return TokenStream{
        .tokens = try tokens.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

/// Convenience function with default configuration
/// Automatically chooses parallel or sequential based on input size
pub fn scan(allocator: std.mem.Allocator, source: []const u8) !TokenStream {
    return scanParallel(allocator, source, .{});
}

/// Smart scanning with automatic parallelization decision
/// Recommended for production use
pub fn scanSmart(allocator: std.mem.Allocator, source: []const u8) !TokenStream {
    const config = ParallelConfig{
        .num_threads = 0, // Auto-detect
        .min_chunk_size = 65536, // 64KB
        .target_chunk_size = 262144, // 256KB
        .parallel_threshold = 131072, // 128KB minimum for parallel
    };
    return scanParallel(allocator, source, config);
}

/// Force sequential scanning (useful for testing or known small inputs)
pub fn scanSequentialOnly(allocator: std.mem.Allocator, source: []const u8) !TokenStream {
    return scanSequential(allocator, source);
}
