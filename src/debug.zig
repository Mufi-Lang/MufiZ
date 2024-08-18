const Chunk = @import("chunk.zig").Chunk;
const printf = @cImport(@cInclude("stdio.h")).printf;
const printValue = @import("value.zig").printValue;
const obj_h = @import("object.zig");
const ObjFunction = obj_h.ObjFunction;

pub export fn disassembleChunk(arg_chunk: [*c]Chunk, arg_name: [*c]const u8) void {
    var chunk = arg_chunk;
    _ = &chunk;
    var name = arg_name;
    _ = &name;
    _ = printf("== %s ==\n", name);
    {
        var offset: c_int = 0;
        _ = &offset;
        while (offset < chunk.*.count) {
            offset = disassembleInstruction(chunk, offset);
        }
    }
}
pub export fn disassembleInstruction(arg_chunk: [*c]Chunk, arg_offset: c_int) c_int {
    var chunk = arg_chunk;
    _ = &chunk;
    var offset = arg_offset;
    _ = &offset;
    _ = printf("%04d ", offset);
    if ((offset > @as(c_int, 0)) and ((blk: {
        const tmp = offset;
        if (tmp >= 0) break :blk chunk.*.lines + @as(usize, @intCast(tmp)) else break :blk chunk.*.lines - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* == (blk: {
        const tmp = offset - @as(c_int, 1);
        if (tmp >= 0) break :blk chunk.*.lines + @as(usize, @intCast(tmp)) else break :blk chunk.*.lines - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        _ = printf("   | ");
    } else {
        _ = printf("%4d ", (blk: {
            const tmp = offset;
            if (tmp >= 0) break :blk chunk.*.lines + @as(usize, @intCast(tmp)) else break :blk chunk.*.lines - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*);
    }
    var instruction: u8 = (blk: {
        const tmp = offset;
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &instruction;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, instruction)))) {
            @as(c_int, 0) => return constantInstruction("OP_CONSTANT", chunk, offset),
            @as(c_int, 1) => return simpleInstruction("OP_NIL", offset),
            @as(c_int, 2) => return simpleInstruction("OP_TRUE", offset),
            @as(c_int, 3) => return simpleInstruction("OP_FALSE", offset),
            @as(c_int, 4) => return simpleInstruction("OP_POP", offset),
            @as(c_int, 5) => return byteInstruction("OP_GET_LOCAL", chunk, offset),
            @as(c_int, 6) => return byteInstruction("OP_SET_LOCAL", chunk, offset),
            @as(c_int, 7) => return constantInstruction("OP_GET_GLOBAL", chunk, offset),
            @as(c_int, 8) => return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset),
            @as(c_int, 9) => return constantInstruction("OP_SET_GLOBAL", chunk, offset),
            @as(c_int, 10) => return byteInstruction("OP_GET_UPVALUE", chunk, offset),
            @as(c_int, 11) => return byteInstruction("OP_SET_UPVALUE", chunk, offset),
            @as(c_int, 12) => return constantInstruction("OP_GET_PROPERTY", chunk, offset),
            @as(c_int, 13) => return constantInstruction("OP_SET_PROPERTY", chunk, offset),
            @as(c_int, 14) => return constantInstruction("OP_GET_SUPER", chunk, offset),
            @as(c_int, 17) => return simpleInstruction("OP_EQUAL", offset),
            @as(c_int, 18) => return simpleInstruction("OP_GREATER", offset),
            @as(c_int, 19) => return simpleInstruction("OP_LESS", offset),
            @as(c_int, 20) => return simpleInstruction("OP_ADD", offset),
            @as(c_int, 21) => return simpleInstruction("OP_SUBTRACT", offset),
            @as(c_int, 22) => return simpleInstruction("OP_MULTIPLY", offset),
            @as(c_int, 23) => return simpleInstruction("OP_DIVIDE", offset),
            @as(c_int, 26) => return simpleInstruction("OP_NOT", offset),
            @as(c_int, 27) => return simpleInstruction("OP_NEGATE", offset),
            @as(c_int, 28) => return simpleInstruction("OP_PRINT", offset),
            @as(c_int, 29) => return jumpInstruction("OP_JUMP", @as(c_int, 1), chunk, offset),
            @as(c_int, 30) => return jumpInstruction("OP_JUMP_IF_FALSE", @as(c_int, 1), chunk, offset),
            @as(c_int, 31) => return jumpInstruction("OP_JUMP_IF_DONE", @as(c_int, 1), chunk, offset),
            @as(c_int, 32) => return jumpInstruction("OP_LOOP", -@as(c_int, 1), chunk, offset),
            @as(c_int, 33) => return byteInstruction("OP_CALL", chunk, offset),
            @as(c_int, 34) => return invokeInstruction("OP_INVOKE", chunk, offset),
            @as(c_int, 35) => return invokeInstruction("OP_SUPER_INVOKE", chunk, offset),
            @as(c_int, 36) => {
                {
                    offset += 1;
                    var constant: u8 = (blk: {
                        const tmp = blk_1: {
                            const ref = &offset;
                            const tmp_2 = ref.*;
                            ref.* += 1;
                            break :blk_1 tmp_2;
                        };
                        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                    _ = &constant;
                    _ = printf("%-16s %4d", "OP_CLOSURE", @as(c_int, @bitCast(@as(c_uint, constant))));
                    printValue(chunk.*.constants.values[constant]);
                    _ = printf("\n");
                    var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(chunk.*.constants.values[constant].as.obj)));
                    _ = &function;
                    {
                        var j: c_int = 0;
                        _ = &j;
                        while (j < function.*.upvalueCount) : (j += 1) {
                            var isLocal: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                                const tmp = blk_1: {
                                    const ref = &offset;
                                    const tmp_2 = ref.*;
                                    ref.* += 1;
                                    break :blk_1 tmp_2;
                                };
                                if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)));
                            _ = &isLocal;
                            var index_1: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                                const tmp = blk_1: {
                                    const ref = &offset;
                                    const tmp_2 = ref.*;
                                    ref.* += 1;
                                    break :blk_1 tmp_2;
                                };
                                if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)));
                            _ = &index_1;
                            @import("std").debug.print("{d:0>4}      |                  {s} {d:0>4}\n", .{ offset - @as(c_int, 2), if (isLocal != 0) "local" else "upvalue", index_1 });
                        }
                    }
                    return offset;
                }
            },
            @as(c_int, 37) => return simpleInstruction("OP_CLOSE_UPVALUE", offset),
            @as(c_int, 38) => return simpleInstruction("OP_RETURN", offset),
            @as(c_int, 39) => return constantInstruction("OP_CLASS", chunk, offset),
            @as(c_int, 40) => return simpleInstruction("OP_INHERIT", offset),
            @as(c_int, 41) => return constantInstruction("OP_METHOD", chunk, offset),
            @as(c_int, 42) => return simpleInstruction("OP_ARRAY", offset),
            @as(c_int, 43) => return simpleInstruction("OP_FVECTOR", offset),
            @as(c_int, 45) => return simpleInstruction("OP_ITERATOR_NEXT", offset),
            @as(c_int, 44) => return simpleInstruction("OP_GET_ITERATOR", offset),
            else => {
                _ = printf("Unknown opcode %d\n", @as(c_int, @bitCast(@as(c_uint, instruction))));
                return offset + @as(c_int, 1);
            },
        }
        break;
    }
    return 0;
}

