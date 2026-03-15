/// Type Checker for MufiZ Compiler
///
/// Performs static type checking during compilation:
/// - Validates type annotations
/// - Checks operator compatibility
/// - Generates helpful error messages with type information
/// - Integrates with type inference for untyped expressions
///
/// This is a separate compilation pass that runs after parsing but before code generation.

const std = @import("std");
const Allocator = std.mem.Allocator;
const type_system = @import("type_system.zig");
const type_inference = @import("type_inference.zig");

const SimpleType = type_system.SimpleType;
const Type = type_system.Type;
const TypeInfo = type_system.TypeInfo;
const TypeEnvironment = type_system.TypeEnvironment;
const TypeCompatibilityGraph = type_system.TypeCompatibilityGraph;
const OperationType = type_system.OperationType;
const CoercionDirection = type_system.CoercionDirection;

// ============================================================================
// Type Checking Errors
// ============================================================================

pub const TypeCheckError = error{
    TypeMismatch,
    IncompatibleOperands,
    UndefinedVariable,
    InvalidTypeAnnotation,
    OutOfMemory,
};

pub const CheckError = struct {
    message: []const u8,
    line: usize = 0,
    column: usize = 0,
    expected: ?SimpleType = null,
    actual: ?SimpleType = null,

    const Self = @This();

    pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try std.fmt.format(writer, "{s}:{d}:{d}: error: {s}", .{
            "input",
            self.line,
            self.column,
            self.message,
        });

        if (self.expected) |exp| {
            if (self.actual) |act| {
                try std.fmt.format(writer, " (expected {s}, got {s})", .{ exp.name(), act.name() });
            }
        }
    }
};

// ============================================================================
// Type Checker Context
// ============================================================================

pub const TypeChecker = struct {
    allocator: Allocator,
    graph: TypeCompatibilityGraph,
    environment: TypeEnvironment,
    errors: std.ArrayList(CheckError),
    warnings: std.ArrayList(CheckError),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .graph = try TypeCompatibilityGraph.init(allocator),
            .environment = try TypeEnvironment.init(allocator),
            .errors = std.ArrayList(CheckError).init(allocator),
            .warnings = std.ArrayList(CheckError).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.graph.deinit();
        self.environment.deinit();
        self.errors.deinit();
        self.warnings.deinit();
    }

    pub fn hasErrors(self: Self) bool {
        return self.errors.items.len > 0;
    }

    pub fn addError(self: *Self, error_info: CheckError) !void {
        try self.errors.append(error_info);
    }

    pub fn addWarning(self: *Self, warning_info: CheckError) !void {
        try self.warnings.append(warning_info);
    }

    pub fn printErrors(self: Self) void {
        for (self.errors.items) |err| {
            std.debug.print("{}\n", .{err});
        }
    }

    pub fn printWarnings(self: Self) void {
        for (self.warnings.items) |warn| {
            std.debug.print("{}\n", .{warn});
        }
    }
};

// ============================================================================
// Type Checking Functions
// ============================================================================

/// Check if a value of type `from` can be assigned to a variable of type `to`
pub fn canAssign(checker: *TypeChecker, from: SimpleType, to: SimpleType) bool {
    if (from == to) return true;

    const coercion = checker.graph.canCoerce(from, to);
    return coercion != .None;
}

/// Check if an assignment is valid and return appropriate error if not
pub fn checkAssignment(
    checker: *TypeChecker,
    var_type: SimpleType,
    value_type: SimpleType,
    line: usize,
    col: usize,
) !void {
    if (!canAssign(checker, value_type, var_type)) {
        try checker.addError(.{
            .message = "Cannot assign value to variable of incompatible type",
            .line = line,
            .column = col,
            .expected = var_type,
            .actual = value_type,
        });
    }
}

/// Check a binary operation and return the result type
pub fn checkBinaryOp(
    checker: *TypeChecker,
    op: OperationType,
    left: SimpleType,
    right: SimpleType,
    line: usize,
    col: usize,
) !SimpleType {
    const result = checker.graph.resolveOperationType(op, left, right);

    if (result == .Invalid) {
        try checker.addError(.{
            .message = "Invalid binary operation between incompatible types",
            .line = line,
            .column = col,
            .expected = left,
            .actual = right,
        });
        return .Invalid;
    }

    return result;
}

