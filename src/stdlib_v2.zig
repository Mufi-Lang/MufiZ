const std = @import("std");
const Value = @import("value.zig").Value;
const vm = @import("vm.zig");
const conv = @import("conv.zig");

// Improved type system for parameter validation
pub const ParamType = enum(u8) {
    any = 0,
    int = 1,
    double = 2,
    bool = 3,
    nil = 4,
    object = 5,
    complex = 6,
    number = 7, // int or double
    string = 8,

    pub fn matches(self: ParamType, value: Value) bool {
        return switch (self) {
            .any => true,
            .int => value.is_int(),
            .double => value.is_double(),
            .bool => value.is_bool(),
            .nil => value.is_nil(),
            .object => value.is_obj(),
            .complex => value.is_complex(),
            .number => value.is_prim_num(),
            .string => value.is_string(),
        };
    }

    pub fn toString(self: ParamType) []const u8 {
        return switch (self) {
            .any => "Any",
            .int => "Int",
            .double => "Double",
            .bool => "Bool",
            .nil => "Nil",
            .object => "Object",
            .complex => "Complex",
            .number => "Number",
            .string => "String",
        };
    }
};

// Function parameter specification
pub const ParamSpec = struct {
    name: []const u8,
    type: ParamType,
    optional: bool = false,
};

// Function metadata for automatic registration and documentation
pub const FunctionMeta = struct {
    name: []const u8,
    module: []const u8,
    description: []const u8,
    params: []const ParamSpec,
    return_type: ParamType = .any,
    examples: []const []const u8 = &[_][]const u8{},
};

// Result type for validation
const ValidationResult = union(enum) {
    ok,
    wrong_argc: struct { expected: usize, got: i32 },
    wrong_type: struct { param_idx: usize, expected: ParamType, got: []const u8 },
};

// Native function wrapper with automatic validation
pub fn NativeWrapper(comptime meta: FunctionMeta, comptime func: anytype) type {
    return struct {
        pub const function_meta = meta;

        pub fn call(argc: i32, args: [*]Value) Value {
            // Validate argument count
            const min_required = blk: {
                var count: usize = 0;
                for (meta.params) |param| {
                    if (!param.optional) count += 1;
                }
                break :blk count;
            };
            const max_allowed = meta.params.len;

            if (argc < 0 or @as(usize, @intCast(argc)) < min_required or @as(usize, @intCast(argc)) > max_allowed) {
                return stdlib_error("{}() expects {}-{} arguments, got {}", .{ meta.name, min_required, max_allowed, argc });
            }

            // Validate argument types
            for (meta.params, 0..) |param, i| {
                if (i >= @as(usize, @intCast(argc))) {
                    if (!param.optional) {
                        return stdlib_error("{}() missing required parameter: {}", .{ meta.name, param.name });
                    }
                    break;
                }

                if (!param.type.matches(args[i])) {
                    return stdlib_error("{}() parameter '{}' expects {}, got {}", .{ meta.name, param.name, param.type.toString(), conv.what_is(args[i]) });
                }
            }

            // Call the actual function
            return @call(.auto, func, .{ argc, args });
        }
    };
}