pub fn constantInstruction(arg_name: [*c]const u8, arg_chunk: [*c]Chunk, arg_offset: c_int) callconv(.C) c_int {
    var name = arg_name;
    _ = &name;
    var chunk = arg_chunk;
    _ = &chunk;
    var offset = arg_offset;
    _ = &offset;
    var constant: u8 = (blk: {
        const tmp = offset + @as(c_int, 1);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &constant;
    _ = printf("%-16s %4d '", name, @as(c_int, @bitCast(@as(c_uint, constant))));
    printValue(chunk.*.constants.values[constant]);
    _ = printf("'\n");
    return offset + @as(c_int, 2);
}
pub fn invokeInstruction(arg_name: [*c]const u8, arg_chunk: [*c]Chunk, arg_offset: c_int) callconv(.C) c_int {
    var name = arg_name;
    _ = &name;
    var chunk = arg_chunk;
    _ = &chunk;
    var offset = arg_offset;
    _ = &offset;
    var constant: u8 = (blk: {
        const tmp = offset + @as(c_int, 1);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &constant;
    var argCount: u8 = (blk: {
        const tmp = offset + @as(c_int, 2);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &argCount;
    _ = printf("%-16s (%d args) %4d '", name, @as(c_int, @bitCast(@as(c_uint, argCount))), @as(c_int, @bitCast(@as(c_uint, constant))));
    printValue(chunk.*.constants.values[constant]);
    _ = printf("'\n");
    return offset + @as(c_int, 3);
}
pub fn simpleInstruction(arg_name: [*c]const u8, arg_offset: c_int) callconv(.C) c_int {
    var name = arg_name;
    _ = &name;
    var offset = arg_offset;
    _ = &offset;
    _ = printf("%s\n", name);
    return offset + @as(c_int, 1);
}
pub fn byteInstruction(arg_name: [*c]const u8, arg_chunk: [*c]Chunk, arg_offset: c_int) callconv(.C) c_int {
    var name = arg_name;
    _ = &name;
    var chunk = arg_chunk;
    _ = &chunk;
    var offset = arg_offset;
    _ = &offset;
    var slot: u8 = (blk: {
        const tmp = offset + @as(c_int, 1);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &slot;
    _ = printf("%-16s %4d", name, @as(c_int, @bitCast(@as(c_uint, slot))));
    return offset + @as(c_int, 2);
}
pub fn jumpInstruction(arg_name: [*c]const u8, arg_sign: c_int, arg_chunk: [*c]Chunk, arg_offset: c_int) callconv(.C) c_int {
    var name = arg_name;
    _ = &name;
    var sign = arg_sign;
    _ = &sign;
    var chunk = arg_chunk;
    _ = &chunk;
    var offset = arg_offset;
    _ = &offset;
    var jump: u16 = @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, (blk: {
        const tmp = offset + @as(c_int, 1);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*))) << @intCast(8)))));
    _ = &jump;
    jump |= @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, (blk: {
        const tmp = offset + @as(c_int, 2);
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)))))));
    _ = printf("%-16s %4d -> %d\n", name, offset, (offset + @as(c_int, 3)) + (sign * @as(c_int, @bitCast(@as(c_uint, jump)))));
    return offset + @as(c_int, 3);
}
