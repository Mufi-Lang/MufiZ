const std = @import("std");
const stdlib_core = @import("../stdlib_core.zig");
const Value = @import("../value.zig").Value;
const object_h = @import("../object.zig");
const mem_utils = @import("../mem_utils.zig");
const SymbolExpr = object_h.SymbolExpr;
const ObjSymbol = object_h.ObjSymbol;

const DefineFunction = stdlib_core.DefineFunction;
const ParamSpec = stdlib_core.ParamSpec;

// ============ Helper Functions ============

fn getAllocator() std.mem.Allocator {
    return mem_utils.getAllocator();
}

fn allocateSymbol(expr: *SymbolExpr) Value {
    const obj = object_h.allocateObject(@sizeOf(ObjSymbol), .OBJ_SYMBOL);
    const sym: *ObjSymbol = @as(*ObjSymbol, @ptrCast(@alignCast(obj)));
    sym.expr = expr;
    return Value.init_obj(@ptrCast(sym));
}

fn allocateStringValue(str: []const u8) Value {
    const str_obj = object_h.copyString(str.ptr, str.len);
    return Value.init_obj(@ptrCast(str_obj));
}

// ============ Implementation Functions ============

fn sym_const_impl(_: i32, args: [*]Value) Value {
    const value = args[0].as_num_double();
    const expr = SymbolExpr.constant(getAllocator(), value) catch unreachable;
    return allocateSymbol(expr);
}

fn sym_var_impl(_: i32, args: [*]Value) Value {
    const name_obj = args[0].as_string();
    const name = name_obj.chars[0..@intCast(name_obj.length)];
    const expr = SymbolExpr.variable(getAllocator(), name) catch unreachable;
    return allocateSymbol(expr);
}

fn sym_to_string_impl(_: i32, args: [*]Value) Value {
    const sym = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const result = sym.expr.toString(getAllocator()) catch unreachable;
    defer getAllocator().free(result);
    return allocateStringValue(result);
}

fn sym_is_constant_impl(_: i32, args: [*]Value) Value {
    const sym = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_bool(sym.expr.isConstant());
}

fn sym_add_impl(_: i32, args: [*]Value) Value {
    const left = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const right = @as(*ObjSymbol, @ptrCast(@alignCast(args[1].as.obj)));
    
    const left_clone = left.expr.clone() catch unreachable;
    const right_clone = right.expr.clone() catch unreachable;
    
    var terms = getAllocator().alloc(*SymbolExpr, 2) catch unreachable;
    terms[0] = left_clone;
    terms[1] = right_clone;
    const result = SymbolExpr.add(getAllocator(), terms) catch unreachable;
    getAllocator().free(terms);
    return allocateSymbol(result);
}

