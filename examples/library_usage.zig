/// Example: Using MufiZ as a Library
/// This example demonstrates how to import and use the MufiZ library
/// in another Zig project.

const std = @import("std");
const mufiz = @import("../src/lib.zig");

// Example code snippets
const Example1Code = "print(2 + 2 * 10);";
const Example2Code = "var message = \"Hello from MufiZ library!\"; print(message);";
const Example3Code = "fn greet(name) { return \"Hello, \" + name + \"!\"; } print(greet(\"World\"));";

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
    std.debug.print("Executing: {s}\n", .{Example1Code});
    const result1 = mufiz.interpret(Example1Code);
    if (result1 == mufiz.OK) {
        std.debug.print("✓ Execution successful\n", .{});
    } else {
        std.debug.print("✗ Execution failed with code: {d}\n", .{result1});
    }

    // Example 2: Variables
    std.debug.print("\n--- Example 2: Variables ---\n", .{});
    std.debug.print("Executing: {s}\n", .{Example2Code});
    const result2 = mufiz.interpret(Example2Code);
    if (result2 == mufiz.OK) {
        std.debug.print("✓ Execution successful\n", .{});
    } else {
        std.debug.print("✗ Execution failed with code: {d}\n", .{result2});
    }

    // Example 3: Functions
    std.debug.print("\n--- Example 3: Functions ---\n", .{});
    std.debug.print("Executing: {s}\n", .{Example3Code});
    const result3 = mufiz.interpret(Example3Code);
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
