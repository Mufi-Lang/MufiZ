const std = @import("std");
const stdlib_v2 = @import("../stdlib_v2.zig");
const math = @import("math.zig");

// Example of how to use the new stdlib system

pub fn main() !void {
    // Initialize the registry
    const registry = stdlib_v2.getGlobalRegistry();

    // Set feature flags if needed
    stdlib_v2.setFeatureFlags(.{
        .enable_fs = true,
        .enable_net = false, // Disable network functions for this example
    });

    // Auto-register all functions from the math module
    const MathModule = stdlib_v2.AutoRegisterModule(math);
    try MathModule.register();

    // Or register individual functions manually
    // try registry.register(math.sin);
    // try registry.register(math.cos);
    // try registry.register(math.tan);

    // Register all functions with the VM
    registry.registerAll();

    // Print documentation for all registered functions
    std.debug.print("=== Registered Functions ===\n");
    registry.printDocs();

    // Show statistics
    std.debug.print("\nTotal functions registered: {}\n", .{registry.getFunctionCount()});
    std.debug.print("Math module functions: {}\n", .{registry.getModuleFunctionCount("math")});

    // Example of conditional module registration
    if (stdlib_v2.isFeatureEnabled("enable_net")) {
        std.debug.print("Network functions would be registered here\n");
    } else {
        std.debug.print("Network functions disabled\n");
    }
}

// Example of how to create a custom module with the new system
pub const CustomMath = struct {
    // Simple function with no parameters
    fn double_pi_impl(argc: i32, args: [*]Value) Value {
        _ = argc;
        _ = args;
        return Value.init_double(2.0 * std.math.pi);
    }

    pub const double_pi = stdlib_v2.DefineFunction(
        "double_pi",
        "custom",
        "Returns 2 * pi",
        stdlib_v2.NoParams,
        .double,
        &[_][]const u8{"double_pi() -> 6.283185307179586"},
        double_pi_impl,
    );

    // Function with optional parameters
    fn clamp_impl(argc: i32, args: [*]Value) Value {
        const value = args[0].as_num_double();
        const min_val = if (argc > 1) args[1].as_num_double() else 0.0;
        const max_val = if (argc > 2) args[2].as_num_double() else 1.0;

        const clamped = @min(@max(value, min_val), max_val);
        return Value.init_double(clamped);
    }

    pub const clamp = stdlib_v2.DefineFunction(
        "clamp",
        "custom",
        "Clamp a value between min and max bounds",
        &[_]stdlib_v2.ParamSpec{
            .{ .name = "value", .type = .number },
            .{ .name = "min", .type = .number, .optional = true },
            .{ .name = "max", .type = .number, .optional = true },
        },
        .double,
        &[_][]const u8{
            "clamp(1.5) -> 1.0",
            "clamp(-0.5, 0, 10) -> 0.0",
            "clamp(15, 0, 10) -> 10.0",
        },
        clamp_impl,
    );
};

// Example of error handling improvements
pub fn demonstrateErrorHandling() void {
    const Value = @import("../value.zig").Value;

    // Old way (manual validation)
    std.debug.print("=== Error Handling Comparison ===\n");

    // Simulate calling a function with wrong arguments
    var args = [_]Value{Value.init_string("not a number")};

    // New system automatically provides consistent error messages:
    // "sin() parameter 'value' expects Number, got String"

    // The new system also handles:
    // - Argument count validation
    // - Type checking with clear parameter names
    // - Consistent error message formatting
    // - Optional parameter handling
}

// Example of module organization
pub const ModuleExample = struct {
    // Group related functions together
    const string_functions = struct {
        pub const upper = stdlib_v2.DefineFunction(
            "upper",
            "string",
            "Convert string to uppercase",
            &[_]stdlib_v2.ParamSpec{.{ .name = "text", .type = .string }},
            .string,
            &[_][]const u8{"upper(\"hello\") -> \"HELLO\""},
            upper_impl,
        );

        fn upper_impl(argc: i32, args: [*]Value) Value {
            _ = argc;
            // Implementation would go here
            return args[0]; // Placeholder
        }
    };

    const math_functions = struct {
        pub const factorial = stdlib_v2.DefineFunction(
            "factorial",
            "math",
            "Calculate factorial of a number",
            &[_]stdlib_v2.ParamSpec{.{ .name = "n", .type = .int }},
            .int,
            &[_][]const u8{"factorial(5) -> 120"},
            factorial_impl,
        );

        fn factorial_impl(argc: i32, args: [*]Value) Value {
            _ = argc;
            const n = args[0].as_num_int();
            var result: i64 = 1;
            var i: i64 = 2;
            while (i <= n) : (i += 1) {
                result *= i;
            }
            return Value.init_int(@intCast(result));
        }
    };

    pub fn registerAll() !void {
        const registry = stdlib_v2.getGlobalRegistry();
        try registry.register(string_functions.upper);
        try registry.register(math_functions.factorial);
    }
};
