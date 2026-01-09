/// Example: Using MufiZ as a Library
/// This example demonstrates how to import and use the MufiZ library
/// in another Zig project.

const std = @import("std");
const mufiz = @import("../src/lib.zig");

pub fn main() !void {
    std.debug.print("=== MufiZ Library Example ===\n\n", .{});

    // Initialize the MufiZ library with memory tracking
    std.debug.print("Initializing MufiZ library...\n", .{});
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer {
        std.debug.print("\nCleaning up MufiZ library...\n", .{});
        mufiz.deinit();
    }

    // Print version
    std.debug.print("\nVersion: ", .{});
    mufiz.printVersion();

    // Example 1: Simple arithmetic
    std.debug.print("\n--- Example 1: Simple Arithmetic ---\n", .{});
    const code1 = "print(2 + 2 * 10);";
    std.debug.print("Executing: {s}\n", .{code1});
    const result1 = mufiz.interpret(code1);
    if (result1 == mufiz.OK) {
        std.debug.print("✓ Execution successful\n", .{});
    } else {
        std.debug.print("✗ Execution failed with code: {d}\n", .{result1});
    }

    // Example 2: Variables
    std.debug.print("\n--- Example 2: Variables ---\n", .{});
    const code2 = "var message = \"Hello from MufiZ library!\"; print(message);";
    std.debug.print("Executing: {s}\n", .{code2});
    const result2 = mufiz.interpret(code2);
    if (result2 == mufiz.OK) {
        std.debug.print("✓ Execution successful\n", .{});
    } else {
        std.debug.print("✗ Execution failed with code: {d}\n", .{result2});
    }

    // Example 3: Functions
    std.debug.print("\n--- Example 3: Functions ---\n", .{});
    const code3 = "fn greet(name) { return \"Hello, \" + name + \"!\"; } print(greet(\"World\"));";
    std.debug.print("Executing: {s}\n", .{code3});
    const result3 = mufiz.interpret(code3);
    if (result3 == mufiz.OK) {
        std.debug.print("✓ Execution successful\n", .{});
    } else {
        std.debug.print("✗ Execution failed with code: {d}\n", .{result3});
    }

    // Check for memory leaks
    if (mufiz.hasMemoryLeaks()) {
        std.debug.print("\n⚠️  Memory leaks detected!\n", .{});
        mufiz.printMemoryStats();
    } else {
        std.debug.print("\n✓ No memory leaks detected\n", .{});
    }

    std.debug.print("\n=== Example Complete ===\n", .{});
}
