/// Symbolic Expression Support for MufiZ
///
/// This module implements symbolic mathematics capabilities, allowing users to:
/// - Create and manipulate mathematical expressions symbolically
/// - Perform algebraic operations (simplify, expand, collect, factor)
/// - Compute derivatives and integrals
/// - Solve equations
///
/// Expressions are represented as abstract syntax trees (ASTs) where each node
/// represents either a value (variable or constant) or an operation.
const std = @import("std");
const Allocator = std.mem.Allocator;

/// Represents a node in a symbolic expression tree.
/// Uses a tagged union to efficiently represent different expression types.
pub const SymbolNodeType = enum {
    Constant, // Fixed numeric value
    Variable, // Named symbolic variable
    Add, // Binary addition
    Subtract, // Binary subtraction
    Multiply, // Binary multiplication
    Divide, // Binary division
    Power, // Exponentiation (base^exp)
    Negate, // Unary negation
    Sin, // sin(expr)
    Cos, // cos(expr)
    Tan, // tan(expr)
    Exp, // e^expr
    Log, // ln(expr)
    Sqrt, // sqrt(expr)
    Abs, // |expr|
};

/// A node in the symbolic expression tree
pub const SymbolNode = union(SymbolNodeType) {
    Constant: f64,
    Variable: []const u8,
    Add: []*SymbolExpr,
    Subtract: []*SymbolExpr,
    Multiply: []*SymbolExpr,
    Divide: struct { num: *SymbolExpr, denom: *SymbolExpr },
    Power: struct { base: *SymbolExpr, exp: *SymbolExpr },
    Negate: *SymbolExpr,
    Sin: *SymbolExpr,
    Cos: *SymbolExpr,
    Tan: *SymbolExpr,
    Exp: *SymbolExpr,
    Log: *SymbolExpr,
    Sqrt: *SymbolExpr,
    Abs: *SymbolExpr,
};