/// Check a variable reference and return its type
pub fn checkVariable(
    checker: *TypeChecker,
    name: []const u8,
    line: usize,
    col: usize,
) !SimpleType {
    if (checker.environment.lookup(name)) |type_info| {
        return type_info.type.simple;
    }

    try checker.addError(.{
        .message = "Undefined variable",
        .line = line,
        .column = col,
    });
    return .Invalid;
}

/// Validate a type annotation string and convert to SimpleType
pub fn parseTypeAnnotation(annotation: []const u8) ?SimpleType {
    if (std.mem.eql(u8, annotation, "int")) return .Int;
    if (std.mem.eql(u8, annotation, "double")) return .Double;
    if (std.mem.eql(u8, annotation, "complex")) return .Complex;
    if (std.mem.eql(u8, annotation, "bool")) return .Bool;
    if (std.mem.eql(u8, annotation, "string")) return .String;
    if (std.mem.eql(u8, annotation, "nil")) return .Nil;
    if (std.mem.eql(u8, annotation, "array")) return .Array;
    if (std.mem.eql(u8, annotation, "vector")) return .Vector;
    if (std.mem.eql(u8, annotation, "matrix")) return .Matrix;
    if (std.mem.eql(u8, annotation, "function")) return .Function;
    return null;
}

// ============================================================================
// Type Coercion Cost (for operator overloading priority)
// ============================================================================

/// Calculate the "cost" of coercing from one type to another
/// Lower cost = better match for operator overloading
pub fn coercionCost(graph: *TypeCompatibilityGraph, from: SimpleType, to: SimpleType) u32 {
    if (from == to) return 0; // No coercion needed

    if (graph.canCoerce(from, to) == .Implicit) {
        // Implicit coercions have low cost
        return 1;
    }

    if (graph.canCoerce(from, to) == .Explicit) {
        // Explicit coercions have higher cost
        return 10;
    }

    return 1000; // No coercion possible
}

// ============================================================================
// Type Diagnostic Messages
// ============================================================================

pub fn formatTypeError(
    allocator: Allocator,
    expected: SimpleType,
    actual: SimpleType,
    context: []const u8,
) ![]const u8 {
    return try std.fmt.allocPrint(
        allocator,
        "Type mismatch in {s}: expected {s}, got {s}",
        .{ context, expected.name(), actual.name() },
    );
}

pub fn suggestCoercion(
    allocator: Allocator,
    from: SimpleType,
    to: SimpleType,
) !?[]const u8 {
    // Suggest explicit casts when needed
    if (from != to) {
        return try std.fmt.allocPrint(
            allocator,
            "Suggestion: cast {s} to {s}",
            .{ from.name(), to.name() },
        );
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

    var checker = try TypeChecker.init(allocator);
    defer checker.deinit();

    // Define some variables in the environment
    try checker.environment.define("x", TypeInfo.initExplicit(.Int));
    try checker.environment.define("y", TypeInfo.initExplicit(.Double));

    // Test variable lookup
    std.debug.print("Checking variable 'x'...\n", .{});
    const x_type = checkVariable(&checker, "x", 1, 1) catch .Invalid;
    std.debug.print("Type of 'x': {s}\n", .{x_type.name()});

    // Test binary operation
    std.debug.print("Checking x + y (int + double)...\n", .{});
    const result_type = checkBinaryOp(&checker, .Add, .Int, .Double, 2, 1) catch .Invalid;
    std.debug.print("Result type: {s}\n", .{result_type.name()});

    // Test invalid operation
    std.debug.print("Checking string + int (should fail)...\n", .{});
    const invalid_type = checkBinaryOp(&checker, .Add, .String, .Int, 3, 1) catch .Invalid;
    std.debug.print("Result type: {s}\n", .{invalid_type.name()});

    // Print any errors
    if (checker.hasErrors()) {
        std.debug.print("\nErrors found:\n", .{});
        checker.printErrors();
    }
}
