const std = @import("std");
const Value = @import("../value.zig").Value;
const object_h = @import("../object.zig");
const Tensor = object_h.Tensor;
const stdlib_core = @import("../stdlib_core.zig");

// Basic tensor creation functions

fn tensor_eye_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_INT) {
        return stdlib_core.stdlib_error("tensor_eye() requires integer argument", .{});
    }

    const n: usize = @intCast(argv[0].as_int());
    const t = Tensor.eye(n);
    return Value.init_obj(@ptrCast(t));
}

fn tensor_zeros_1d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_INT) {
        return stdlib_core.stdlib_error("tensor_zeros_1d() requires integer argument", .{});
    }

    const n: usize = @intCast(argv[0].as_int());
    const shape = [_]usize{n};
    const t = Tensor.zeros(&shape);
    return Value.init_obj(@ptrCast(t));
}

fn tensor_ones_1d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_INT) {
        return stdlib_core.stdlib_error("tensor_ones_1d() requires integer argument", .{});
    }

    const n: usize = @intCast(argv[0].as_int());
    const shape = [_]usize{n};
    const t = Tensor.ones(&shape);
    return Value.init_obj(@ptrCast(t));
}

fn tensor_rank_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    return Value.init_int(@intCast(t.rank));
}

fn tensor_total_size_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    return Value.init_int(@intCast(t.size()));
}

fn tensor_get_1d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Second argument must be an integer", .{});
    }

    const t = argv[0].as_tensor();
    const i: usize = @intCast(argv[1].as_int());

    return Value.init_double(t.get1D(i));
}

fn tensor_set_1d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Second argument must be an integer", .{});
    }
    if (argv[2].type != .VAL_DOUBLE and argv[2].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Third argument must be a number", .{});
    }

    const t = argv[0].as_tensor();
    const i: usize = @intCast(argv[1].as_int());
    const val = if (argv[2].type == .VAL_DOUBLE) argv[2].as_double() else @as(f64, @floatFromInt(argv[2].as_int()));

    t.set1D(i, val);
    return Value.init_nil();
}

fn tensor_get_2d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_INT or argv[2].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Indices must be integers", .{});
    }

    const t = argv[0].as_tensor();
    const i: usize = @intCast(argv[1].as_int());
    const j: usize = @intCast(argv[2].as_int());

    return Value.init_double(t.get2D(i, j));
}

fn tensor_set_2d_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_INT or argv[2].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Indices must be integers", .{});
    }
    if (argv[3].type != .VAL_DOUBLE and argv[3].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Value must be a number", .{});
    }

    const t = argv[0].as_tensor();
    const i: usize = @intCast(argv[1].as_int());
    const j: usize = @intCast(argv[2].as_int());
    const val = if (argv[3].type == .VAL_DOUBLE) argv[3].as_double() else @as(f64, @floatFromInt(argv[3].as_int()));

    t.set2D(i, j, val);
    return Value.init_nil();
}

fn tensor_sum_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    return Value.init_double(t.sum());
}

fn tensor_mean_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    return Value.init_double(t.mean());
}

fn tensor_flatten_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    const flattened = t.flatten();
    return Value.init_obj(@ptrCast(flattened));
}

fn tensor_transpose_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Argument must be a tensor", .{});
    }

    const t = argv[0].as_tensor();
    const result = t.transpose();
    if (result == null) {
        return stdlib_core.stdlib_error("Transpose only works on 2D tensors", .{});
    }
    return Value.init_obj(@ptrCast(result.?));
}

fn tensor_add_scalar_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_DOUBLE and argv[1].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Second argument must be a number", .{});
    }

    const t = argv[0].as_tensor();
    const scalar = if (argv[1].type == .VAL_DOUBLE) argv[1].as_double() else @as(f64, @floatFromInt(argv[1].as_int()));
    const result = t.addScalar(scalar);
    return Value.init_obj(@ptrCast(result));
}

