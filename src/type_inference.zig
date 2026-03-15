/// Type Inference Engine for MufiZ Compiler
///
/// Implements bottom-up type inference for expressions:
/// - Infers types from literals and operations
/// - Resolves type constraints
/// - Unifies types across expressions
/// - Tracks inferred types for use in type checking

const std = @import("std");
const Allocator = std.mem.Allocator;
const type_system = @import("type_system.zig");

const SimpleType = type_system.SimpleType;
const Type = type_system.Type;
const TypeInfo = type_system.TypeInfo;
const TypeEnvironment = type_system.TypeEnvironment;
const TypeCompatibilityGraph = type_system.TypeCompatibilityGraph;
const OperationType = type_system.OperationType;

// ============================================================================
// Type Inference Results
// ============================================================================

pub const InferenceError = error{
    IncompatibleTypes,
    UnsolvedConstraints,
    OutOfMemory,
    UnknownVariable,
};

pub const InferenceResult = union(enum) {
    Ok: Type,
    Err: struct {
        message: []const u8,
        context: []const u8,
    },

    const Self = @This();

    pub fn isOk(self: Self) bool {
        return self == .Ok;
    }

    pub fn unwrapOk(self: Self) !Type {
        return switch (self) {
            .Ok => |t| t,
            .Err => InferenceError.UnsolvedConstraints,
        };
    }
};

// ============================================================================
// Type Constraint
// ============================================================================

/// Represents a constraint that two types must unify
pub const TypeConstraint = struct {
    left: SimpleType,
    right: SimpleType,
    source: []const u8, // Source code location (for error messages)
};

// ============================================================================
// Type Inference Context
// ============================================================================

pub const TypeInferenceContext = struct {
    allocator: Allocator,
    graph: *TypeCompatibilityGraph,
    environment: *TypeEnvironment,
    constraints: std.ArrayList(TypeConstraint),

    const Self = @This();

    pub fn init(allocator: Allocator, graph: *TypeCompatibilityGraph, env: *TypeEnvironment) !Self {
        return Self{
            .allocator = allocator,
            .graph = graph,
            .environment = env,
            .constraints = std.ArrayList(TypeConstraint).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.constraints.deinit();
    }

    /// Add a constraint that two types must be compatible
    pub fn addConstraint(self: *Self, left: SimpleType, right: SimpleType, source: []const u8) !void {
        try self.constraints.append(.{
            .left = left,
            .right = right,
            .source = source,
        });
    }

    /// Solve all accumulated constraints
    pub fn solveConstraints(self: *Self) !void {
        for (self.constraints.items) |constraint| {
            // Check if types are compatible
            const coercion = self.graph.canCoerce(constraint.left, constraint.right);
            if (coercion == .None) {
                // Try reverse direction
                const reverseCoercion = self.graph.canCoerce(constraint.right, constraint.left);
                if (reverseCoercion == .None) {
                    std.debug.print("Type constraint failed: {s} vs {s} at {s}\n", .{
                        constraint.left.name(),
                        constraint.right.name(),
                        constraint.source,
                    });
                    return InferenceError.IncompatibleTypes;
                }
            }
        }
    }
};

// ============================================================================
// Inference Functions
// ============================================================================

/// Infer the type of a literal value
pub fn inferLiteralType(value: []const u8) SimpleType {
    // Try to parse as integer
    if (std.fmt.parseInt(i32, value, 10)) |_| {
        return .Int;
    } else |_| {}

    // Try to parse as float
    if (std.fmt.parseFloat(f64, value)) |_| {
        return .Double;
    } else |_| {}

    // Check for bool literals
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "false")) {
        return .Bool;
    }

    // Check for nil
    if (std.mem.eql(u8, value, "nil")) {
        return .Nil;
    }

    // Default: treat as string
    return .String;
}

/// Infer the type of a binary operation
pub fn inferBinaryOpType(
    ctx: *TypeInferenceContext,
    op: OperationType,
    left_type: SimpleType,
    right_type: SimpleType,
) InferenceResult {
    const result = ctx.graph.resolveOperationType(op, left_type, right_type);

    if (result == .Invalid) {
        return InferenceResult{
            .Err = .{
                .message = "Invalid operation between incompatible types",
                .context = "binary operation type resolution",
            },
        };
    }

    return InferenceResult{ .Ok = Type.init(result) };
}

/// Infer the type of a unary operation
pub fn inferUnaryOpType(_: *TypeInferenceContext, operand_type: SimpleType) InferenceResult {
    // Most unary ops preserve numeric types
    if (operand_type.isNumeric()) {
        return InferenceResult{ .Ok = Type.init(operand_type) };
    }

    if (operand_type == .Bool) {
        return InferenceResult{ .Ok = Type.init(.Bool) };
    }

    return InferenceResult{
        .Err = .{
            .message = "Invalid unary operation on non-numeric type",
            .context = "unary operation type resolution",
        },
    };
}

/// Infer the type of a function call
/// This is a placeholder - full implementation requires AST nodes
pub fn inferFunctionCallType(ctx: *TypeInferenceContext, function_name: []const u8) InferenceResult {
    // In a full implementation, look up function signature from environment
    // For now, return Any type (unknown)
    _ = ctx;
    _ = function_name;
    return InferenceResult{ .Ok = Type.init(.Any) };
}

/// Infer the type of a variable lookup
pub fn inferVariableType(ctx: *TypeInferenceContext, var_name: []const u8) InferenceResult {
    if (ctx.environment.lookup(var_name)) |type_info| {
        return InferenceResult{ .Ok = type_info.type };
    }

    return InferenceResult{
        .Err = .{
            .message = "Unknown variable",
            .context = var_name,
        },
    };
}

// ============================================================================
// Type Unification
// ============================================================================

/// Unify two types (find a common type they can both be)
pub fn unifyTypes(graph: *TypeCompatibilityGraph, a: SimpleType, b: SimpleType) ?SimpleType {
    if (a == b) return a;

    // Try to coerce a to b
    if (graph.canCoerce(a, b) != .None) {
        return b;
    }

    // Try to coerce b to a
    if (graph.canCoerce(b, a) != .None) {
        return a;
    }

    // Find a common type
    const common = graph.findCommonType(a, b);
    if (common != .Invalid) {
        return common;
    }

    return null;
}

// ============================================================================
// Tests
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create graph and environment
    var graph = try TypeCompatibilityGraph.init(allocator);
    defer graph.deinit();

    var env = try TypeEnvironment.init(allocator);
    defer env.deinit();

    // Create inference context
    var ctx = try TypeInferenceContext.init(allocator, &graph, &env);
    defer ctx.deinit();

    // Test literal type inference
    const int_lit = inferLiteralType("42");
    std.debug.print("Inferred type of '42': {s}\n", .{int_lit.name()});

    const double_lit = inferLiteralType("3.14");
    std.debug.print("Inferred type of '3.14': {s}\n", .{double_lit.name()});

    const bool_lit = inferLiteralType("true");
    std.debug.print("Inferred type of 'true': {s}\n", .{bool_lit.name()});

    // Test binary op type inference
    const add_result = inferBinaryOpType(&ctx, .Add, .Int, .Double);
    std.debug.print("Type of (int + double): {}\n", .{add_result});

    // Test type unification
    if (unifyTypes(&graph, .Int, .Double)) |unified| {
        std.debug.print("Unified type of Int and Double: {s}\n", .{unified.name()});
    }
}