/// A complete symbolic expression with its AST node
pub const SymbolExpr = struct {
    allocator: Allocator,
    node: SymbolNode,

    const Self = @This();

    /// Create a constant expression
    pub fn constant(allocator: Allocator, value: f64) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Constant = value };
        return expr;
    }

    /// Create a variable expression
    pub fn variable(allocator: Allocator, name: []const u8) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        const name_copy = try allocator.dupe(u8, name);
        expr.node = .{ .Variable = name_copy };
        return expr;
    }

    /// Create an addition expression
    pub fn add(allocator: Allocator, terms: []*SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        const terms_copy = try allocator.dupe(*SymbolExpr, terms);
        expr.node = .{ .Add = terms_copy };
        return expr;
    }

    /// Create a subtraction expression
    pub fn subtract(allocator: Allocator, left: *SymbolExpr, right: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        var terms = try allocator.alloc(*SymbolExpr, 2);
        terms[0] = left;
        terms[1] = right;
        expr.node = .{ .Subtract = terms };
        return expr;
    }

    /// Create a multiplication expression
    pub fn multiply(allocator: Allocator, factors: []*SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        const factors_copy = try allocator.dupe(*SymbolExpr, factors);
        expr.node = .{ .Multiply = factors_copy };
        return expr;
    }

    /// Create a division expression
    pub fn divide(allocator: Allocator, num: *SymbolExpr, denom: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Divide = .{ .num = num, .denom = denom } };
        return expr;
    }

    /// Create a power expression (base^exponent)
    pub fn power(allocator: Allocator, base: *SymbolExpr, exponent: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Power = .{ .base = base, .exp = exponent } };
        return expr;
    }

    /// Create a negation expression (-expr)
    pub fn negate(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Negate = operand };
        return expr;
    }

    /// Create sin(expr)
    pub fn sin(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Sin = operand };
        return expr;
    }

    /// Create cos(expr)
    pub fn cos(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Cos = operand };
        return expr;
    }

    /// Create tan(expr)
    pub fn tan(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Tan = operand };
        return expr;
    }

    /// Create e^expr
    pub fn exp(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Exp = operand };
        return expr;
    }

    /// Create ln(expr)
    pub fn log(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Log = operand };
        return expr;
    }

    /// Create sqrt(expr)
    pub fn sqrt(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Sqrt = operand };
        return expr;
    }

    /// Create |expr|
    pub fn abs(allocator: Allocator, operand: *SymbolExpr) !*Self {
        var expr = try allocator.create(Self);
        expr.allocator = allocator;
        expr.node = .{ .Abs = operand };
        return expr;
    }

    /// Free the expression and all its children
    pub fn deinit(self: *Self) void {
        self.destroyNode(&self.node);
        self.allocator.destroy(self);
    }

    /// Recursively free all nodes in the expression tree
    fn destroyNode(self: *Self, node: *SymbolNode) void {
        switch (node.*) {
            .Constant, .Variable => {
                // Leaf nodes, only need to free strings for variables
                if (node.* == .Variable) {
                    self.allocator.free(node.Variable);
                }
            },
            .Add, .Multiply, .Subtract => {
                const items = switch (node.*) {
                    .Add => node.Add,
                    .Multiply => node.Multiply,
                    .Subtract => node.Subtract,
                    else => unreachable,
                };
                for (items) |item| {
                    item.deinit();
                }
                self.allocator.free(items);
            },
            .Divide => {
                node.Divide.num.deinit();
                node.Divide.denom.deinit();
            },
            .Power => {
                node.Power.base.deinit();
                node.Power.exp.deinit();
            },
            .Negate, .Sin, .Cos, .Tan, .Exp, .Log, .Sqrt, .Abs => {
                const operand = switch (node.*) {
                    .Negate => node.Negate,
                    .Sin => node.Sin,
                    .Cos => node.Cos,
                    .Tan => node.Tan,
                    .Exp => node.Exp,
                    .Log => node.Log,
                    .Sqrt => node.Sqrt,
                    .Abs => node.Abs,
                    else => unreachable,
                };
                operand.deinit();
            },
        }
    }

    /// Clone the entire expression tree
    pub fn clone(self: *const Self) anyerror!*SymbolExpr {
        return self.cloneNode(&self.node, self.allocator);
    }

    /// Recursively clone a node and all its children
    fn cloneNode(_: *const Self, node: *const SymbolNode, allocator: Allocator) anyerror!*SymbolExpr {
        return switch (node.*) {
            .Constant => |val| try SymbolExpr.constant(allocator, val),
            .Variable => |name| try SymbolExpr.variable(allocator, name),
            .Add => |terms| blk: {
                var cloned_terms = try allocator.alloc(*SymbolExpr, terms.len);
                for (terms, 0..) |term, i| {
                    cloned_terms[i] = try term.clone();
                }
                break :blk try SymbolExpr.add(allocator, cloned_terms);
            },
            .Subtract => |terms| blk: {
                const left = try terms[0].clone();
                const right = try terms[1].clone();
                break :blk try SymbolExpr.subtract(allocator, left, right);
            },
            .Multiply => |factors| blk: {
                var cloned_factors = try allocator.alloc(*SymbolExpr, factors.len);
                for (factors, 0..) |factor, i| {
                    cloned_factors[i] = try factor.clone();
                }
                break :blk try SymbolExpr.multiply(allocator, cloned_factors);
            },
            .Divide => |div| blk: {
                const num = try div.num.clone();
                const denom = try div.denom.clone();
                break :blk try SymbolExpr.divide(allocator, num, denom);
            },
            .Power => |pow| blk: {
                const base = try pow.base.clone();
                const exponent = try pow.exp.clone();
                break :blk try SymbolExpr.power(allocator, base, exponent);
            },
            .Negate => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.negate(allocator, cloned);
            },
            .Sin => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.sin(allocator, cloned);
            },
            .Cos => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.cos(allocator, cloned);
            },
            .Tan => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.tan(allocator, cloned);
            },
            .Exp => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.exp(allocator, cloned);
            },
            .Log => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.log(allocator, cloned);
            },
            .Sqrt => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.sqrt(allocator, cloned);
            },
            .Abs => |operand| blk: {
                const cloned = try operand.clone();
                break :blk try SymbolExpr.abs(allocator, cloned);
            },
        };
    }

    /// Convert expression to infix notation string (e.g., "2*x + 3*y")
    pub fn toString(self: *const Self, allocator: Allocator) ![]u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 128);
        defer buffer.deinit(allocator);
        try self.nodeToString(&self.node, &buffer, false, allocator);
        return try buffer.toOwnedSlice(allocator);
    }

    /// Recursively convert node to string, handling operator precedence
    fn nodeToString(self: *const Self, node: *const SymbolNode, buffer: *std.ArrayList(u8), parent_needs_parens: bool, allocator: Allocator) !void {
        switch (node.*) {
            .Constant => |val| {
                if (@rem(val, 1.0) == 0) {
                    var temp_buf: [64]u8 = undefined;
                    const str = try std.fmt.bufPrint(&temp_buf, "{d:.0}", .{val});
                    try buffer.appendSlice(allocator, str);
                } else {
                    var temp_buf: [64]u8 = undefined;
                    const str = try std.fmt.bufPrint(&temp_buf, "{d}", .{val});
                    try buffer.appendSlice(allocator, str);
                }
            },
            .Variable => |name| {
                try buffer.appendSlice(allocator, name);
            },
            .Add => |terms| {
                if (parent_needs_parens) try buffer.appendSlice(allocator, "(");
                for (terms, 0..) |term, i| {
                    if (i > 0) try buffer.appendSlice(allocator, " + ");
                    try self.nodeToString(&term.node, buffer, false, allocator);
                }
                if (parent_needs_parens) try buffer.appendSlice(allocator, ")");
            },
            .Subtract => |terms| {
                if (parent_needs_parens) try buffer.appendSlice(allocator, "(");
                try self.nodeToString(&terms[0].node, buffer, false, allocator);
                try buffer.appendSlice(allocator, " - ");
                try self.nodeToString(&terms[1].node, buffer, false, allocator);
                if (parent_needs_parens) try buffer.appendSlice(allocator, ")");
            },
            .Multiply => |factors| {
                if (parent_needs_parens) try buffer.appendSlice(allocator, "(");
                for (factors, 0..) |factor, i| {
                    if (i > 0) try buffer.appendSlice(allocator, "*");
                    const needs_parens = switch (factor.node) {
                        .Add, .Subtract => true,
                        else => false,
                    };
                    try self.nodeToString(&factor.node, buffer, needs_parens, allocator);
                }
                if (parent_needs_parens) try buffer.appendSlice(allocator, ")");
            },
            .Divide => |div| {
                if (parent_needs_parens) try buffer.appendSlice(allocator, "(");
                const needs_parens = switch (div.num.node) {
                    .Add, .Subtract => true,
                    else => false,
                };
                try self.nodeToString(&div.num.node, buffer, needs_parens, allocator);
                try buffer.appendSlice(allocator, "/");
                const denom_needs_parens = switch (div.denom.node) {
                    .Add, .Subtract, .Multiply => true,
                    else => false,
                };
                try self.nodeToString(&div.denom.node, buffer, denom_needs_parens, allocator);
                if (parent_needs_parens) try buffer.appendSlice(allocator, ")");
            },
            .Power => |pow| {
                if (parent_needs_parens) try buffer.appendSlice(allocator, "(");
                const needs_parens = switch (pow.base.node) {
                    .Add, .Subtract, .Multiply, .Divide => true,
                    else => false,
                };
                try self.nodeToString(&pow.base.node, buffer, needs_parens, allocator);
                try buffer.appendSlice(allocator, "^");
                const exp_needs_parens = switch (pow.exp.node) {
                    .Add, .Subtract, .Multiply, .Divide => true,
                    else => false,
                };
                try self.nodeToString(&pow.exp.node, buffer, exp_needs_parens, allocator);
                if (parent_needs_parens) try buffer.appendSlice(allocator, ")");
            },
            .Negate => |operand| {
                try buffer.appendSlice(allocator, "-");
                const needs_parens = switch (operand.node) {
                    .Add, .Subtract => true,
                    else => false,
                };
                try self.nodeToString(&operand.node, buffer, needs_parens, allocator);
            },
            .Sin => |operand| {
                try buffer.appendSlice(allocator, "sin(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Cos => |operand| {
                try buffer.appendSlice(allocator, "cos(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Tan => |operand| {
                try buffer.appendSlice(allocator, "tan(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Exp => |operand| {
                try buffer.appendSlice(allocator, "exp(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Log => |operand| {
                try buffer.appendSlice(allocator, "log(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Sqrt => |operand| {
                try buffer.appendSlice(allocator, "sqrt(");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, ")");
            },
            .Abs => |operand| {
                try buffer.appendSlice(allocator, "|");
                try self.nodeToString(&operand.node, buffer, false, allocator);
                try buffer.appendSlice(allocator, "|");
            },
        }
    }

    /// Check if this expression is a constant
    pub fn isConstant(self: *const Self) bool {
        return switch (self.node) {
            .Constant => true,
            else => false,
        };
    }

    /// Check if this expression is a variable
    pub fn isVariable(self: *const Self) bool {
        return switch (self.node) {
            .Variable => true,
            else => false,
        };
    }

    /// Get the numeric value if this is a constant
    pub fn getConstantValue(self: *const Self) ?f64 {
        return switch (self.node) {
            .Constant => |val| val,
            else => null,
        };
    }

    /// Get the variable name if this is a variable
    pub fn getVariableName(self: *const Self) ?[]const u8 {
        return switch (self.node) {
            .Variable => |name| name,
            else => null,
        };
    }
};

/// Wrapper object stored in the VM as OBJ_SYMBOL
pub const ObjSymbol = struct {
    obj: object_h.Obj,
    expr: *SymbolExpr,

    const Self = @This();

    pub fn create(allocator: Allocator, obj_ptr: *object_h.Obj, expr: *SymbolExpr) !*Self {
        var sym = try allocator.create(Self);
        sym.obj = obj_ptr.*;
        sym.expr = expr;
        return sym;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.expr.deinit();
        allocator.destroy(self);
    }
};

// Import object types
const object_h = @import("../object.zig");
