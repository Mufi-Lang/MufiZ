/// MufiZ Library Module
/// This module exports the core compiler and interpreter functionality as a library,
/// enabling integration with other Zig projects and external tooling.
///
/// Example usage:
/// ```zig
/// const mufiz = @import("mufiz");
/// 
/// pub fn main() !void {
///     // Initialize the library
///     try mufiz.init(.{
///         .enable_leak_detection = true,
///         .enable_tracking = true,
///         .enable_safety = true,
///     });
///     defer mufiz.deinit();
///     
///     // Interpret some code
///     const result = try mufiz.interpret("var x = 42; print(x);");
/// }
/// ```

const std = @import("std");

// Re-export core modules
pub const vm = @import("vm.zig");
pub const compiler = @import("compiler.zig");
pub const value = @import("value.zig");
pub const object = @import("object.zig");
pub const chunk = @import("chunk.zig");
pub const memory = @import("memory.zig");
pub const mem_utils = @import("mem_utils.zig");
pub const system = @import("system.zig");
pub const stdlib = @import("stdlib_main.zig");

// Re-export commonly used types
pub const Value = value.Value;
pub const VM = vm.VM;
pub const Chunk = chunk.Chunk;
pub const OpCode = chunk.OpCode;

// Re-export interpreter exit codes
pub const OK: u8 = vm.INTERPRET_OK;
pub const COMPILE_ERROR: u8 = vm.INTERPRET_COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = vm.INTERPRET_RUNTIME_ERROR;

// Track initialization state
var is_initialized: bool = false;

/// Error returned when library is used incorrectly
pub const LibraryError = error{
    AlreadyInitialized,
    NotInitialized,
};

/// Configuration options for initializing the MufiZ library
pub const InitOptions = struct {
    /// Enable memory leak detection
    enable_leak_detection: bool = false,
    /// Enable memory allocation tracking
    enable_tracking: bool = false,
    /// Enable memory safety checks
    enable_safety: bool = false,
};

/// Initialize the MufiZ library
/// Must be called before any other library functions.
/// Call `deinit()` when done to clean up resources.
/// Returns error.AlreadyInitialized if already initialized.
pub fn init(options: InitOptions) !void {
    if (is_initialized) {
        return LibraryError.AlreadyInitialized;
    }
    
    // Initialize memory management
    mem_utils.initAllocator(.{
        .enable_leak_detection = options.enable_leak_detection,
        .enable_tracking = options.enable_tracking,
        .enable_safety = options.enable_safety,
    });
    
    // Initialize the virtual machine
    vm.initVM();
    
    // Initialize and register standard library functions
    try stdlib.initializeStdlib();
    stdlib.registerWithVM();
    
    is_initialized = true;
}

/// Clean up and deinitialize the MufiZ library
/// Should be called when the library is no longer needed.
/// Optionally checks for memory leaks.
/// This function is idempotent and safe to call multiple times.
pub fn deinit() void {
    if (!is_initialized) {
        return; // Already deinitialized or never initialized
    }
    
    // Free the virtual machine
    vm.freeVM();
    
    // Check for memory leaks if leak detection was enabled
    if (mem_utils.checkForLeaks()) {
        std.debug.print("Warning: Memory leaks detected!\n", .{});
        mem_utils.printMemStats();
    }
    
    // Clean up memory management
    mem_utils.deinit();
    
    is_initialized = false;
}

/// Interpret MufiZ source code
/// Returns the exit code (OK, COMPILE_ERROR, or RUNTIME_ERROR)
/// Requires the library to be initialized first.
pub fn interpret(source: []const u8) u8 {
    if (!is_initialized) {
        std.debug.print("Error: Library not initialized. Call init() first.\n", .{});
        return RUNTIME_ERROR;
    }
    return vm.interpret(source);
}

/// Get the global allocator used by the library
/// Requires the library to be initialized first.
/// Returns LibraryError.NotInitialized if library is not initialized.
pub fn getAllocator() !std.mem.Allocator {
    if (!is_initialized) {
        return LibraryError.NotInitialized;
    }
    return mem_utils.getAllocator();
}

/// Run a MufiZ script from a file
/// Requires the file system feature to be enabled.
pub const Runner = system.Runner;

/// Start the interactive REPL
/// Returns an error if initialization fails.
/// Requires the library to be initialized first.
pub fn startRepl() !void {
    if (!is_initialized) {
        return LibraryError.NotInitialized;
    }
    try system.repl();
}

/// Print version information
pub fn printVersion() void {
    system.version();
}

/// Print usage information
pub fn printUsage() void {
    system.usage();
}

/// Check if memory leaks were detected
pub fn hasMemoryLeaks() bool {
    return mem_utils.checkForLeaks();
}

/// Print memory statistics
pub fn printMemoryStats() void {
    mem_utils.printMemStats();
}

// Tests
test "library initialization" {
    try init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer deinit();
    
    // Basic sanity check
    const allocator = try getAllocator();
    _ = allocator;
}

test "double initialization error" {
    try init(.{});
    defer deinit();
    
    // Attempting to initialize again should fail
    const result = init(.{});
    try std.testing.expectError(LibraryError.AlreadyInitialized, result);
}

test "idempotent deinitialization" {
    try init(.{});
    deinit();
    
    // Calling deinit again should be safe
    deinit();
}

test "basic interpretation" {
    try init(.{});
    defer deinit();
    
    // Test a simple expression
    const result = interpret("1 + 1;");
    try std.testing.expectEqual(OK, result);
}

test "interpret without initialization" {
    // Ensure library is not initialized
    if (is_initialized) {
        deinit();
    }
    
    // This should fail gracefully
    const result = interpret("1 + 1;");
    try std.testing.expectEqual(RUNTIME_ERROR, result);
    
    // Clean up - initialize and deinitialize for next test
    try init(.{});
    deinit();
}