fn sym_sub_impl(_: i32, args: [*]Value) Value {
    const left = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const right = @as(*ObjSymbol, @ptrCast(@alignCast(args[1].as.obj)));
    
    const left_clone = left.expr.clone() catch unreachable;
    const right_clone = right.expr.clone() catch unreachable;
    
    const result = SymbolExpr.subtract(getAllocator(), left_clone, right_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_mul_impl(_: i32, args: [*]Value) Value {
    const left = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const right = @as(*ObjSymbol, @ptrCast(@alignCast(args[1].as.obj)));
    
    const left_clone = left.expr.clone() catch unreachable;
    const right_clone = right.expr.clone() catch unreachable;
    
    var factors = getAllocator().alloc(*SymbolExpr, 2) catch unreachable;
    factors[0] = left_clone;
    factors[1] = right_clone;
    const result = SymbolExpr.multiply(getAllocator(), factors) catch unreachable;
    getAllocator().free(factors);
    return allocateSymbol(result);
}

fn sym_div_impl(_: i32, args: [*]Value) Value {
    const num = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const denom = @as(*ObjSymbol, @ptrCast(@alignCast(args[1].as.obj)));
    
    const num_clone = num.expr.clone() catch unreachable;
    const denom_clone = denom.expr.clone() catch unreachable;
    
    const result = SymbolExpr.divide(getAllocator(), num_clone, denom_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_pow_impl(_: i32, args: [*]Value) Value {
    const base = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const exponent = @as(*ObjSymbol, @ptrCast(@alignCast(args[1].as.obj)));
    
    const base_clone = base.expr.clone() catch unreachable;
    const exp_clone = exponent.expr.clone() catch unreachable;
    const result = SymbolExpr.power(getAllocator(), base_clone, exp_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_negate_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.negate(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_sin_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.sin(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_cos_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.cos(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_tan_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.tan(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_exp_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.exp(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_log_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.log(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_sqrt_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.sqrt(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_abs_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const arg_clone = arg.expr.clone() catch unreachable;
    const result = SymbolExpr.abs(getAllocator(), arg_clone) catch unreachable;
    return allocateSymbol(result);
}

fn sym_derivative_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const wrt_obj = args[1].as_string();
    const wrt = wrt_obj.chars[0..@intCast(wrt_obj.length)];
    
    const result = arg.expr.derivative(getAllocator(), wrt) catch |err| {
        return stdlib_core.stdlib_error("derivative failed: {}", .{err});
    };
    
    return allocateSymbol(result);
}

fn sym_simplify_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const result = arg.expr.simplify() catch unreachable;
    return allocateSymbol(result);
}

fn sym_expand_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const result = arg.expr.expand() catch unreachable;
    return allocateSymbol(result);
}

fn sym_substitute_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    const var_name_obj = args[1].as_string();
    const var_name = var_name_obj.chars[0..@intCast(var_name_obj.length)];
    const val = @as(*ObjSymbol, @ptrCast(@alignCast(args[2].as.obj)));
    
    var substitutions = std.StringHashMap(*SymbolExpr).init(getAllocator());
    substitutions.put(var_name, val.expr) catch unreachable;
    
    const result = arg.expr.substitute(getAllocator(), substitutions) catch |err| {
        substitutions.deinit();
        return stdlib_core.stdlib_error("substitute failed: {}", .{err});
    };
    
    substitutions.deinit();
    return allocateSymbol(result);
}

fn sym_evaluate_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    
    const result = arg.expr.evaluate() catch |err| {
        return switch (err) {
            error.UnsubstitutedVariable => stdlib_core.stdlib_error("Cannot evaluate: unsubstituted variable remains", .{}),
            error.DivisionByZero => stdlib_core.stdlib_error("Division by zero during evaluation", .{}),
            else => stdlib_core.stdlib_error("evaluation failed", .{}),
        };
    };
    
    return Value.init_double(result);
}

fn sym_get_variables_impl(_: i32, args: [*]Value) Value {
    const arg = @as(*ObjSymbol, @ptrCast(@alignCast(args[0].as.obj)));
    
    var vars = std.ArrayList([]const u8).initCapacity(getAllocator(), 10) catch unreachable;
    defer vars.deinit(getAllocator());
    
    arg.expr.getVariables(&vars) catch unreachable;
    
    // Create a linked list to hold the variable names
    const result_list = object_h.LinkedList.init();
    
    for (vars.items) |v| {
        const str_obj = object_h.copyString(v.ptr, v.len);
        result_list.push(Value.init_obj(@ptrCast(str_obj)));
    }
    
    return Value.init_obj(@ptrCast(result_list));
}

// ============ Function Definitions ============

pub const sym_const = DefineFunction(
    "sym_const",
    "symbolic",
    "Create a constant symbolic expression",
    &.{ParamSpec{ .name = "value", .type = .double }},
    .any,
    &.{"sym_const(3.14)"},
    sym_const_impl,
);

pub const sym_var = DefineFunction(
    "sym_var",
    "symbolic",
    "Create a variable symbolic expression",
    &.{ParamSpec{ .name = "name", .type = .string }},
    .any,
    &.{"sym_var(\"x\")"},
    sym_var_impl,
);

pub const sym_to_string = DefineFunction(
    "sym_to_string",
    "symbolic",
    "Convert symbolic expression to string",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .string,
    &.{"sym_to_string(expr)"},
    sym_to_string_impl,
);

pub const sym_is_constant = DefineFunction(
    "sym_is_constant",
    "symbolic",
    "Check if expression is constant",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .bool,
    &.{"sym_is_constant(expr)"},
    sym_is_constant_impl,
);

pub const sym_add = DefineFunction(
    "sym_add",
    "symbolic",
    "Add two symbolic expressions",
    &.{ParamSpec{ .name = "left", .type = .any }, ParamSpec{ .name = "right", .type = .any }},
    .any,
    &.{"sym_add(x, y)"},
    sym_add_impl,
);

pub const sym_sub = DefineFunction(
    "sym_sub",
    "symbolic",
    "Subtract two symbolic expressions",
    &.{ParamSpec{ .name = "left", .type = .any }, ParamSpec{ .name = "right", .type = .any }},
    .any,
    &.{"sym_sub(x, y)"},
    sym_sub_impl,
);

pub const sym_mul = DefineFunction(
    "sym_mul",
    "symbolic",
    "Multiply two symbolic expressions",
    &.{ParamSpec{ .name = "left", .type = .any }, ParamSpec{ .name = "right", .type = .any }},
    .any,
    &.{"sym_mul(x, y)"},
    sym_mul_impl,
);

pub const sym_div = DefineFunction(
    "sym_div",
    "symbolic",
    "Divide two symbolic expressions",
    &.{ParamSpec{ .name = "num", .type = .any }, ParamSpec{ .name = "denom", .type = .any }},
    .any,
    &.{"sym_div(x, y)"},
    sym_div_impl,
);

pub const sym_pow = DefineFunction(
    "sym_pow",
    "symbolic",
    "Raise to power",
    &.{ParamSpec{ .name = "base", .type = .any }, ParamSpec{ .name = "exp", .type = .any }},
    .any,
    &.{"sym_pow(x, 2)"},
    sym_pow_impl,
);

pub const sym_negate = DefineFunction(
    "sym_negate",
    "symbolic",
    "Negate expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_negate(x)"},
    sym_negate_impl,
);

pub const sym_sin = DefineFunction(
    "sym_sin",
    "symbolic",
    "Sine of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_sin(x)"},
    sym_sin_impl,
);

pub const sym_cos = DefineFunction(
    "sym_cos",
    "symbolic",
    "Cosine of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_cos(x)"},
    sym_cos_impl,
);

pub const sym_tan = DefineFunction(
    "sym_tan",
    "symbolic",
    "Tangent of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_tan(x)"},
    sym_tan_impl,
);

pub const sym_exp = DefineFunction(
    "sym_exp",
    "symbolic",
    "Exponential of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_exp(x)"},
    sym_exp_impl,
);

pub const sym_log = DefineFunction(
    "sym_log",
    "symbolic",
    "Natural log of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_log(x)"},
    sym_log_impl,
);

pub const sym_sqrt = DefineFunction(
    "sym_sqrt",
    "symbolic",
    "Square root of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_sqrt(x)"},
    sym_sqrt_impl,
);