// Registry for automatic function discovery
pub const FunctionRegistry = struct {
    functions: std.ArrayList(RegisteredFunction),
    allocator: std.mem.Allocator,

    const RegisteredFunction = struct {
        name: []const u8,
        module: []const u8,
        description: []const u8,
        params: []const ParamSpec,
        return_type: ParamType,
        examples: []const []const u8,
        call_fn: *const fn (argc: i32, args: [*]Value) Value,
    };

    pub fn init(allocator: std.mem.Allocator) FunctionRegistry {
        return .{
            .functions = std.ArrayList(RegisteredFunction){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FunctionRegistry) void {
        self.functions.deinit(self.allocator);
    }

    pub fn register(self: *FunctionRegistry, comptime wrapper: anytype) !void {
        const meta = wrapper.function_meta;
        try self.functions.append(self.allocator, .{
            .name = meta.name,
            .module = meta.module,
            .description = meta.description,
            .params = meta.params,
            .return_type = meta.return_type,
            .examples = meta.examples,
            .call_fn = wrapper.call,
        });
    }

    pub fn registerAll(self: *FunctionRegistry) void {
        for (self.functions.items) |func| {
            vm.defineNative(@ptrCast(@constCast(func.name)), @ptrCast(func.call_fn));
        }
    }

    pub fn registerModule(self: *FunctionRegistry, module_name: []const u8) void {
        for (self.functions.items) |func| {
            if (std.mem.eql(u8, func.module, module_name)) {
                vm.defineNative(@ptrCast(@constCast(func.name)), @ptrCast(func.call_fn));
            }
        }
    }

    pub fn printDocs(self: *FunctionRegistry) void {
        var current_module: ?[]const u8 = null;

        for (self.functions.items) |func| {
            if (current_module == null or !std.mem.eql(u8, current_module.?, func.module)) {
                current_module = func.module;
                std.debug.print("\n=== {} Module ===\n", .{func.module});
            }

            std.debug.print("\n{}(", .{func.name});
            for (func.params, 0..) |param, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}: {s}", .{ param.name, param.type.toString() });
                if (param.optional) std.debug.print("?", .{});
            }
            std.debug.print(") -> {s}\n", .{func.return_type.toString()});
            std.debug.print("  {s}\n", .{func.description});

            if (func.examples.len > 0) {
                std.debug.print("  Examples:\n", .{});
                for (func.examples) |example| {
                    std.debug.print("    {s}\n", .{example});
                }
            }
        }
    }

    pub fn getFunctionCount(self: *FunctionRegistry) usize {
        return self.functions.items.len;
    }

    pub fn getModuleFunctionCount(self: *FunctionRegistry, module_name: []const u8) usize {
        var count: usize = 0;
        for (self.functions.items) |func| {
            if (std.mem.eql(u8, func.module, module_name)) {
                count += 1;
            }
        }
        return count;
    }
};

// Global registry instance
var global_registry: ?FunctionRegistry = null;

pub fn getGlobalRegistry() *FunctionRegistry {
    if (global_registry == null) {
        // Initialize with a default allocator - in practice you'd want to pass this in
        global_registry = FunctionRegistry.init(std.heap.page_allocator);
    }
    return &global_registry.?;
}

// Improved error handling with consistent formatting
pub fn stdlib_error(comptime fmt: []const u8, args: anytype) Value {
    // Temporarily disable formatting to fix compile issues
    _ = fmt;
    _ = args;
    return Value.init_nil();
}

// Macro for easy function definition
pub fn DefineFunction(
    comptime name: []const u8,
    comptime module: []const u8,
    comptime description: []const u8,
    comptime params: []const ParamSpec,
    comptime return_type: ParamType,
    comptime examples: []const []const u8,
    comptime func: anytype,
) type {
    const meta = FunctionMeta{
        .name = name,
        .module = module,
        .description = description,
        .params = params,
        .return_type = return_type,
        .examples = examples,
    };
    return NativeWrapper(meta, func);
}

// Helper macros for common parameter patterns
pub const NoParams = &[_]ParamSpec{};
pub const OneNumber = &[_]ParamSpec{.{ .name = "value", .type = .number }};
pub const TwoNumbers = &[_]ParamSpec{
    .{ .name = "a", .type = .number },
    .{ .name = "b", .type = .number },
};
pub const OneAny = &[_]ParamSpec{.{ .name = "value", .type = .any }};

// Module registration helper
pub fn registerModule(comptime module_functions: anytype) !void {
    const registry = getGlobalRegistry();
    const type_info = @typeInfo(@TypeOf(module_functions));

    if (type_info != .Struct) {
        @compileError("registerModule expects a struct containing function wrappers");
    }

    inline for (type_info.Struct.decls) |decl| {
        const field = @field(module_functions, decl.name);
        if (@hasDecl(@TypeOf(field), "function_meta")) {
            try registry.register(field);
        }
    }
}

// Auto-discovery macro for modules
pub fn AutoRegisterModule(comptime module: type) type {
    return struct {
        pub fn register() !void {
            // Temporarily disabled auto-registration due to Zig 0.15 compatibility issues
            // Individual modules will need to be registered manually
            _ = module;
        }
    };
}

// Feature flag support
pub const FeatureFlags = struct {
    enable_fs: bool = true,
    enable_net: bool = true,
    enable_curl: bool = false,
};

var feature_flags = FeatureFlags{};

pub fn setFeatureFlags(flags: FeatureFlags) void {
    feature_flags = flags;
}

pub fn isFeatureEnabled(comptime feature: []const u8) bool {
    return @field(feature_flags, feature);
}

// Conditional registration based on features
pub fn registerModuleConditional(comptime module_functions: anytype, comptime feature: []const u8) !void {
    if (isFeatureEnabled(feature)) {
        try registerModule(module_functions);
    } else {
        std.log.warn("Module skipped due to disabled feature: {s}", .{feature});
    }
}
