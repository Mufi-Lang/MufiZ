const std = @import("std");
const print = std.debug.print;

const memcpy = @import("mem_utils.zig").memcpyFast;
const mem_utils = @import("mem_utils.zig");
const obj_h = @import("object.zig");
const Obj = obj_h.Obj;
const ObjString = obj_h.ObjString;
const ObjArray = obj_h.ObjArray;
const ObjFunction = obj_h.ObjFunction;
const ObjLinkedList = obj_h.LinkedList;
const Node = obj_h.Node;
const FloatVector = obj_h.FloatVector;
const Matrix = obj_h.Matrix;
const MatrixRow = obj_h.MatrixRow;
const fvec = @import("objects/fvec.zig");
const obj_range = @import("objects/range.zig");

const scanner_h = @import("scanner_optimized.zig");
const simd_string = @import("simd_string.zig");
const SIMDString = simd_string.SIMDString;

pub const ValueType = enum(i32) { VAL_BOOL = 0, VAL_NIL = 1, VAL_INT = 2, VAL_DOUBLE = 3, VAL_OBJ = 4, VAL_COMPLEX = 5 };

pub const Complex = struct {
    r: f64,
    i: f64,
};

pub const Value = struct {
    type: ValueType,
    as: union {
        boolean: bool,
        num_double: f64,
        num_int: i32,
        obj: ?*Obj,
        complex: Complex,
    },

    const Self = @This();

    pub fn init_int(i: i32) Self {
        return Value{ .type = .VAL_INT, .as = .{ .num_int = i } };
    }

    pub fn init_double(d: f64) Self {
        return Value{ .type = .VAL_DOUBLE, .as = .{ .num_double = d } };
    }

    pub fn init_bool(b: bool) Self {
        return Value{ .type = .VAL_BOOL, .as = .{ .boolean = b } };
    }

    pub fn init_nil() Self {
        return Value.init_int(0);
    }

    pub fn init_obj(obj: *Obj) Self {
        return Value{ .type = .VAL_OBJ, .as = .{ .obj = obj } };
    }

    pub fn init_string(s: []u8) Self {
        const chars: [*]const u8 = @ptrCast(@alignCast(s.ptr));
        const length: usize = @intCast(s.len);
        const obj_str = obj_h.copyString(chars, length);
        return Value.init_obj(@ptrCast(obj_str));
    }

    pub fn init_complex(c: Complex) Self {
        return Value{ .type = .VAL_COMPLEX, .as = .{ .complex = c } };
    }

    // Reference counting support
    pub fn retain(self: Self) void {
        if (self.is_obj()) {
            // TODO: Implement reference counting with new allocator approach
            // For now, skip reference counting - will be handled by GC
        }
    }

    pub fn release(self: Self) void {
        if (self.is_obj()) {
            // TODO: Implement reference counting with new allocator approach
            // For now, skip reference counting - will be handled by GC
        }
    }

    pub fn assign(self: *Self, other: Value) void {
        const old = self.*;

        // Increment the reference count of the new value first
        other.retain();

        // Assign the new value
        self.* = other;

        // Release the old value after assignment is complete
        old.release();
    }

    pub fn negate(self: Self) Self {
        switch (self.type) {
            .VAL_INT => return Value.init_int(-self.as.num_int),
            .VAL_DOUBLE => return Value.init_double(-self.as.num_double),
            .VAL_COMPLEX => return Value.init_complex(.{ .r = -self.as.complex.r, .i = -self.as.complex.i }),
            .VAL_OBJ => {
                if (self.is_fvec()) {
                    const vec = self.as_fvec();
                    const result = vec.scale(-1.0);
                    return Value.init_obj(@ptrCast(@alignCast(result)));
                } else {
                    @panic("Cannot negate non-numeric value");
                }
            },
            else => @panic("Cannot negate non-numeric value"),
        }
    }

    pub fn add(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_int(self.as.num_int + other.as.num_int),
                    .VAL_DOUBLE => return Value.init_int(self.as.num_int + @as(i32, @intFromFloat(other.as.num_double))),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) + other.as.complex.r, .i = other.as.complex.i }),
                    else => @panic("Cannot add non-numeric value"),
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double + @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double + other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.num_double + other.as.complex.r, .i = other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => return Value.init_complex(.{ .r = self.as.complex.r + @as(f64, @floatFromInt(other.as.num_int)), .i = self.as.complex.i }),
                    .VAL_DOUBLE => return Value.init_complex(.{ .r = self.as.complex.r + other.as.num_double, .i = self.as.complex.i }),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.complex.r + other.as.complex.r, .i = self.as.complex.i + other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_OBJ => {
                if (self.is_string() and other.is_string()) {
                    const a = self.as_string();
                    const b = other.as_string();
                    const length: usize = a.*.length + b.*.length;
                    const allocator = mem_utils.getAllocator();
                    const chars_slice = mem_utils.alloc(allocator, u8, length + 1) catch return Value.init_nil();
                    const chars: [*]u8 = chars_slice.ptr;
                    // Use regular memory copy to avoid alignment issues
                    _ = memcpy(@ptrCast(chars), @ptrCast(a.*.chars), @intCast(a.*.length));
                    _ = memcpy(@ptrCast(chars + @as(usize, @bitCast(@as(isize, @intCast(a.*.length))))), @ptrCast(b.*.chars), @intCast(b.*.length));
                    chars[@intCast(length)] = '\x00';
                    const result = obj_h.takeString(chars, length);
                    return Value.init_obj(@ptrCast(@alignCast(result)));
                } else if (self.is_fvec() and other.is_fvec()) {
                    // Both are FloatVectors
                    const a = self.as_fvec();
                    const b = other.as_fvec();
                    const result = a.add(b);
                    return Value.init_obj(@ptrCast(result));
                } else if (self.is_fvec() and other.is_prim_num()) {
                    // FloatVector + scalar
                    const a = self.as_fvec();
                    const scalar = other.as_num_double();
                    const result = a.single_add(scalar);
                    return Value.init_obj(@ptrCast(result));
                } else if (self.is_matrix() and other.is_matrix()) {
                    // Matrix + Matrix
                    const a = self.as_matrix();
                    const b = other.as_matrix();
                    const result = a.add(b);
                    if (result == null) {
                        @panic("Matrix dimension mismatch for addition");
                    }
                    return Value.init_obj(@ptrCast(result.?));
                } else if (self.is_matrix() and other.is_prim_num()) {
                    // Matrix + scalar
                    const a = self.as_matrix();
                    const scalar = other.as_num_double();
                    const result = a.scalarMul(1.0); // Clone first
                    const size = a.rows * a.cols;
                    for (0..size) |i| {
                        result.data[i] = a.data[i] + scalar;
                    }
                    return Value.init_obj(@ptrCast(result));
                } else {
                    // Handle hash table or any object + string concatenation
                    // Convert object to string representation and concatenate
                    const self_str = if (self.is_string())
                        self.as_zstring()
                    else
                        objToString(self);

                    const other_str = if (other.is_string())
                        other.as_zstring()
                    else
                        valueToString(other);

                    const length: usize = self_str.len + other_str.len;
                    const allocator = mem_utils.getAllocator();
                    const chars_slice = mem_utils.alloc(allocator, u8, length + 1) catch return Value.init_nil();
                    const chars: [*]u8 = chars_slice.ptr;
                    _ = memcpy(@ptrCast(chars), @ptrCast(self_str.ptr), @intCast(self_str.len));
                    _ = memcpy(@ptrCast(chars + @as(usize, @intCast(self_str.len))), @ptrCast(other_str.ptr), @intCast(other_str.len));
                    chars[@intCast(length)] = '\x00';
                    const result = obj_h.takeString(chars, length);
                    return Value.init_obj(@ptrCast(@alignCast(result)));
                }
            },
            else => {},
        }
        return Value.init_nil();
    }

    pub fn sub(self: Self, other: Value) Value {
        return self.add(other.negate());
    }

    pub fn mul(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_int(self.as.num_int * other.as.num_int),
                    .VAL_DOUBLE => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) * other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.r, .i = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double * @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double * other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.num_double * other.as.complex.r, .i = self.as.num_double * other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => return Value.init_complex(.{ .r = self.as.complex.r * @as(f64, @floatFromInt(other.as.num_int)), .i = self.as.complex.i * @as(f64, @floatFromInt(other.as.num_int)) }),
                    .VAL_DOUBLE => return Value.init_complex(.{ .r = self.as.complex.r * other.as.num_double, .i = self.as.complex.i * other.as.num_double }),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.complex.r * other.as.complex.r - self.as.complex.i * other.as.complex.i, .i = self.as.complex.r * other.as.complex.i + self.as.complex.i * other.as.complex.r }),
                    else => {},
                }
            },
            .VAL_OBJ => {
                if (self.is_fvec() and other.is_fvec()) {
                    // Both are FloatVectors
                    const a = self.as_fvec();
                    const b = other.as_fvec();
                    const result = a.mul(b);
                    return Value.init_obj(@ptrCast(result));
                } else if (self.is_fvec() and other.is_prim_num()) {
                    // FloatVector * scalar
                    const a = self.as_fvec();
                    const scalar = other.as_num_double();
                    const result = a.scale(scalar);
                    return Value.init_obj(@ptrCast(result));
                } else if (self.is_matrix() and other.is_matrix()) {
                    // Matrix * Matrix
                    const a = self.as_matrix();
                    const b = other.as_matrix();
                    const result = a.mul(b);
                    if (result == null) {
                        @panic("Matrix dimension mismatch for multiplication");
                    }
                    return Value.init_obj(@ptrCast(result.?));
                } else if (self.is_matrix() and other.is_prim_num()) {
                    // Matrix * scalar
                    const a = self.as_matrix();
                    const scalar = other.as_num_double();
                    const result = a.scalarMul(scalar);
                    return Value.init_obj(@ptrCast(result));
                } else {
                    @panic("Cannot multiply these object types");
                }
            },
            else => {},
        }
        return Value.init_nil();
    }

    pub fn div(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) / @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) / other.as.num_double),
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.r / denominator, .i = -@as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.i / denominator });
                    },
                    else => {},
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double / @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double / other.as.num_double),
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = self.as.num_double * other.as.complex.r / denominator, .i = -self.as.num_double * other.as.complex.i / denominator });
                    },
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => {
                        const denominator = @as(f64, @floatFromInt(other.as.num_int)) * @as(f64, @floatFromInt(other.as.num_int));
                        return Value.init_complex(.{ .r = self.as.complex.r * @as(f64, @floatFromInt(other.as.num_int)) / denominator, .i = self.as.complex.i * @as(f64, @floatFromInt(other.as.num_int)) / denominator });
                    },
                    .VAL_DOUBLE => {
                        const denominator = other.as.num_double * other.as.num_double;
                        return Value.init_complex(.{ .r = self.as.complex.r * other.as.num_double / denominator, .i = self.as.complex.i * other.as.num_double / denominator });
                    },
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = (self.as.complex.r * other.as.complex.r + self.as.complex.i * other.as.complex.i) / denominator, .i = (self.as.complex.i * other.as.complex.r - self.as.complex.r * other.as.complex.i) / denominator });
                    },
                    else => {},
                }
            },
            .VAL_OBJ => {
                if (self.is_fvec() and other.is_fvec()) {
                    // Both are FloatVectors
                    const a = self.as_fvec();
                    const b = other.as_fvec();
                    const result = a.div(b);
                    return Value.init_obj(@ptrCast(result));
                } else if (self.is_fvec() and other.is_prim_num()) {
                    // FloatVector / scalar
                    const a = self.as_fvec();
                    const scalar = other.as_num_double();
                    const result = a.single_div(scalar);
                    return Value.init_obj(@ptrCast(result));
                } else {
                    @panic("Cannot divide these object types");
                }
            },
            else => {},
        }
        return Value.init_nil();
    }

    pub fn is_bool(self: Self) bool {
        return self.type == .VAL_BOOL;
    }

    pub fn is_nil(self: Self) bool {
        return self.type == .VAL_NIL;
    }

    pub fn is_int(self: Self) bool {
        return self.type == .VAL_INT;
    }

    pub fn is_double(self: Self) bool {
        return self.type == .VAL_DOUBLE;
    }

    pub fn is_obj(self: Self) bool {
        return self.type == .VAL_OBJ;
    }

    pub fn is_complex(self: Self) bool {
        return self.type == .VAL_COMPLEX;
    }

    pub fn is_prim_num(self: Self) bool {
        return self.is_int() or self.is_double();
    }

    pub fn is_obj_type(self: Self, ty: obj_h.ObjType) bool {
        return self.is_obj() and self.as.obj.?.type == ty;
    }

    pub fn is_string(self: Self) bool {
        return self.is_obj_type(.OBJ_STRING);
    }

    pub fn is_class(self: Self) bool {
        return self.is_obj_type(.OBJ_CLASS);
    }

    pub fn is_instance(self: Self) bool {
        return self.is_obj_type(.OBJ_INSTANCE);
    }

    pub fn is_fvec(self: Self) bool {
        return self.is_obj_type(.OBJ_FVECTOR);
    }

    pub fn is_matrix(self: Self) bool {
        return self.is_obj_type(.OBJ_MATRIX);
    }

    pub fn is_matrix_row(self: Self) bool {
        return self.is_obj_type(.OBJ_MATRIX_ROW);
    }

    pub fn is_range(self: Self) bool {
        return self.is_obj_type(.OBJ_RANGE);
    }

    pub fn is_pair(self: Self) bool {
        return self.is_obj_type(.OBJ_PAIR);
    }

    pub fn as_obj(self: Self) ?*Obj {
        return self.as.obj;
    }

    pub fn as_bool(self: Self) bool {
        return self.as.boolean;
    }

    pub fn as_int(self: Self) i32 {
        return self.as.num_int;
    }

    pub fn as_double(self: Self) f64 {
        return self.as.num_double;
    }

    pub fn as_complex(self: Self) Complex {
        return self.as.complex;
    }

    pub fn as_fvec(self: Self) *FloatVector {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_matrix(self: Self) *Matrix {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_matrix_row(self: Self) *MatrixRow {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_range(self: Self) *obj_range.ObjRange {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_pair(self: Self) *obj_h.ObjPair {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_num_double(self: Self) f64 {
        return switch (self.type) {
            .VAL_INT => @as(f64, @floatFromInt(self.as.num_int)),
            .VAL_DOUBLE => self.as.num_double,
            else => @panic("Cannot convert non-numeric value to double"),
        };
    }

    pub fn as_num_int(self: Self) i32 {
        return switch (self.type) {
            .VAL_INT => self.as.num_int,
            .VAL_DOUBLE => @as(i32, @intFromFloat(self.as.num_double)),
            else => @panic("Cannot convert non-numeric value to int"),
        };
    }

    pub fn as_string(self: Self) *ObjString {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_linked_list(self: Self) *ObjLinkedList {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_hash_table(self: Self) *obj_h.ObjHashTable {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_vector(self: Self) *obj_h.FloatVector {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_class(self: Self) *obj_h.ObjClass {
        return @ptrCast(@alignCast(self.as.obj));
    }

    pub fn as_zstring(self: Self) []const u8 {
        const objstr = self.as_string();
        const len: usize = @intCast(objstr.*.length);
        return @ptrCast(@alignCast(objstr.*.chars[0..len]));
    }
};

pub const ValueArray = struct {
    capacity: i32,
    count: i32,
    values: [*]Value,
};

pub fn valuesEqual(a: Value, b: Value) bool {
    if (a.type != b.type) {
        // Special case for range objects - check if value is contained in range
        if (a.type == .VAL_OBJ and a.as.obj != null and a.as.obj.?.type == .OBJ_RANGE and
            (b.type == .VAL_INT or b.type == .VAL_DOUBLE))
        {
            const range = @import("objects/range.zig");
            const range_obj: *range.ObjRange = @ptrCast(@alignCast(a.as.obj));
            const value = b.as_num_int();
            return range_obj.contains(value);
        }
        if (b.type == .VAL_OBJ and b.as.obj != null and b.as.obj.?.type == .OBJ_RANGE and
            (a.type == .VAL_INT or a.type == .VAL_DOUBLE))
        {
            const range = @import("objects/range.zig");
            const range_obj: *range.ObjRange = @ptrCast(@alignCast(b.as.obj));
            const value = a.as_num_int();
            return range_obj.contains(value);
        }
        return false;
    }

    switch (a.type) {
        .VAL_BOOL => return a.as_bool() == b.as_bool(),
        .VAL_NIL => return true,
        .VAL_INT => return a.as.num_int == b.as.num_int,
        .VAL_DOUBLE => return a.as.num_double == b.as.num_double,
        .VAL_OBJ => {
            {
                const obj_a: *Obj = a.as.obj.?;
                const obj_b: *Obj = b.as.obj.?;
                if (obj_a.*.type != obj_b.*.type) return false;
                switch (obj_a.*.type) {
                    .OBJ_STRING => {
                        {
                            const str_a: *ObjString = @as(*ObjString, @ptrCast(@alignCast(a.as.obj)));
                            const str_b: *ObjString = @as(*ObjString, @ptrCast(@alignCast(b.as.obj)));
                            if (str_a.length != str_b.length) return false;

                            // Use SIMD string comparison only for larger strings to avoid alignment issues
                            if (str_a.length >= 32) {
                                const slice_a = str_a.chars[0..str_a.length];
                                const slice_b = str_b.chars[0..str_b.length];
                                return SIMDString.equalsSIMD(slice_a, slice_b);
                            } else {
                                // Use standard comparison for small strings
                                return scanner_h.memcmp(@ptrCast(str_a.chars), @ptrCast(str_b.chars), @intCast(str_a.length)) == 0;
                            }
                        }
                    },
                    .OBJ_LINKED_LIST => {
                        {
                            const list_a: *ObjLinkedList = @as(*ObjLinkedList, @ptrCast(@alignCast(a.as.obj)));
                            const list_b: *ObjLinkedList = @as(*ObjLinkedList, @ptrCast(@alignCast(b.as.obj)));
                            if (list_a.count != list_b.count) return false;
                            var node_a: ?*Node = list_a.head;
                            var node_b: ?*Node = list_b.head;
                            while (node_a) |nodeA| {
                                if (node_b) |nodeB| {
                                    if (!valuesEqual(nodeA.data, nodeB.data)) return false;
                                    node_a = nodeA.next;
                                    node_b = nodeB.next;
                                } else {
                                    return false;
                                }
                            }
                            return true;
                        }
                    },
                    .OBJ_FVECTOR => {
                        const vec_a: *FloatVector = @as(*FloatVector, @ptrCast(@alignCast(a.as.obj)));
                        const vec_b: *FloatVector = @as(*FloatVector, @ptrCast(@alignCast(b.as.obj)));
                        if (vec_a.*.count != vec_b.*.count) return false;

                        var i: i32 = 0;
                        while (i < vec_a.*.count) : (i += 1) {
                            if (vec_a.*.data[@intCast(i)] != vec_b.*.data[@intCast(i)]) return false;
                        }

                        return true;
                    },
                    .OBJ_RANGE => {
                        const range_a = @as(*obj_range.ObjRange, @ptrCast(@alignCast(a.as.obj)));
                        const range_b = @as(*obj_range.ObjRange, @ptrCast(@alignCast(b.as.obj)));

                        return range_a.start == range_b.start and
                            range_a.end == range_b.end and
                            range_a.inclusive == range_b.inclusive;
                    },
                    .OBJ_PAIR => {
                        const pair_a = @as(*obj_h.ObjPair, @ptrCast(@alignCast(a.as.obj)));
                        const pair_b = @as(*obj_h.ObjPair, @ptrCast(@alignCast(b.as.obj)));

                        return valuesEqual(pair_a.key, pair_b.key) and
                            valuesEqual(pair_a.value, pair_b.value);
                    },
                    else => return false,
                }
            }
        },
        .VAL_COMPLEX => {
            const c_a: Complex = a.as.complex;
            const c_b: Complex = b.as.complex;
            return (c_a.r == c_b.r) and (c_a.i == c_b.i);
        },
    }
}

pub fn valueCompare(a: Value, b: Value) i32 {
    if (a.type != b.type) return -1;

    switch (a.type) {
        .VAL_BOOL => return @intCast(@intFromBool(a.as_bool()) - @intFromBool(b.as_bool())),
        .VAL_NIL => return 0,
        .VAL_INT => {
            const a1: i32 = a.as.num_int;
            const b1: i32 = b.as.num_int;

            if (a1 > b1) return 1;
            if (a1 < b1) return -1;
            if (a1 == b1) return 0;
        },
        .VAL_DOUBLE => {
            const a1: f64 = a.as.num_double;
            const b1: f64 = b.as.num_double;

            if (a1 > b1) return 1;
            if (a1 < b1) return -1;
            if (a1 == b1) return 0;
        },
        else => return -1,
    }
    return -1;
}

pub fn initValueArray(array: *ValueArray) void {
    array.values = undefined;
    array.capacity = 0;
    array.count = 0;
}

pub fn writeValueArray(array: *ValueArray, value: Value) void {
    if (array.capacity < (array.count + 1)) {
        const oldCapacity: i32 = array.capacity;
        array.capacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        const allocator = mem_utils.getAllocator();

        if (@intFromPtr(array.values) != 0) {
            const old_values_slice = array.values[0..@intCast(oldCapacity)];
            const new_values_slice = mem_utils.realloc(allocator, old_values_slice, @intCast(array.capacity)) catch {
                // Handle allocation failure
                return;
            };
            array.values = new_values_slice.ptr;
        } else {
            const new_values_slice = mem_utils.alloc(allocator, Value, @intCast(array.capacity)) catch {
                return;
            };
            array.values = new_values_slice.ptr;
        }
    }
    array.values[@intCast(array.count)] = value;
    array.count += 1;
}

pub fn freeValueArray(array: *ValueArray) void {
    if (@intFromPtr(array.values) != 0 and array.capacity > 0) {
        const allocator = mem_utils.getAllocator();
        const values_slice = array.values[0..@intCast(array.capacity)];
        mem_utils.free(allocator, values_slice);
    }
    initValueArray(array);
}

pub fn printValue(value: Value) void {
    switch (value.type) {
        .VAL_BOOL => {
            print("{s}", .{if (value.as_bool()) "true" else "false"});
        },
        .VAL_NIL => {
            print("nil", .{});
        },
        .VAL_DOUBLE => {
            var val: f64 = value.as.num_double;

            if (@abs(val) < 0.0000000001) {
                val = 0.0;
            }
            print("{d}", .{val});
        },
        .VAL_INT => {
            print("{d}", .{value.as.num_int});
        },
        .VAL_COMPLEX => {
            const c: Complex = value.as.complex;
            print("{d} + {d}i", .{ c.r, c.i });
        },
        .VAL_OBJ => {
            obj_h.printObject(value);
        },
    }
}

// Convert object to string
fn objToString(value: Value) []const u8 {
    if (value.as.obj == null) return "null";

    switch (value.as.obj.?.type) {
        .OBJ_STRING => return value.as_zstring(),
        .OBJ_FUNCTION => {
            const function = @as(*obj_h.ObjFunction, @ptrCast(@alignCast(value.as.obj)));
            if (function.*.name) |name| {
                return std.fmt.allocPrint(std.heap.page_allocator, "<fn {s}>", .{name.*.chars[0..@intCast(name.*.length)]}) catch unreachable;
            } else {
                return "<fn script>";
            }
        },
        .OBJ_HASH_TABLE => {
            const ht = @as(*obj_h.ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
            var result = std.fmt.allocPrint(std.heap.page_allocator, "{{", .{}) catch unreachable;

            var count: i32 = 0;
            var iter = ht.*.map.iterator();

            while (iter.next()) |entry| {
                if (count > 0) {
                    const temp = result;
                    result = std.fmt.allocPrint(std.heap.page_allocator, "{s}, ", .{temp}) catch unreachable;
                }

                const key = entry.key_ptr.*.chars[0..@intCast(entry.key_ptr.*.length)];
                const keyStr = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\": ", .{key}) catch unreachable;

                const valStr = valueToString(entry.value_ptr.*);

                const temp = result;
                result = std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}{s}", .{ temp, keyStr, valStr }) catch unreachable;
                count += 1;
            }

            const temp = result;
            result = std.fmt.allocPrint(std.heap.page_allocator, "{s}}}", .{temp}) catch unreachable;
            return result;
        },
        .OBJ_FVECTOR => return "<vector>",
        .OBJ_LINKED_LIST => return "<list>",
        .OBJ_PAIR => {
            const pair = @as(*obj_h.ObjPair, @ptrCast(@alignCast(value.as.obj)));
            const keyStr = valueToString(pair.key);
            const valueStr = valueToString(pair.value);
            return std.fmt.allocPrint(std.heap.page_allocator, "({s}, {s})", .{ keyStr, valueStr }) catch unreachable;
        },
        else => return "<object>",
    }
}

pub fn valueToString(value: Value) []const u8 {
    switch (value.type) {
        .VAL_BOOL => return if (value.as_bool()) "true" else "false",
        .VAL_NIL => return "nil",
        .VAL_INT => {
            const s = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as_int()}) catch unreachable;
            return s;
        },
        .VAL_DOUBLE => {
            const s = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as_double()}) catch unreachable;
            return s;
        },
        .VAL_COMPLEX => {
            const c = value.as_complex();
            const s = std.fmt.allocPrint(std.heap.page_allocator, "{d} + {d}i", .{ c.r, c.i }) catch unreachable;
            return s;
        },
        .VAL_OBJ => {
            return objToString(value);
        },
    }
    return null;
}