fn tensor_scalar_multiply_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_DOUBLE and argv[1].type != .VAL_INT) {
        return stdlib_core.stdlib_error("Second argument must be a number", .{});
    }

    const t = argv[0].as_tensor();
    const scalar = if (argv[1].type == .VAL_DOUBLE) argv[1].as_double() else @as(f64, @floatFromInt(argv[1].as_int()));
    const result = t.scalarMultiply(scalar);
    return Value.init_obj(@ptrCast(result));
}

fn tensor_add_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_OBJ or argv[1].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Second argument must be a tensor", .{});
    }

    const t1 = argv[0].as_tensor();
    const t2 = argv[1].as_tensor();
    if (t1.add(t2.*)) |result| {
        return Value.init_obj(@ptrCast(result));
    } else {
        return stdlib_core.stdlib_error("Tensors must have the same shape", .{});
    }
}

fn tensor_subtract_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_OBJ or argv[1].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Second argument must be a tensor", .{});
    }

    const t1 = argv[0].as_tensor();
    const t2 = argv[1].as_tensor();
    if (t1.subtract(t2.*)) |result| {
        return Value.init_obj(@ptrCast(result));
    } else {
        return stdlib_core.stdlib_error("Tensors must have the same shape", .{});
    }
}

fn tensor_elem_multiply_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_OBJ or argv[1].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Second argument must be a tensor", .{});
    }

    const t1 = argv[0].as_tensor();
    const t2 = argv[1].as_tensor();
    if (t1.multiply(t2.*)) |result| {
        return Value.init_obj(@ptrCast(result));
    } else {
        return stdlib_core.stdlib_error("Tensors must have the same shape", .{});
    }
}

fn tensor_elem_divide_impl(_: i32, argv: [*]Value) Value {
    if (argv[0].type != .VAL_OBJ or argv[0].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("First argument must be a tensor", .{});
    }
    if (argv[1].type != .VAL_OBJ or argv[1].as.obj.?.type != .OBJ_TENSOR) {
        return stdlib_core.stdlib_error("Second argument must be a tensor", .{});
    }

    const t1 = argv[0].as_tensor();
    const t2 = argv[1].as_tensor();
    if (t1.divide(t2.*)) |result| {
        return Value.init_obj(@ptrCast(result));
    } else {
        return stdlib_core.stdlib_error("Tensors must have the same shape", .{});
    }
}

// Function definitions
pub const tensor_eye = stdlib_core.DefineFunction(
    "tensor_eye",
    "tensor",
    "Create an identity matrix (2D tensor)",
    &[_]stdlib_core.ParamSpec{.{ .name = "n", .type = .int }},
    .object,
    &[_][]const u8{"tensor_eye(3) -> 3×3 identity matrix"},
    tensor_eye_impl,
);

pub const tensor_rank = stdlib_core.DefineFunction(
    "tensor_rank",
    "tensor",
    "Get the rank (number of dimensions) of a tensor",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .int,
    &[_][]const u8{"tensor_rank(t) -> 2 for a matrix"},
    tensor_rank_impl,
);

pub const tensor_total_size = stdlib_core.DefineFunction(
    "tensor_total_size",
    "tensor",
    "Get total number of elements in tensor",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .int,
    &[_][]const u8{"tensor_total_size(t) -> total elements"},
    tensor_total_size_impl,
);

pub const tensor_get_1d = stdlib_core.DefineFunction(
    "tensor_get_1d",
    "tensor",
    "Get element from 1D tensor (vector)",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "index", .type = .int } },
    .double,
    &[_][]const u8{"tensor_get_1d(v, 0)"},
    tensor_get_1d_impl,
);

pub const tensor_set_1d = stdlib_core.DefineFunction(
    "tensor_set_1d",
    "tensor",
    "Set element in 1D tensor (vector)",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "index", .type = .int }, .{ .name = "value", .type = .double } },
    .nil,
    &[_][]const u8{"tensor_set_1d(v, 0, 5.0)"},
    tensor_set_1d_impl,
);

