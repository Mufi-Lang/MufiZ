/// File-Level Parallel Scanner for MufiZ
/// Provides efficient batch processing by parallelizing across multiple files
/// instead of within a single file. This approach has much better ROI for
/// typical compilation workloads.
const std = @import("std");
const scanner = @import("../scanner_optimized.zig");

/// Result of scanning a single file
pub const FileTokens = struct {
    file_path: []const u8,
    source: []const u8,
    tokens: std.ArrayList(scanner.Token),
    line_count: usize,
    scan_time_ns: u64,
    success: bool,
    error_message: ?[]const u8 = null,

    pub fn deinit(self: *FileTokens, allocator: std.mem.Allocator) void {
        self.tokens.deinit();
        if (self.error_message) |msg| {
            allocator.free(msg);
        }
    }
};

/// Configuration for batch scanning
pub const BatchConfig = struct {
    /// Number of worker threads (0 = auto-detect based on CPU cores)
    num_threads: usize = 0,

    /// Maximum number of files to queue per thread
    files_per_thread: usize = 4,

    /// Whether to stop on first error
    fail_fast: bool = false,

    /// Whether to collect detailed timing statistics
    collect_stats: bool = false,
};

/// Statistics for batch scanning
pub const BatchStats = struct {
    total_files: usize,
    successful_files: usize,
    failed_files: usize,
    total_tokens: usize,
    total_lines: usize,
    total_bytes: usize,
    total_time_ns: u64,
    avg_time_per_file_ns: u64,
    files_per_second: f64,
};

/// Result of batch scanning
pub const BatchResult = struct {
    file_results: []FileTokens,
    stats: BatchStats,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BatchResult) void {
        for (self.file_results) |*result| {
            result.deinit(self.allocator);
        }
        self.allocator.free(self.file_results);
    }
};

/// Work item for a single file
const WorkItem = struct {
    file_path: []const u8,
    source: []const u8,
    index: usize,
};

/// Worker context
const WorkerContext = struct {
    allocator: std.mem.Allocator,
    work_queue: *std.ArrayList(WorkItem),
    results: []FileTokens,
    mutex: *std.Thread.Mutex,
    config: BatchConfig,
    should_stop: *std.atomic.Value(bool),

    fn processWork(self: *WorkerContext) !void {
        while (true) {
            // Check if we should stop (fail-fast)
            if (self.should_stop.load(.acquire)) {
                break;
            }

            // Get next work item
            self.mutex.lock();
            const work_item = if (self.work_queue.items.len > 0)
                self.work_queue.pop()
            else
                null;
            self.mutex.unlock();

            if (work_item == null) {
                break; // No more work
            }

            const item = work_item.?;

            // Scan this file
            const start_time = std.time.nanoTimestamp();
            const result = self.scanFile(item) catch |err| blk: {
                const error_msg = std.fmt.allocPrint(
                    self.allocator,
                    "Failed to scan: {s}",
                    .{@errorName(err)},
                ) catch "Unknown error";

                break :blk FileTokens{
                    .file_path = item.file_path,
                    .source = item.source,
                    .tokens = std.ArrayList(scanner.Token).init(self.allocator),
                    .line_count = 0,
                    .scan_time_ns = 0,
                    .success = false,
                    .error_message = error_msg,
                };
            };
            const end_time = std.time.nanoTimestamp();

            // Store result
            var final_result = result;
            final_result.scan_time_ns = @intCast(end_time - start_time);

            self.mutex.lock();
            self.results[item.index] = final_result;
            self.mutex.unlock();

            // Check for fail-fast
            if (self.config.fail_fast and !result.success) {
                self.should_stop.store(true, .release);
                break;
            }
        }
    }

    fn scanFile(self: *WorkerContext, item: WorkItem) !FileTokens {
        var tokens = std.ArrayList(scanner.Token).init(self.allocator);
        errdefer tokens.deinit();

        // Create null-terminated buffer
        const buffer = try self.allocator.alloc(u8, item.source.len + 1);
        defer self.allocator.free(buffer);

        @memcpy(buffer[0..item.source.len], item.source);
        buffer[item.source.len] = 0;

        // Initialize scanner
        scanner.init_scanner(buffer.ptr);

        // Scan all tokens
        var line_count: usize = 1;
        while (true) {
            const token = scanner.scanToken();

            // Track line count
            if (token.line > line_count) {
                line_count = @intCast(token.line);
            }

            // Adjust token position to point to original source
            var adjusted_token = token;
            const token_start = @intFromPtr(token.start);
            const buffer_start = @intFromPtr(buffer.ptr);
            const offset = token_start - buffer_start;
            adjusted_token.start = @ptrFromInt(@intFromPtr(item.source.ptr) + offset);

            try tokens.append(self.allocator, adjusted_token);

            if (token.type == .TOKEN_EOF) {
                break;
            }
        }

        return FileTokens{
            .file_path = item.file_path,
            .source = item.source,
            .tokens = tokens,
            .line_count = line_count,
            .scan_time_ns = 0, // Will be set by caller
            .success = true,
            .error_message = null,
        };
    }
};

