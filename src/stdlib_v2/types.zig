const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const OneAny = stdlib_v2.OneAny;
const mem_utils = @import("../mem_utils.zig");

// Implementation functions

fn int_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    switch (args[0].type) {
        .VAL_DOUBLE => {
            const d = @ceil(args[0].as_double());
            const i: i32 = @intFromFloat(d);
            return Value.init_int(i);
        },
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const s = args[0].as_zstring();
                const i = std.fmt.parseInt(i32, s, 10) catch 0;
                return Value.init_int(i);
            } else {
                return Value.init_nil();
            }
        },
        .VAL_INT => return args[0], // Already an int
        .VAL_BOOL => return Value.init_int(if (args[0].as_bool()) 1 else 0),
        else => return Value.init_nil(),
    }
}

fn double_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    switch (args[0].type) {
        .VAL_INT => {
            const i = args[0].as_int();
            const d: f64 = @floatFromInt(i);
            return Value.init_double(d);
        },
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const s = args[0].as_zstring();
                const d = std.fmt.parseFloat(f64, s) catch 0.0;
                return Value.init_double(d);
            } else {
                return Value.init_nil();
            }
        },
        .VAL_DOUBLE => return args[0], // Already a double
        .VAL_BOOL => return Value.init_double(if (args[0].as_bool()) 1.0 else 0.0),
        else => return Value.init_nil(),
    }
}

fn str_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const value = args[0];

    var s: []u8 = undefined;
    switch (value.type) {
        .VAL_INT => {
            const i = value.as_int();
            s = std.fmt.allocPrint(mem_utils.getAllocator(), "{d}", .{i}) catch return Value.init_nil();
        },
        .VAL_DOUBLE => {
            const d = value.as_double();
            s = std.fmt.allocPrint(mem_utils.getAllocator(), "{}", .{d}) catch return Value.init_nil();
        },
        .VAL_BOOL => {
            const b = value.as_bool();
            s = std.fmt.allocPrint(mem_utils.getAllocator(), "{}", .{b}) catch return Value.init_nil();
        },
        .VAL_NIL => {
            s = std.fmt.allocPrint(mem_utils.getAllocator(), "nil", .{}) catch return Value.init_nil();
        },
        .VAL_COMPLEX => {
            const c = value.as_complex();
            s = std.fmt.allocPrint(mem_utils.getAllocator(), "{}+{}i", .{ c.r, c.i }) catch return Value.init_nil();
        },
        .VAL_OBJ => {
            if (value.is_string()) {
                return value; // Already a string
            } else {
                s = std.fmt.allocPrint(mem_utils.getAllocator(), "[object]", .{}) catch return Value.init_nil();
            }
        },
    }

    const val = Value.init_string(s);
    mem_utils.getAllocator().free(s);
    return val;
}

fn bool_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const value = args[0];

    switch (value.type) {
        .VAL_BOOL => return value, // Already a bool
        .VAL_NIL => return Value.init_bool(false),
        .VAL_INT => return Value.init_bool(value.as_int() != 0),
        .VAL_DOUBLE => return Value.init_bool(value.as_double() != 0.0),
        .VAL_OBJ => {
            if (value.is_string()) {
                const s = value.as_zstring();
                return Value.init_bool(s.len > 0);
            } else {
                return Value.init_bool(true); // Objects are truthy
            }
        },
        .VAL_COMPLEX => {
            const c = value.as_complex();
            return Value.init_bool(c.r != 0.0 or c.i != 0.0);
        },
    }
}

fn type_of_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const value = args[0];

    const type_name = switch (value.type) {
        .VAL_BOOL => "bool",
        .VAL_NIL => "nil",
        .VAL_INT => "int",
        .VAL_DOUBLE => "double",
        .VAL_COMPLEX => "complex",
        .VAL_OBJ => {
            if (value.is_string()) {
                "string";
            } else {
                "object";
            }
        },
    };

    const s = mem_utils.getAllocator().dupe(u8, type_name) catch return Value.init_nil();
    return Value.init_string(s);
}

fn is_nil_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_NIL);
}

