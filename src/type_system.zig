/// Type System Module for MufiZ Compiler
///
/// Implements a compile-time type system with:
/// - Type representation and metadata
/// - Type compatibility graph for coercion rules
/// - Type inference support
/// - Compile-time type validation
///
/// Architecture:
/// - SimpleType: represents basic types (int, double, complex, string, bool, nil)
/// - Type: represents types with quantifiers (could be extended for generics)
/// - TypeInfo: compile-time type metadata (mutable, immutable, etc.)
/// - CompatibilityGraph: defines valid type coercions and operations

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Type Representation
// ============================================================================

/// Basic types in the MufiZ language
pub const SimpleType = enum(u8) {
    // Primitive numeric types
    Int = 0,
    Double = 1,
    Complex = 2,

    // Non-numeric primitives
    Bool = 3,
    Nil = 4,
    String = 5,

    // Collections
    Array = 6,
    Vector = 7, // FloatVector (homogeneous float array)
    Matrix = 8,
    Table = 9, // Hash table

    // Special types
    Function = 10,
    Any = 11, // Unknown type (not yet inferred)
    Invalid = 12, // Error type

    pub fn name(self: SimpleType) []const u8 {
        return switch (self) {
            .Int => "int",
            .Double => "double",
            .Complex => "complex",
            .Bool => "bool",
            .Nil => "nil",
            .String => "string",
            .Array => "array",
            .Vector => "vector",
            .Matrix => "matrix",
            .Table => "table",
            .Function => "function",
            .Any => "any",
            .Invalid => "invalid",
        };
    }

    pub fn isNumeric(self: SimpleType) bool {
        return self == .Int or self == .Double or self == .Complex;
    }

    pub fn isCollection(self: SimpleType) bool {
        return self == .Array or self == .Vector or self == .Matrix or self == .Table;
    }
};

/// Represents a type with optional mutability and other attributes
pub const Type = struct {
    simple: SimpleType,
    mutable: bool = true,

    const Self = @This();

    pub fn init(simple: SimpleType) Self {
        return .{ .simple = simple };
    }

    pub fn initImmutable(simple: SimpleType) Self {
        return .{ .simple = simple, .mutable = false };
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.simple == other.simple and self.mutable == other.mutable;
    }

    pub fn name(self: Self) []const u8 {
        return self.simple.name();
    }
};

/// Metadata about a type during compilation
pub const TypeInfo = struct {
    type: Type,
    /// Is the type explicitly annotated or inferred?
    explicit: bool = false,
    /// Can this type be safely coerced to another?
    coercible: bool = true,

    const Self = @This();

    pub fn init(simple: SimpleType) Self {
        return .{ .type = .{ .simple = simple } };
    }

    pub fn initExplicit(simple: SimpleType) Self {
        return .{ .type = .{ .simple = simple }, .explicit = true };
    }
};

// ============================================================================
// Type Compatibility Graph
// ============================================================================

/// Direction of type coercion
pub const CoercionDirection = enum {
    None,
    Implicit,
    Explicit,
};