pub const sym_abs = DefineFunction(
    "sym_abs",
    "symbolic",
    "Absolute value of expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_abs(x)"},
    sym_abs_impl,
);

pub const sym_derivative = DefineFunction(
    "sym_derivative",
    "symbolic",
    "Compute derivative with respect to a variable",
    &.{ParamSpec{ .name = "expr", .type = .any }, ParamSpec{ .name = "wrt", .type = .string }},
    .any,
    &.{"sym_derivative(expr, \"x\")"},
    sym_derivative_impl,
);

pub const sym_simplify = DefineFunction(
    "sym_simplify",
    "symbolic",
    "Simplify algebraic expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_simplify(expr)"},
    sym_simplify_impl,
);

pub const sym_expand = DefineFunction(
    "sym_expand",
    "symbolic",
    "Expand/distribute algebraic expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_expand(expr)"},
    sym_expand_impl,
);

pub const sym_substitute = DefineFunction(
    "sym_substitute",
    "symbolic",
    "Substitute variable in expression",
    &.{ParamSpec{ .name = "expr", .type = .any }, ParamSpec{ .name = "var_name", .type = .string }, ParamSpec{ .name = "value", .type = .any }},
    .any,
    &.{"sym_substitute(expr, \"x\", 2)"},
    sym_substitute_impl,
);

pub const sym_evaluate = DefineFunction(
    "sym_evaluate",
    "symbolic",
    "Evaluate symbolic expression to numeric value",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .double,
    &.{"sym_evaluate(expr)"},
    sym_evaluate_impl,
);

pub const sym_get_variables = DefineFunction(
    "sym_get_variables",
    "symbolic",
    "Extract all variables from an expression",
    &.{ParamSpec{ .name = "expr", .type = .any }},
    .any,
    &.{"sym_get_variables(expr)"},
    sym_get_variables_impl,
);