pub const tensor_get_2d = stdlib_core.DefineFunction(
    "tensor_get_2d",
    "tensor",
    "Get element from 2D tensor (matrix)",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "row", .type = .int }, .{ .name = "col", .type = .int } },
    .double,
    &[_][]const u8{"tensor_get_2d(m, 0, 1)"},
    tensor_get_2d_impl,
);

pub const tensor_set_2d = stdlib_core.DefineFunction(
    "tensor_set_2d",
    "tensor",
    "Set element in 2D tensor (matrix)",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "row", .type = .int }, .{ .name = "col", .type = .int }, .{ .name = "value", .type = .double } },
    .nil,
    &[_][]const u8{"tensor_set_2d(m, 0, 1, 3.14)"},
    tensor_set_2d_impl,
);

pub const tensor_sum = stdlib_core.DefineFunction(
    "tensor_sum",
    "tensor",
    "Sum all elements in tensor",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .double,
    &[_][]const u8{"tensor_sum(t)"},
    tensor_sum_impl,
);

pub const tensor_mean = stdlib_core.DefineFunction(
    "tensor_mean",
    "tensor",
    "Calculate mean of all elements",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .double,
    &[_][]const u8{"tensor_mean(t)"},
    tensor_mean_impl,
);

pub const tensor_flatten = stdlib_core.DefineFunction(
    "tensor_flatten",
    "tensor",
    "Flatten tensor to 1D",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .object,
    &[_][]const u8{"tensor_flatten(t) -> 1D tensor"},
    tensor_flatten_impl,
);

pub const tensor_transpose = stdlib_core.DefineFunction(
    "tensor_transpose",
    "tensor",
    "Transpose 2D tensor",
    &[_]stdlib_core.ParamSpec{.{ .name = "tensor", .type = .object }},
    .object,
    &[_][]const u8{"tensor_transpose(m)"},
    tensor_transpose_impl,
);

pub const tensor_add_scalar = stdlib_core.DefineFunction(
    "tensor_add_scalar",
    "tensor",
    "Add scalar to all elements",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "scalar", .type = .double } },
    .object,
    &[_][]const u8{"tensor_add_scalar(t, 5.0)"},
    tensor_add_scalar_impl,
);

pub const tensor_scalar_multiply = stdlib_core.DefineFunction(
    "tensor_scalar_multiply",
    "tensor",
    "Multiply all elements by scalar",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor", .type = .object }, .{ .name = "scalar", .type = .double } },
    .object,
    &[_][]const u8{"tensor_scalar_multiply(t, 2.0)"},
    tensor_scalar_multiply_impl,
);

pub const tensor_add = stdlib_core.DefineFunction(
    "tensor_add",
    "tensor",
    "Add two tensors element-wise",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor1", .type = .object }, .{ .name = "tensor2", .type = .object } },
    .object,
    &[_][]const u8{"tensor_add(t1, t2)"},
    tensor_add_impl,
);

pub const tensor_subtract = stdlib_core.DefineFunction(
    "tensor_subtract",
    "tensor",
    "Subtract two tensors element-wise",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor1", .type = .object }, .{ .name = "tensor2", .type = .object } },
    .object,
    &[_][]const u8{"tensor_subtract(t1, t2)"},
    tensor_subtract_impl,
);

pub const tensor_elem_multiply = stdlib_core.DefineFunction(
    "tensor_elem_multiply",
    "tensor",
    "Multiply two tensors element-wise (Hadamard product)",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor1", .type = .object }, .{ .name = "tensor2", .type = .object } },
    .object,
    &[_][]const u8{"tensor_elem_multiply(t1, t2)"},
    tensor_elem_multiply_impl,
);

pub const tensor_elem_divide = stdlib_core.DefineFunction(
    "tensor_elem_divide",
    "tensor",
    "Divide two tensors element-wise",
    &[_]stdlib_core.ParamSpec{ .{ .name = "tensor1", .type = .object }, .{ .name = "tensor2", .type = .object } },
    .object,
    &[_][]const u8{"tensor_elem_divide(t1, t2)"},
    tensor_elem_divide_impl,
);