fn is_bool_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_BOOL);
}

fn is_int_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_INT);
}

fn is_double_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_DOUBLE);
}

fn is_number_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_INT or args[0].type == .VAL_DOUBLE);
}

fn is_complex_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_COMPLEX);
}

fn is_string_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].is_string());
}

fn is_object_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(args[0].type == .VAL_OBJ);
}

// Public function wrappers with metadata

pub const int = DefineFunction(
    "int",
    "types",
    "Convert a value to an integer",
    OneAny,
    .int,
    &[_][]const u8{
        "int(3.14) -> 4",
        "int(\"42\") -> 42",
        "int(true) -> 1",
        "int(false) -> 0",
    },
    int_impl,
);

pub const double = DefineFunction(
    "double",
    "types",
    "Convert a value to a double",
    OneAny,
    .double,
    &[_][]const u8{
        "double(42) -> 42.0",
        "double(\"3.14\") -> 3.14",
        "double(true) -> 1.0",
        "double(false) -> 0.0",
    },
    double_impl,
);

pub const str = DefineFunction(
    "str",
    "types",
    "Convert a value to a string",
    OneAny,
    .string,
    &[_][]const u8{
        "str(42) -> \"42\"",
        "str(3.14) -> \"3.14\"",
        "str(true) -> \"true\"",
        "str(nil) -> \"nil\"",
        "str(complex(3, 4)) -> \"3+4i\"",
    },
    str_impl,
);

pub const bool_fn = DefineFunction(
    "bool",
    "types",
    "Convert a value to a boolean",
    OneAny,
    .bool,
    &[_][]const u8{
        "bool(1) -> true",
        "bool(0) -> false",
        "bool(\"\") -> false",
        "bool(\"hello\") -> true",
        "bool(nil) -> false",
    },
    bool_impl,
);

pub const type_of = DefineFunction(
    "type_of",
    "types",
    "Get the type name of a value",
    OneAny,
    .string,
    &[_][]const u8{
        "type_of(42) -> \"int\"",
        "type_of(3.14) -> \"double\"",
        "type_of(true) -> \"bool\"",
        "type_of(nil) -> \"nil\"",
        "type_of(\"hello\") -> \"string\"",
        "type_of(complex(1, 2)) -> \"complex\"",
    },
    type_of_impl,
);

pub const is_nil = DefineFunction(
    "is_nil",
    "types",
    "Check if value is nil",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_nil(nil) -> true",
        "is_nil(42) -> false",
    },
    is_nil_impl,
);

pub const is_bool = DefineFunction(
    "is_bool",
    "types",
    "Check if value is a boolean",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_bool(true) -> true",
        "is_bool(42) -> false",
    },
    is_bool_impl,
);

pub const is_int = DefineFunction(
    "is_int",
    "types",
    "Check if value is an integer",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_int(42) -> true",
        "is_int(3.14) -> false",
    },
    is_int_impl,
);

pub const is_double = DefineFunction(
    "is_double",
    "types",
    "Check if value is a double",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_double(3.14) -> true",
        "is_double(42) -> false",
    },
    is_double_impl,
);

pub const is_number = DefineFunction(
    "is_number",
    "types",
    "Check if value is a number (int or double)",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_number(42) -> true",
        "is_number(3.14) -> true",
        "is_number(\"hello\") -> false",
    },
    is_number_impl,
);

pub const is_complex = DefineFunction(
    "is_complex",
    "types",
    "Check if value is a complex number",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_complex(complex(1, 2)) -> true",
        "is_complex(42) -> false",
    },
    is_complex_impl,
);

pub const is_string = DefineFunction(
    "is_string",
    "types",
    "Check if value is a string",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_string(\"hello\") -> true",
        "is_string(42) -> false",
    },
    is_string_impl,
);

pub const is_object = DefineFunction(
    "is_object",
    "types",
    "Check if value is an object",
    OneAny,
    .bool,
    &[_][]const u8{
        "is_object(linked_list()) -> true",
        "is_object(42) -> false",
    },
    is_object_impl,
);
