//! Instruction Format and Encoding Utilities
//!
//! This module provides utilities for working with variable-length bytecode instructions.
//! It defines instruction formats, encoding/decoding helpers, and length calculation.
//!
//! Bytecode Optimization Strategy:
//! - Small constants (0-15): Single-byte opcodes
//! - Small locals (0-3): Single-byte opcodes for get/set
//! - Short jumps: Single-byte offset for nearby branches
//! - Superinstructions: Fused common patterns
//!
//! Author: MufiZ Bytecode Optimization Project
//! Phase: 1 (Foundation)

const std = @import("std");
const chunk_h = @import("chunk.zig");

/// Instruction format types
/// These describe how instructions are encoded in the bytecode stream
pub const InstructionFormat = enum {
    /// Simple instruction: Just the opcode (1 byte)
    /// Examples: OP_ADD, OP_NIL, OP_RETURN, OP_POP
    Simple,

    /// Byte instruction: Opcode + single u8 operand (2 bytes)
    /// Examples: OP_GET_LOCAL [slot], OP_CALL [argc]
    Byte,

    /// Short instruction: Opcode + single i8 operand (2 bytes)
    /// Used for short jumps with signed offset
    Short,

    /// Constant instruction: Opcode + u8 constant index (2 bytes)
    /// Examples: OP_CONSTANT [idx], OP_GET_GLOBAL [idx]
    Constant,

    /// Constant long: Opcode + u16 constant index (3 bytes)
    /// For chunks with >256 constants
    ConstantLong,

    /// Jump instruction: Opcode + u16 offset (3 bytes)
    /// Examples: OP_JUMP [offset], OP_JUMP_IF_FALSE [offset]
    Jump,

    /// Jump short: Opcode + i8 offset (2 bytes)
    /// Optimized for nearby branches
    JumpShort,

    /// Two-byte instruction: Opcode + 2 u8 operands (3 bytes)
    /// Examples: OP_MATRIX [rows] [cols], OP_INVOKE [name] [argc]
    TwoByte,

    /// Variable-length instruction (2+ bytes)
    /// Examples: OP_CLOSURE (depends on upvalue count)
    Variable,
};

/// Instruction metadata
pub const InstructionInfo = struct {
    name: []const u8,
    format: InstructionFormat,
    base_length: u8,
    description: []const u8,
};

/// Get the instruction format for a given opcode
pub fn getInstructionFormat(opcode: u8) InstructionFormat {
    return switch (opcode) {
        // Simple instructions (1 byte)
        1,
        2,
        3,
        4, // OP_NIL, OP_TRUE, OP_FALSE, OP_POP
        16,
        17,
        18,
        19, // Comparisons
        20,
        21,
        22,
        23,
        24,
        25, // Arithmetic
        26,
        27,
        28, // OP_NOT, OP_NEGATE, OP_PRINT
        37,
        38,
        39,
        40, // OP_CLOSE_UPVALUE, OP_RETURN, OP_CLASS, OP_INHERIT
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50, // Array/Range operations
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        61, // More operations
        => .Simple,

        // Byte instructions (2 bytes)
        5,
        6, // OP_GET_LOCAL, OP_SET_LOCAL
        11,
        12, // OP_GET_UPVALUE, OP_SET_UPVALUE
        32, // OP_CALL
        58, // OP_FVECTOR
        => .Byte,

        // Constant instructions (2 bytes)
        0, // OP_CONSTANT
        7,
        8,
        9,
        10, // Global operations
        13,
        14,
        15, // Property operations
        41, // OP_METHOD
        62,
        63,
        65,
        66, // Import operations
        => .Constant,

        // Jump instructions (3 bytes)
        29,
        30,
        31, // OP_JUMP, OP_JUMP_IF_FALSE, OP_LOOP
        => .Jump,

        // Two-byte instructions (3 bytes)
        34,
        35, // OP_INVOKE, OP_SUPER_INVOKE
        59,
        60, // OP_MATRIX, OP_GET_MATRIX_FLAT
        64, // OP_IMPORT_SPECIFIC
        => .TwoByte,

        // Variable-length instructions
        36, // OP_CLOSURE
        => .Variable,

        // Future opcodes (Phase 2+)
        67...82 => .Simple, // Small constants (when implemented)
        83...90 => .Simple, // Small locals (when implemented)
        91...93 => .Short, // Short jumps (when implemented)
        100...191 => .Byte, // Superinstructions (when implemented, most will be 2 bytes)

        else => .Simple, // Default to simple for unknown opcodes
    };
}