/// Scan multiple files in parallel
pub fn scanFiles(
    allocator: std.mem.Allocator,
    file_paths: []const []const u8,
    sources: []const []const u8,
    config: BatchConfig,
) !BatchResult {
    std.debug.assert(file_paths.len == sources.len);

    if (file_paths.len == 0) {
        return BatchResult{
            .file_results = &[_]FileTokens{},
            .stats = BatchStats{
                .total_files = 0,
                .successful_files = 0,
                .failed_files = 0,
                .total_tokens = 0,
                .total_lines = 0,
                .total_bytes = 0,
                .total_time_ns = 0,
                .avg_time_per_file_ns = 0,
                .files_per_second = 0.0,
            },
            .allocator = allocator,
        };
    }

    const batch_start = std.time.nanoTimestamp();

    // Determine number of threads
    const num_threads = if (config.num_threads == 0)
        try std.Thread.getCpuCount()
    else
        config.num_threads;

    const actual_threads = @min(num_threads, file_paths.len);

    // Create work queue
    var work_queue = std.ArrayList(WorkItem).init(allocator);
    defer work_queue.deinit();

    // Fill work queue (in reverse order so pop() gets items in order)
    var i: usize = file_paths.len;
    while (i > 0) {
        i -= 1;
        try work_queue.append(WorkItem{
            .file_path = file_paths[i],
            .source = sources[i],
            .index = i,
        });
    }

    // Allocate results array
    const results = try allocator.alloc(FileTokens, file_paths.len);
    errdefer allocator.free(results);

    // Initialize results with empty data
    for (results, 0..) |*result, idx| {
        result.* = FileTokens{
            .file_path = file_paths[idx],
            .source = sources[idx],
            .tokens = std.ArrayList(scanner.Token).init(allocator),
            .line_count = 0,
            .scan_time_ns = 0,
            .success = false,
            .error_message = null,
        };
    }

    // Create synchronization primitives
    var mutex = std.Thread.Mutex{};
    var should_stop = std.atomic.Value(bool).init(false);

    // Create worker context
    var worker_ctx = WorkerContext{
        .allocator = allocator,
        .work_queue = &work_queue,
        .results = results,
        .mutex = &mutex,
        .config = config,
        .should_stop = &should_stop,
    };

    // Single-threaded path for one thread
    if (actual_threads == 1) {
        try worker_ctx.processWork();
    } else {
        // Create and launch worker threads
        const threads = try allocator.alloc(std.Thread, actual_threads);
        defer allocator.free(threads);

        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(.{}, WorkerContext.processWork, .{&worker_ctx});
        }

        // Wait for all threads to complete
        for (threads) |thread| {
            thread.join();
        }
    }

    const batch_end = std.time.nanoTimestamp();
    const total_time_ns: u64 = @intCast(batch_end - batch_start);

    // Compute statistics
    var stats = BatchStats{
        .total_files = file_paths.len,
        .successful_files = 0,
        .failed_files = 0,
        .total_tokens = 0,
        .total_lines = 0,
        .total_bytes = 0,
        .total_time_ns = total_time_ns,
        .avg_time_per_file_ns = 0,
        .files_per_second = 0.0,
    };

    for (results) |result| {
        if (result.success) {
            stats.successful_files += 1;
            stats.total_tokens += result.tokens.items.len;
            stats.total_lines += result.line_count;
        } else {
            stats.failed_files += 1;
        }
        stats.total_bytes += result.source.len;
    }

    if (stats.total_files > 0) {
        stats.avg_time_per_file_ns = total_time_ns / stats.total_files;
        const seconds = @as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0;
        stats.files_per_second = @as(f64, @floatFromInt(stats.total_files)) / seconds;
    }

    return BatchResult{
        .file_results = results,
        .stats = stats,
        .allocator = allocator,
    };
}

/// Convenience function: scan files from disk
pub fn scanFilesFromDisk(
    allocator: std.mem.Allocator,
    file_paths: []const []const u8,
    config: BatchConfig,
) !BatchResult {
    // Read all files into memory
    const sources = try allocator.alloc([]u8, file_paths.len);
    defer {
        for (sources) |source| {
            allocator.free(source);
        }
        allocator.free(sources);
    }

    for (file_paths, 0..) |path, i| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = (try file.stat()).size;
        const source = try allocator.alloc(u8, file_size);
        _ = try file.readAll(source);

        sources[i] = source;
    }

    // Convert to const slices
    const const_sources = try allocator.alloc([]const u8, sources.len);
    defer allocator.free(const_sources);

    for (sources, 0..) |source, i| {
        const_sources[i] = source;
    }

    return scanFiles(allocator, file_paths, const_sources, config);
}

/// Helper: scan directory recursively
pub fn scanDirectory(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    extension: []const u8,
    config: BatchConfig,
) !BatchResult {
    var file_list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (file_list.items) |path| {
            allocator.free(path);
        }
        file_list.deinit();
    }

    // Recursively find all files with the given extension
    try findFilesRecursive(allocator, dir_path, extension, &file_list);

    const paths = try file_list.toOwnedSlice();
    defer {
        for (paths) |path| {
            allocator.free(path);
        }
        allocator.free(paths);
    }

    return scanFilesFromDisk(allocator, paths, config);
}

fn findFilesRecursive(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    extension: []const u8,
    file_list: *std.ArrayList([]const u8),
) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        errdefer allocator.free(full_path);

        switch (entry.kind) {
            .file => {
                if (std.mem.endsWith(u8, entry.name, extension)) {
                    try file_list.append(full_path);
                } else {
                    allocator.free(full_path);
                }
            },
            .directory => {
                defer allocator.free(full_path);
                try findFilesRecursive(allocator, full_path, extension, file_list);
            },
            else => {
                allocator.free(full_path);
            },
        }
    }
}
