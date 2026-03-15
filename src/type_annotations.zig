/// Type Annotation Parser for MufiZ Compiler
///
/// Extends the MufiZ compiler's parser to support optional type annotations:
/// - Variable declarations: let x: int = 5
/// - Function parameters: fn add(a: int, b: double) -> double
/// - Function return types
///
/// This module provides integration functions that can be called from the main compiler.

const std = @import("std");
const type_system = @import("type_system.zig");

const SimpleType = type_system.SimpleType;
const Type = type_system.Type;

// Forward declarations - these will be provided by the compiler
// We define them here for type safety
pub const ParsedTypeAnnotation = struct {
    type: ?SimpleType,
    present: bool,
};

pub const FunctionSignature = struct {
    name: []const u8,
    parameters: std.ArrayList(struct {
        name: []const u8,
        type_annotation: ParsedTypeAnnotation,
    }),
    return_type: ParsedTypeAnnotation,
};

// ============================================================================
// Type Annotation Parsing Functions
// ============================================================================

/// Parse a type annotation from a token stream
/// Expected format: ": typename" or absent
/// Returns null if no colon is found, Some(type) if type is valid
pub fn tryParseTypeAnnotation(allocator: std.mem.Allocator) !ParsedTypeAnnotation {
    _ = allocator;
    // This function will be called from the compiler's parsing context
    // In the compiler, we'll have access to the parser state
    // For now, provide the interface

    return ParsedTypeAnnotation{
        .type = null,
        .present = false,
    };
}

/// Map string representations of types to SimpleType enum
pub fn parseTypeNameString(name: []const u8) ?SimpleType {
    if (std.mem.eql(u8, name, "int")) return .Int;
    if (std.mem.eql(u8, name, "double")) return .Double;
    if (std.mem.eql(u8, name, "complex")) return .Complex;
    if (std.mem.eql(u8, name, "bool")) return .Bool;
    if (std.mem.eql(u8, name, "string")) return .String;
    if (std.mem.eql(u8, name, "nil")) return .Nil;
    if (std.mem.eql(u8, name, "array")) return .Array;
    if (std.mem.eql(u8, name, "vector")) return .Vector;
    if (std.mem.eql(u8, name, "matrix")) return .Matrix;
    if (std.mem.eql(u8, name, "table")) return .Table;
    if (std.mem.eql(u8, name, "function")) return .Function;
    return null;
}

// ============================================================================
// Variable Declaration with Type Annotation
// ============================================================================

pub const ParsedVariable = struct {
    name: []const u8,
    type_annotation: ParsedTypeAnnotation,
    is_const: bool = false,
};

/// Helper function that compilers can call to parse: name [: type]
/// Expects: IDENTIFIER [TOKEN_COLON IDENTIFIER] already partially consumed
pub fn parseVariableWithType(
    allocator: std.mem.Allocator,
    var_name: []const u8,
) !ParsedVariable {
    _ = allocator;

    return ParsedVariable{
        .name = var_name,
        .type_annotation = .{
            .type = null,
            .present = false,
        },
    };
}

// ============================================================================
// Function Signature Parsing
// ============================================================================

pub fn parseFunctionSignature(allocator: std.mem.Allocator, func_name: []const u8) !FunctionSignature {
    return FunctionSignature{
        .name = func_name,
        .parameters = std.ArrayList(struct {
            name: []const u8,
            type_annotation: ParsedTypeAnnotation,
        }).init(allocator),
        .return_type = .{
            .type = null,
            .present = false,
        },
    };
}

// ============================================================================
// Type Annotation Validation
// ============================================================================

pub fn validateTypeAnnotation(type_annotation: ParsedTypeAnnotation, line: usize, col: usize) ?ParsedTypeAnnotation {
    if (!type_annotation.present) return type_annotation;

    if (type_annotation.type == null) {
        std.debug.print("{}:{}: Error: Invalid type annotation\n", .{ line, col });
        return null;
    }

    return type_annotation;
}

// ============================================================================
// Integration Helper - to be called from compiler.zig
// ============================================================================

/// Check if the next token is a type annotation (colon)
/// This is a simple helper that works with scanner state
pub fn isTypeAnnotationStart(next_token_type: u32) bool {
    const TOKEN_COLON = 65; // From scanner_optimized.zig
    return next_token_type == TOKEN_COLON;
}

/// Format a type annotation for error messages
pub fn formatTypeAnnotation(allocator: std.mem.Allocator, annotation: ParsedTypeAnnotation) ![]const u8 {
    if (annotation.present and annotation.type != null) {
        return try std.fmt.allocPrint(allocator, ": {s}", .{annotation.type.?.name()});
    }
    return try std.fmt.allocPrint(allocator, "", .{});
}

// ============================================================================
// Tests
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test type name parsing
    const int_type = parseTypeNameString("int");
    std.debug.print("Parsed 'int': {}\n", .{int_type});

    const double_type = parseTypeNameString("double");
    std.debug.print("Parsed 'double': {}\n", .{double_type});

    const invalid_type = parseTypeNameString("invalid_type");
    std.debug.print("Parsed 'invalid_type': {}\n", .{invalid_type});

    // Test variable parsing
    const var_parsed = try parseVariableWithType(allocator, "x");
    std.debug.print("Parsed variable: {s}\n", .{var_parsed.name});

    // Test annotation formatting
    const no_annot = ParsedTypeAnnotation{ .type = null, .present = false };
    const formatted = try formatTypeAnnotation(allocator, no_annot);
    defer allocator.free(formatted);
    std.debug.print("Formatted annotation: '{s}'\n", .{formatted});
}