/// Get the base length of an instruction (minimum bytes)
pub fn getBaseLength(format: InstructionFormat) u8 {
    return switch (format) {
        .Simple => 1,
        .Byte, .Short, .Constant, .JumpShort => 2,
        .Jump, .TwoByte, .ConstantLong => 3,
        .Variable => 2, // Minimum for variable-length
    };
}

/// Get a human-readable name for an instruction format
pub fn getFormatName(format: InstructionFormat) []const u8 {
    return switch (format) {
        .Simple => "Simple",
        .Byte => "Byte",
        .Short => "Short",
        .Constant => "Constant",
        .ConstantLong => "ConstantLong",
        .Jump => "Jump",
        .JumpShort => "JumpShort",
        .TwoByte => "TwoByte",
        .Variable => "Variable",
    };
}

/// Encoding helper: Write a byte instruction
pub fn encodeByte(code: []u8, offset: usize, opcode: u8, operand: u8) usize {
    code[offset] = opcode;
    code[offset + 1] = operand;
    return 2;
}

/// Encoding helper: Write a constant instruction
pub fn encodeConstant(code: []u8, offset: usize, opcode: u8, constant_idx: u8) usize {
    code[offset] = opcode;
    code[offset + 1] = constant_idx;
    return 2;
}

/// Encoding helper: Write a jump instruction
pub fn encodeJump(code: []u8, offset: usize, opcode: u8, jump_offset: u16) usize {
    code[offset] = opcode;
    code[offset + 1] = @truncate(jump_offset >> 8);
    code[offset + 2] = @truncate(jump_offset & 0xFF);
    return 3;
}

/// Encoding helper: Write a short jump instruction
pub fn encodeShortJump(code: []u8, offset: usize, opcode: u8, jump_offset: i8) usize {
    code[offset] = opcode;
    code[offset + 1] = @bitCast(jump_offset);
    return 2;
}

/// Encoding helper: Write a two-byte instruction
pub fn encodeTwoByte(code: []u8, offset: usize, opcode: u8, operand1: u8, operand2: u8) usize {
    code[offset] = opcode;
    code[offset + 1] = operand1;
    code[offset + 2] = operand2;
    return 3;
}

/// Decoding helper: Read a byte operand
pub inline fn decodeByte(code: []const u8, offset: usize) u8 {
    return code[offset + 1];
}

/// Decoding helper: Read a u16 jump offset
pub inline fn decodeJump(code: []const u8, offset: usize) u16 {
    const high: u16 = code[offset + 1];
    const low: u16 = code[offset + 2];
    return (high << 8) | low;
}

/// Decoding helper: Read an i8 short jump offset
pub inline fn decodeShortJump(code: []const u8, offset: usize) i8 {
    return @bitCast(code[offset + 1]);
}

/// Decoding helper: Read two byte operands
pub inline fn decodeTwoByte(code: []const u8, offset: usize) struct { u8, u8 } {
    return .{ code[offset + 1], code[offset + 2] };
}

/// Optimization helper: Can a constant use the small constant optimization?
pub inline fn canUseSmallConstant(constant_idx: u8) bool {
    return constant_idx <= 15;
}

/// Optimization helper: Can a local use the small local optimization?
pub inline fn canUseSmallLocal(slot: u8) bool {
    return slot <= 3;
}

/// Optimization helper: Can a jump use short jump encoding?
pub inline fn canUseShortJump(offset: i32) bool {
    return offset >= -127 and offset <= 127;
}

/// Calculate instruction statistics for a chunk
pub const InstructionStats = struct {
    total_instructions: usize = 0,
    total_bytes: usize = 0,
    format_counts: [9]usize = [_]usize{0} ** 9,

    pub fn record(self: *InstructionStats, format: InstructionFormat, length: usize) void {
        self.total_instructions += 1;
        self.total_bytes += length;
        self.format_counts[@intFromEnum(format)] += 1;
    }

    pub fn averageSize(self: *const InstructionStats) f64 {
        if (self.total_instructions == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_bytes)) /
            @as(f64, @floatFromInt(self.total_instructions));
    }
};

/// Bytecode version information
pub const BytecodeVersion = struct {
    major: u8,
    minor: u8,
    features: u16,

    /// Feature flags for bytecode capabilities
    pub const Features = packed struct {
        has_small_constants: bool = false,
        has_small_locals: bool = false,
        has_short_jumps: bool = false,
        has_superinstructions: bool = false,
        has_extended_constants: bool = false,
        reserved: u11 = 0,
    };

    pub const CURRENT_MAJOR: u8 = 1;
    pub const CURRENT_MINOR: u8 = 0;

    pub fn current() BytecodeVersion {
        return .{
            .major = CURRENT_MAJOR,
            .minor = CURRENT_MINOR,
            .features = 0, // No optimizations enabled yet (Phase 1)
        };
    }

    pub fn withFeatures(features: Features) BytecodeVersion {
        return .{
            .major = CURRENT_MAJOR,
            .minor = CURRENT_MINOR,
            .features = @bitCast(features),
        };
    }

    pub fn getFeatures(self: BytecodeVersion) Features {
        return @bitCast(self.features);
    }

    pub fn isCompatible(self: BytecodeVersion, other: BytecodeVersion) bool {
        return self.major == other.major;
    }
};