/// Defines the type compatibility graph and coercion rules
pub const TypeCompatibilityGraph = struct {
    allocator: Allocator,
    /// Coercion matrix: [from_type][to_type] -> CoercionDirection
    coercions: std.AutoHashMap(u16, CoercionDirection),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var graph = Self{
            .allocator = allocator,
            .coercions = std.AutoHashMap(u16, CoercionDirection).init(allocator),
        };

        try graph.initDefaultRules();
        return graph;
    }

    pub fn deinit(self: *Self) void {
        self.coercions.deinit();
    }

    /// Helper to encode two types into a single key for the coercion matrix
    inline fn encodeKey(from: SimpleType, to: SimpleType) u16 {
        const from_u16: u16 = @intCast(@intFromEnum(from));
        const to_u16: u16 = @intCast(@intFromEnum(to));
        return (from_u16 << 8) | to_u16;
    }

    /// Initialize default type coercion rules
    fn initDefaultRules(self: *Self) !void {
        // Numeric type hierarchy: Int -> Double -> Complex

        // Int can implicitly coerce to Double or Complex
        try self.coercions.put(encodeKey(.Int, .Double), .Implicit);
        try self.coercions.put(encodeKey(.Int, .Complex), .Implicit);

        // Double can implicitly coerce to Complex
        try self.coercions.put(encodeKey(.Double, .Complex), .Implicit);

        // Any numeric type can explicitly coerce to another numeric type
        try self.coercions.put(encodeKey(.Double, .Int), .Explicit);
        try self.coercions.put(encodeKey(.Complex, .Int), .Explicit);
        try self.coercions.put(encodeKey(.Complex, .Double), .Explicit);

        // Types can explicitly coerce to String
        try self.coercions.put(encodeKey(.Int, .String), .Explicit);
        try self.coercions.put(encodeKey(.Double, .String), .Explicit);
        try self.coercions.put(encodeKey(.Complex, .String), .Explicit);
        try self.coercions.put(encodeKey(.Bool, .String), .Explicit);

        // Bool has no implicit conversions
        // (Zig-like: explicit conversions only)

        // Any type can be compared or converted to Any
        try self.coercions.put(encodeKey(.Any, .Any), .Implicit);
    }

    /// Check if a type can be coerced to another
    pub fn canCoerce(self: Self, from: SimpleType, to: SimpleType) CoercionDirection {
        // Same type always coerces implicitly
        if (from == to) return .Implicit;

        // Any type can coerce to Any
        if (to == .Any) return .Implicit;

        // Check the coercion matrix
        return self.coercions.get(encodeKey(from, to)) orelse .None;
    }

    /// Find the "best" common type for two operands (for operator resolution)
    /// Returns the type they should both be coerced to, or .Invalid if incompatible
    pub fn findCommonType(_: *const Self, a: SimpleType, b: SimpleType) SimpleType {
        if (a == b) return a;

        // Numeric type promotion: lower type promotes to higher
        // Int < Double < Complex
        if (a.isNumeric() and b.isNumeric()) {
            if (a == .Complex or b == .Complex) return .Complex;
            if (a == .Double or b == .Double) return .Double;
            return .Int;
        }

        // String concatenation
        if (a == .String or b == .String) return .String;

        // Vector operations
        if (a == .Vector and b == .Vector) return .Vector;

        // Matrix operations
        if (a == .Matrix and b == .Matrix) return .Matrix;

        return .Invalid;
    }

    /// Check if an operation is valid between two types
    /// Returns the result type, or .Invalid if the operation is invalid
    pub fn resolveOperationType(self: Self, op: OperationType, a: SimpleType, b: SimpleType) SimpleType {
        return switch (op) {
            .Add, .Subtract, .Multiply => {
                // Arithmetic operations require numeric types or compatible collections
                if (a.isNumeric() and b.isNumeric()) {
                    return self.findCommonType(a, b);
                }
                // String concatenation
                if ((a == .String or b == .String) and op == .Add) {
                    return .String;
                }
                // Vector/Matrix arithmetic
                if (a == .Vector and b == .Vector) return .Vector;
                if (a == .Matrix and b == .Matrix) return .Matrix;
                return .Invalid;
            },
            .Divide => {
                // Division always returns float-like type
                if (a.isNumeric() and b.isNumeric()) {
                    // Int / Int -> Double
                    // Any numeric / any numeric -> promotes to at least Double
                    if (a == .Int and b == .Int) return .Double;
                    return self.findCommonType(a, b);
                }
                if (a == .Vector and b == .Vector) return .Vector;
                if (a == .Matrix and b == .Matrix) return .Matrix;
                return .Invalid;
            },
            .Modulo, .Exponent => {
                // Modulo and exponent require numeric types
                if (a.isNumeric() and b.isNumeric()) {
                    return self.findCommonType(a, b);
                }
                return .Invalid;
            },
            .Equals, .NotEquals, .Less, .LessOrEqual, .Greater, .GreaterOrEqual => {
                // Comparison always returns bool
                if (a == b or a == .Any or b == .Any) return .Bool;
                // Can compare numeric types
                if (a.isNumeric() and b.isNumeric()) return .Bool;
                // Can compare strings
                if (a == .String and b == .String) return .Bool;
                return .Invalid;
            },
            .And, .Or => {
                // Logical operations require bool
                if (a == .Bool and b == .Bool) return .Bool;
                return .Invalid;
            },
        };
    }
};

