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

    /// Evaluate the expression to a numeric value
    /// Returns error.UnsubstitutedVariable if any variable remains
    /// Returns error.DivisionByZero if division by zero occurs
    pub fn evaluate(self: *const Self) anyerror!f64 {
        return switch (self.node) {
            .Constant => |val| val,
            .Variable => error.UnsubstitutedVariable,
            .Add => |terms| {
                var sum: f64 = 0;
                for (terms) |term| {
                    sum += try term.evaluate();
                }
                return sum;
            },
            .Subtract => |terms| {
                const left = try terms[0].evaluate();
                const right = try terms[1].evaluate();
                return left - right;
            },
            .Multiply => |factors| {
                var product: f64 = 1;
                for (factors) |factor| {
                    product *= try factor.evaluate();
                }
                return product;
            },
            .Divide => |div| {
                const num = try div.num.evaluate();
                const denom = try div.denom.evaluate();
                if (denom == 0) return error.DivisionByZero;
                return num / denom;
            },
            .Power => |pow| {
                const base = try pow.base.evaluate();
                const exponent = try pow.exp.evaluate();
                return std.math.pow(f64, base, exponent);
            },
            .Negate => |operand| {
                return -(try operand.evaluate());
            },
            .Sin => |operand| {
                return std.math.sin(try operand.evaluate());
            },
            .Cos => |operand| {
                return std.math.cos(try operand.evaluate());
            },
            .Tan => |operand| {
                return std.math.tan(try operand.evaluate());
            },
            .Exp => |operand| {
                return std.math.exp(try operand.evaluate());
            },
            .Log => |operand| {
                return std.math.log(f64, std.math.e, try operand.evaluate());
            },
            .Sqrt => |operand| {
                return std.math.sqrt(try operand.evaluate());
            },
            .Abs => |operand| {
                return @abs(try operand.evaluate());
            },
        };
    }

    /// Substitute variables with their replacement expressions
    pub fn substitute(self: *const Self, allocator: Allocator, replacements: std.StringHashMap(*SymbolExpr)) anyerror!*Self {
        return switch (self.node) {
            .Constant => try SymbolExpr.constant(allocator, self.node.Constant),
            .Variable => |name| {
                if (replacements.get(name)) |replacement| {
                    return try replacement.clone();
                }
                return try SymbolExpr.variable(allocator, name);
            },
            .Add => |terms| {
                var new_terms = try allocator.alloc(*SymbolExpr, terms.len);
                for (terms, 0..) |term, i| {
                    new_terms[i] = try term.substitute(allocator, replacements);
                }
                return try SymbolExpr.add(allocator, new_terms);
            },
            .Subtract => |terms| {
                const left = try terms[0].substitute(allocator, replacements);
                const right = try terms[1].substitute(allocator, replacements);
                return try SymbolExpr.subtract(allocator, left, right);
            },
            .Multiply => |factors| {
                var new_factors = try allocator.alloc(*SymbolExpr, factors.len);
                for (factors, 0..) |factor, i| {
                    new_factors[i] = try factor.substitute(allocator, replacements);
                }
                return try SymbolExpr.multiply(allocator, new_factors);
            },
            .Divide => |div| {
                const num = try div.num.substitute(allocator, replacements);
                const denom = try div.denom.substitute(allocator, replacements);
                return try SymbolExpr.divide(allocator, num, denom);
            },
            .Power => |pow| {
                const base = try pow.base.substitute(allocator, replacements);
                const exponent = try pow.exp.substitute(allocator, replacements);
                return try SymbolExpr.power(allocator, base, exponent);
            },
            .Negate => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.negate(allocator, new_operand);
            },
            .Sin => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.sin(allocator, new_operand);
            },
            .Cos => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.cos(allocator, new_operand);
            },
            .Tan => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.tan(allocator, new_operand);
            },
            .Exp => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.exp(allocator, new_operand);
            },
            .Log => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.log(allocator, new_operand);
            },
            .Sqrt => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.sqrt(allocator, new_operand);
            },
            .Abs => |operand| {
                const new_operand = try operand.substitute(allocator, replacements);
                return try SymbolExpr.abs(allocator, new_operand);
            },
        };
    }

    /// Compute the derivative with respect to a variable
    pub fn derivative(self: *const Self, allocator: Allocator, var_name: []const u8) anyerror!*Self {
        return switch (self.node) {
            .Constant => try SymbolExpr.constant(allocator, 0),
            .Variable => |name| {
                if (std.mem.eql(u8, name, var_name)) {
                    return try SymbolExpr.constant(allocator, 1);
                }
                return try SymbolExpr.constant(allocator, 0);
            },
            .Add => |terms| {
                var new_terms = try allocator.alloc(*SymbolExpr, terms.len);
                for (terms, 0..) |term, i| {
                    new_terms[i] = try term.derivative(allocator, var_name);
                }
                return try SymbolExpr.add(allocator, new_terms);
            },
            .Subtract => |terms| {
                const left = try terms[0].derivative(allocator, var_name);
                const right = try terms[1].derivative(allocator, var_name);
                return try SymbolExpr.subtract(allocator, left, right);
            },
            .Multiply => |factors| {
                var sum_terms = try allocator.alloc(*SymbolExpr, factors.len);
                for (factors, 0..) |_, i| {
                    var product_factors = try allocator.alloc(*SymbolExpr, factors.len);
                    for (factors, 0..) |factor, j| {
                        if (i == j) {
                            product_factors[j] = try factor.derivative(allocator, var_name);
                        } else {
                            product_factors[j] = try factor.clone();
                        }
                    }
                    sum_terms[i] = try SymbolExpr.multiply(allocator, product_factors);
                }
                return try SymbolExpr.add(allocator, sum_terms);
            },
            .Divide => |div| {
                const u = div.num;
                const v = div.denom;
                const u_prime = try u.derivative(allocator, var_name);
                const v_prime = try v.derivative(allocator, var_name);
                const numerator_left = blk: {
                    var factors = try allocator.alloc(*SymbolExpr, 2);
                    factors[0] = u_prime;
                    factors[1] = try v.clone();
                    break :blk try SymbolExpr.multiply(allocator, factors);
                };
                const numerator_right = blk: {
                    var factors = try allocator.alloc(*SymbolExpr, 2);
                    factors[0] = try u.clone();
                    factors[1] = v_prime;
                    break :blk try SymbolExpr.multiply(allocator, factors);
                };
                const numerator = try SymbolExpr.subtract(allocator, numerator_left, numerator_right);
                const denominator = blk: {
                    var factors = try allocator.alloc(*SymbolExpr, 2);
                    factors[0] = try v.clone();
                    factors[1] = try v.clone();
                    break :blk try SymbolExpr.multiply(allocator, factors);
                };
                return try SymbolExpr.divide(allocator, numerator, denominator);
            },
            .Power => |pow| {
                const base = pow.base;
                const exponent = pow.exp;
                const n_minus_1 = blk: {
                    if (exponent.node == .Constant) {
                        break :blk try SymbolExpr.constant(allocator, exponent.node.Constant - 1);
                    }
                    const one = try SymbolExpr.constant(allocator, 1);
                    break :blk try SymbolExpr.subtract(allocator, try exponent.clone(), one);
                };
                const power_part = try SymbolExpr.power(allocator, try base.clone(), n_minus_1);
                const base_prime = try base.derivative(allocator, var_name);
                var factors = try allocator.alloc(*SymbolExpr, 3);
                factors[0] = try exponent.clone();
                factors[1] = power_part;
                factors[2] = base_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Negate => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                return try SymbolExpr.negate(allocator, operand_prime);
            },
            .Sin => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const cos_operand = try SymbolExpr.cos(allocator, try operand.clone());
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = cos_operand;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Cos => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const sin_operand = try SymbolExpr.sin(allocator, try operand.clone());
                const neg_sin = try SymbolExpr.negate(allocator, sin_operand);
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = neg_sin;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Tan => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const two = try SymbolExpr.constant(allocator, 2);
                const cos_operand = try SymbolExpr.cos(allocator, try operand.clone());
                const cos_squared = try SymbolExpr.power(allocator, cos_operand, two);
                const sec_squared = blk: {
                    const one = try SymbolExpr.constant(allocator, 1);
                    break :blk try SymbolExpr.divide(allocator, one, cos_squared);
                };
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = sec_squared;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Exp => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const exp_operand = try SymbolExpr.exp(allocator, try operand.clone());
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = exp_operand;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Log => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const one = try SymbolExpr.constant(allocator, 1);
                const reciprocal = try SymbolExpr.divide(allocator, one, try operand.clone());
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = reciprocal;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Sqrt => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const two = try SymbolExpr.constant(allocator, 2);
                const half = try SymbolExpr.constant(allocator, 0.5);
                const sqrt_operand = try SymbolExpr.power(allocator, try operand.clone(), half);
                const reciprocal = try SymbolExpr.divide(allocator, two, sqrt_operand);
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = reciprocal;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
            .Abs => |operand| {
                const operand_prime = try operand.derivative(allocator, var_name);
                const operand_cloned = try operand.clone();
                const abs_operand = try SymbolExpr.abs(allocator, operand_cloned);
                const reciprocal = try SymbolExpr.divide(allocator, try operand.clone(), abs_operand);
                var factors = try allocator.alloc(*SymbolExpr, 2);
                factors[0] = reciprocal;
                factors[1] = operand_prime;
                return try SymbolExpr.multiply(allocator, factors);
            },
        };
    }

    /// Simplify the expression by constant folding and algebraic reduction
    pub fn simplify(self: *const Self) anyerror!*Self {
        return switch (self.node) {
            .Constant => try SymbolExpr.constant(self.allocator, self.node.Constant),
            .Variable => |name| try SymbolExpr.variable(self.allocator, name),
            .Add => |terms| {
                var simplified_terms = try std.ArrayList(*SymbolExpr).initCapacity(self.allocator, terms.len);
                defer simplified_terms.deinit(self.allocator);
                
                var constant_sum: f64 = 0;
                for (terms) |term| {
                    const simp = try term.simplify();
                    if (simp.node == .Constant) {
                        constant_sum += simp.node.Constant;
                        simp.deinit();
                    } else {
                        try simplified_terms.append(self.allocator, simp);
                    }
                }
                if (constant_sum != 0) {
                    try simplified_terms.append(self.allocator, try SymbolExpr.constant(self.allocator, constant_sum));
                }
                if (simplified_terms.items.len == 0) {
                    return try SymbolExpr.constant(self.allocator, 0);
                }
                if (simplified_terms.items.len == 1) {
                    const result = simplified_terms.items[0];
                    return result;
                }
                return try SymbolExpr.add(self.allocator, try self.allocator.dupe(*SymbolExpr, simplified_terms.items));
            },
            .Subtract => |terms| {
                const left = try terms[0].simplify();
                const right = try terms[1].simplify();
                if (left.node == .Constant and right.node == .Constant) {
                    const result = left.node.Constant - right.node.Constant;
                    left.deinit();
                    right.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.subtract(self.allocator, left, right);
            },
            .Multiply => |factors| {
                var simplified_factors = try std.ArrayList(*SymbolExpr).initCapacity(self.allocator, factors.len);
                defer simplified_factors.deinit(self.allocator);
                
                var constant_product: f64 = 1;
                for (factors) |factor| {
                    const simp = try factor.simplify();
                    if (simp.node == .Constant) {
                        constant_product *= simp.node.Constant;
                        simp.deinit();
                    } else {
                        try simplified_factors.append(self.allocator, simp);
                    }
                }
                if (constant_product == 0) {
                    return try SymbolExpr.constant(self.allocator, 0);
                }
                if (constant_product != 1) {
                    try simplified_factors.append(self.allocator, try SymbolExpr.constant(self.allocator, constant_product));
                }
                if (simplified_factors.items.len == 0) {
                    return try SymbolExpr.constant(self.allocator, 1);
                }
                if (simplified_factors.items.len == 1) {
                    return simplified_factors.items[0];
                }
                return try SymbolExpr.multiply(self.allocator, try self.allocator.dupe(*SymbolExpr, simplified_factors.items));
            },
            .Divide => |div| {
                const num = try div.num.simplify();
                const denom = try div.denom.simplify();
                if (num.node == .Constant and denom.node == .Constant) {
                    if (denom.node.Constant == 0) {
                        num.deinit();
                        denom.deinit();
                        return error.DivisionByZero;
                    }
                    const result = num.node.Constant / denom.node.Constant;
                    num.deinit();
                    denom.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.divide(self.allocator, num, denom);
            },
            .Power => |pow| {
                const base = try pow.base.simplify();
                const exponent = try pow.exp.simplify();
                if (base.node == .Constant and exponent.node == .Constant) {
                    const result = std.math.pow(f64, base.node.Constant, exponent.node.Constant);
                    base.deinit();
                    exponent.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.power(self.allocator, base, exponent);
            },
            .Negate => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = -simp.node.Constant;
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.negate(self.allocator, simp);
            },
            .Sin => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.sin(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.sin(self.allocator, simp);
            },
            .Cos => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.cos(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.cos(self.allocator, simp);
            },
            .Tan => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.tan(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.tan(self.allocator, simp);
            },
            .Exp => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.exp(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.exp(self.allocator, simp);
            },
            .Log => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.log(f64, std.math.e, simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.log(self.allocator, simp);
            },
            .Sqrt => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = std.math.sqrt(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.sqrt(self.allocator, simp);
            },
            .Abs => |operand| {
                const simp = try operand.simplify();
                if (simp.node == .Constant) {
                    const result = @abs(simp.node.Constant);
                    simp.deinit();
                    return try SymbolExpr.constant(self.allocator, result);
                }
                return try SymbolExpr.abs(self.allocator, simp);
            },
        };
    }

    /// Expand the expression by distributing multiplications
    pub fn expand(self: *const Self) anyerror!*Self {
        return switch (self.node) {
            .Constant, .Variable => try self.clone(),
            .Add => |terms| {
                var expanded_terms = try std.ArrayList(*SymbolExpr).initCapacity(self.allocator, terms.len);
                defer expanded_terms.deinit(self.allocator);
                
                for (terms) |term| {
                    try expanded_terms.append(self.allocator, try term.expand());
                }
                return try SymbolExpr.add(self.allocator, try self.allocator.dupe(*SymbolExpr, expanded_terms.items));
            },
            .Subtract => |terms| {
                const left = try terms[0].expand();
                const right = try terms[1].expand();
                return try SymbolExpr.subtract(self.allocator, left, right);
            },
            .Multiply => |factors| {
                var expanded = try factors[0].expand();
                for (factors[1..]) |factor| {
                    const expanded_factor = try factor.expand();
                    expanded = try distributiveMultiply(self.allocator, expanded, expanded_factor);
                }
                return expanded;
            },
            .Divide => |div| {
                const num = try div.num.expand();
                const denom = try div.denom.expand();
                return try SymbolExpr.divide(self.allocator, num, denom);
            },
            .Power => |pow| {
                const base = try pow.base.expand();
                const exponent = try pow.exp.expand();
                return try SymbolExpr.power(self.allocator, base, exponent);
            },
            .Negate => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.negate(self.allocator, expanded);
            },
            .Sin => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.sin(self.allocator, expanded);
            },
            .Cos => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.cos(self.allocator, expanded);
            },
            .Tan => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.tan(self.allocator, expanded);
            },
            .Exp => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.exp(self.allocator, expanded);
            },
            .Log => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.log(self.allocator, expanded);
            },
            .Sqrt => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.sqrt(self.allocator, expanded);
            },
            .Abs => |operand| {
                const expanded = try operand.expand();
                return try SymbolExpr.abs(self.allocator, expanded);
            },
        };
    }

    /// Extract all variables from the expression
    pub fn getVariables(self: *const Self, variables: *std.ArrayList([]const u8)) anyerror!void {
        return switch (self.node) {
            .Constant => {},
            .Variable => |name| {
                try variables.append(self.allocator, name);
            },
            .Add => |terms| {
                for (terms) |term| {
                    try term.getVariables(variables);
                }
            },
            .Subtract => |terms| {
                for (terms) |term| {
                    try term.getVariables(variables);
                }
            },
            .Multiply => |factors| {
                for (factors) |factor| {
                    try factor.getVariables(variables);
                }
            },
            .Divide => |div| {
                try div.num.getVariables(variables);
                try div.denom.getVariables(variables);
            },
            .Power => |pow| {
                try pow.base.getVariables(variables);
                try pow.exp.getVariables(variables);
            },
            .Negate => |operand| {
                try operand.getVariables(variables);
            },
            .Sin, .Cos, .Tan, .Exp, .Log, .Sqrt, .Abs => |operand| {
                try operand.getVariables(variables);
            },
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

/// Helper function to distribute multiplication over addition
/// Handles (a+b)*c and a*(b+c)
fn distributiveMultiply(allocator: Allocator, left: *SymbolExpr, right: *SymbolExpr) anyerror!*SymbolExpr {
    if (left.node == .Add) {
        var result_terms = try std.ArrayList(*SymbolExpr).initCapacity(allocator, left.node.Add.len);
        defer result_terms.deinit(allocator);
        for (left.node.Add) |term| {
            var factors = try allocator.alloc(*SymbolExpr, 2);
            factors[0] = term;
            factors[1] = try right.clone();
            try result_terms.append(allocator, try SymbolExpr.multiply(allocator, factors));
        }
        return try SymbolExpr.add(allocator, try allocator.dupe(*SymbolExpr, result_terms.items));
    }
    if (right.node == .Add) {
        var result_terms = try std.ArrayList(*SymbolExpr).initCapacity(allocator, right.node.Add.len);
        defer result_terms.deinit(allocator);
        for (right.node.Add) |term| {
            var factors = try allocator.alloc(*SymbolExpr, 2);
            factors[0] = try left.clone();
            factors[1] = term;
            try result_terms.append(allocator, try SymbolExpr.multiply(allocator, factors));
        }
        return try SymbolExpr.add(allocator, try allocator.dupe(*SymbolExpr, result_terms.items));
    }
    var factors = try allocator.alloc(*SymbolExpr, 2);
    factors[0] = left;
    factors[1] = right;
    return try SymbolExpr.multiply(allocator, factors);
}

// Import object types
const object_h = @import("../object.zig");