/// Helper to traverse bytecode instructions
pub const InstructionIterator = struct {
    code: []const u8,
    offset: usize,

    pub fn init(code: []const u8) InstructionIterator {
        return .{ .code = code, .offset = 0 };
    }

    pub fn next(self: *InstructionIterator) ?struct { opcode: u8, offset: usize } {
        if (self.offset >= self.code.len) return null;

        const opcode = self.code[self.offset];
        const current_offset = self.offset;

        // Advance to next instruction
        const format = getInstructionFormat(opcode);
        const length = getBaseLength(format);
        self.offset += length;

        return .{ .opcode = opcode, .offset = current_offset };
    }

    pub fn reset(self: *InstructionIterator) void {
        self.offset = 0;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "instruction format detection" {
    const testing = std.testing;

    // Simple instructions
    try testing.expectEqual(InstructionFormat.Simple, getInstructionFormat(1)); // OP_NIL
    try testing.expectEqual(InstructionFormat.Simple, getInstructionFormat(20)); // OP_ADD

    // Byte instructions
    try testing.expectEqual(InstructionFormat.Byte, getInstructionFormat(5)); // OP_GET_LOCAL
    try testing.expectEqual(InstructionFormat.Byte, getInstructionFormat(32)); // OP_CALL

    // Constant instructions
    try testing.expectEqual(InstructionFormat.Constant, getInstructionFormat(0)); // OP_CONSTANT

    // Jump instructions
    try testing.expectEqual(InstructionFormat.Jump, getInstructionFormat(29)); // OP_JUMP
}

test "base length calculation" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 1), getBaseLength(.Simple));
    try testing.expectEqual(@as(u8, 2), getBaseLength(.Byte));
    try testing.expectEqual(@as(u8, 3), getBaseLength(.Jump));
}

test "small constant optimization check" {
    const testing = std.testing;

    try testing.expect(canUseSmallConstant(0));
    try testing.expect(canUseSmallConstant(15));
    try testing.expect(!canUseSmallConstant(16));
    try testing.expect(!canUseSmallConstant(255));
}

test "small local optimization check" {
    const testing = std.testing;

    try testing.expect(canUseSmallLocal(0));
    try testing.expect(canUseSmallLocal(3));
    try testing.expect(!canUseSmallLocal(4));
    try testing.expect(!canUseSmallLocal(10));
}

test "short jump optimization check" {
    const testing = std.testing;

    try testing.expect(canUseShortJump(0));
    try testing.expect(canUseShortJump(127));
    try testing.expect(canUseShortJump(-127));
    try testing.expect(!canUseShortJump(128));
    try testing.expect(!canUseShortJump(-128));
    try testing.expect(!canUseShortJump(1000));
}

test "bytecode version" {
    const testing = std.testing;

    const v1 = BytecodeVersion.current();
    try testing.expectEqual(@as(u8, 1), v1.major);
    try testing.expectEqual(@as(u8, 0), v1.minor);

    const features = BytecodeVersion.Features{
        .has_small_constants = true,
        .has_small_locals = true,
    };
    const v2 = BytecodeVersion.withFeatures(features);
    const extracted = v2.getFeatures();
    try testing.expect(extracted.has_small_constants);
    try testing.expect(extracted.has_small_locals);
    try testing.expect(!extracted.has_short_jumps);
}

test "encoding and decoding" {
    const testing = std.testing;
    var buffer: [10]u8 = undefined;

    // Test byte encoding
    _ = encodeByte(&buffer, 0, 5, 42);
    try testing.expectEqual(@as(u8, 5), buffer[0]);
    try testing.expectEqual(@as(u8, 42), decodeByte(&buffer, 0));

    // Test jump encoding
    _ = encodeJump(&buffer, 0, 29, 1000);
    try testing.expectEqual(@as(u16, 1000), decodeJump(&buffer, 0));

    // Test short jump encoding
    _ = encodeShortJump(&buffer, 0, 91, -50);
    try testing.expectEqual(@as(i8, -50), decodeShortJump(&buffer, 0));
}