/// Types of binary operators
pub const OperationType = enum {
    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
    Exponent,
    Equals,
    NotEquals,
    Less,
    LessOrEqual,
    Greater,
    GreaterOrEqual,
    And,
    Or,
};

// ============================================================================
// Type Checking Results
// ============================================================================

pub const TypeError = error{
    IncompatibleTypes,
    UndefinedVariable,
    InvalidOperation,
    TypeMismatch,
    OutOfMemory,
};

pub const TypeCheckResult = union(enum) {
    Ok: Type,
    Err: struct {
        message: []const u8,
        expected: SimpleType,
        actual: SimpleType,
    },

    const Self = @This();

    pub fn isOk(self: Self) bool {
        return self == .Ok;
    }

    pub fn unwrap(self: Self) !Type {
        return switch (self) {
            .Ok => |t| t,
            .Err => TypeError.TypeMismatch,
        };
    }
};

// ============================================================================
// Type Environment (for storing variable types)
// ============================================================================

pub const TypeEnvironment = struct {
    allocator: Allocator,
    variables: std.StringHashMap(TypeInfo),
    parent: ?*TypeEnvironment = null,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .variables = std.StringHashMap(TypeInfo).init(allocator),
        };
    }

    pub fn initChild(allocator: Allocator, parent: *TypeEnvironment) !Self {
        var env = try Self.init(allocator);
        env.parent = parent;
        return env;
    }

    pub fn deinit(self: *Self) void {
        self.variables.deinit();
    }

    pub fn define(self: *Self, name: []const u8, info: TypeInfo) !void {
        try self.variables.put(name, info);
    }

    pub fn lookup(self: Self, name: []const u8) ?TypeInfo {
        if (self.variables.get(name)) |info| {
            return info;
        }
        if (self.parent) |parent| {
            return parent.lookup(name);
        }
        return null;
    }

    pub fn define_or_update(self: *Self, name: []const u8, info: TypeInfo) !void {
        // Only update in current scope if it exists, otherwise define
        if (self.variables.contains(name)) {
            try self.variables.put(name, info);
        } else {
            try self.variables.put(name, info);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = try TypeCompatibilityGraph.init(allocator);
    defer graph.deinit();

    // Test coercion
    std.debug.print("Int -> Double: {}\n", .{graph.canCoerce(.Int, .Double)});
    std.debug.print("Double -> Int: {}\n", .{graph.canCoerce(.Double, .Int)});
    std.debug.print("Int -> Complex: {}\n", .{graph.canCoerce(.Int, .Complex)});

    // Test common type
    std.debug.print("Common type of Int and Double: {s}\n", .{graph.findCommonType(.Int, .Double).name()});
    std.debug.print("Common type of Double and Complex: {s}\n", .{graph.findCommonType(.Double, .Complex).name()});

    // Test operator type resolution
    const addType = graph.resolveOperationType(.Add, .Int, .Double);
    std.debug.print("Int + Double result type: {s}\n", .{addType.name()});

    const divType = graph.resolveOperationType(.Divide, .Int, .Int);
    std.debug.print("Int / Int result type: {s}\n", .{divType.name()});

    const cmpType = graph.resolveOperationType(.Less, .Int, .Double);
    std.debug.print("Int < Double result type: {s}\n", .{cmpType.name()});
}
