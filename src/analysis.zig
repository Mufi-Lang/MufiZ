const std = @import("std");
const errors = @import("errors.zig");
const scanner_h = @import("scanner_optimized.zig");

pub const MufizDiagnosticSeverity = enum(c_int) {
    MUFIZ_DIAGNOSTIC_ERROR = 1,
    MUFIZ_DIAGNOSTIC_WARNING = 2,
};

pub const MufizPosition = extern struct {
    line: u32,
    column: u32,
};

pub const MufizRange = extern struct {
    start: MufizPosition,
    end: MufizPosition,
};

pub const MufizDiagnostic = extern struct {
    range: MufizRange,
    severity: MufizDiagnosticSeverity,
    message: [*c]const u8,
};

pub const SymbolKind = enum(u8) {
    Variable = 1,
    Function = 2,
    Struct = 3,
};

pub const Symbol = struct {
    name: []const u8,
    type_name: []const u8,
    doc_string: []const u8,
    kind: SymbolKind,
    line: u32,
    column: u32,
};

pub const MufizCompletionItem = extern struct {
    name: [*c]const u8,
    type_name: [*c]const u8,
    doc_string: [*c]const u8,
    kind: u8,
};

pub const AnalysisContext = struct {
    allocator: std.mem.Allocator,
    diagnostics: std.ArrayListUnmanaged(MufizDiagnostic),
    symbols: std.ArrayListUnmanaged(Symbol),
    source_lines: std.ArrayListUnmanaged(usize), // Indices of line starts
    source_code: []const u8,
    
    // Completion results buffer
    completion_results: std.ArrayListUnmanaged(MufizCompletionItem),
    last_hover: ?MufizCompletionItem,
    
    pub fn init(allocator: std.mem.Allocator) AnalysisContext {
        return AnalysisContext{
            .allocator = allocator,
            .diagnostics = .{},
            .symbols = .{},
            .source_lines = .{},
            .source_code = "",
            .completion_results = .{},
            .last_hover = null,
        };
    }

    pub fn deinit(self: *AnalysisContext) void {
        for (self.diagnostics.items) |*diag| {
            self.allocator.free(std.mem.span(diag.message));
        }
        self.diagnostics.deinit(self.allocator);
        
        for (self.symbols.items) |*sym| {
            self.allocator.free(sym.name);
            self.allocator.free(sym.type_name);
            self.allocator.free(sym.doc_string);
        }
        self.symbols.deinit(self.allocator);
        
        self.source_lines.deinit(self.allocator);
        if (self.source_code.len > 0) {
            self.allocator.free(self.source_code);
        }
        
        self.clearCompletionResults();
        self.completion_results.deinit(self.allocator);

        if (self.last_hover) |*item| {
            self.allocator.free(std.mem.span(item.name));
            self.allocator.free(std.mem.span(item.type_name));
            self.allocator.free(std.mem.span(item.doc_string));
        }
    }
    
    pub fn clear(self: *AnalysisContext) void {
         for (self.diagnostics.items) |*diag| {
            self.allocator.free(std.mem.span(diag.message));
        }
        self.diagnostics.clearRetainingCapacity();
        
        for (self.symbols.items) |*sym| {
            self.allocator.free(sym.name);
            self.allocator.free(sym.type_name);
            self.allocator.free(sym.doc_string);
        }
        self.symbols.clearRetainingCapacity();
        
        self.source_lines.clearRetainingCapacity();
        if (self.source_code.len > 0) {
            self.allocator.free(self.source_code);
            self.source_code = "";
        }
        
        self.clearCompletionResults();

        if (self.last_hover) |*item| {
            self.allocator.free(std.mem.span(item.name));
            self.allocator.free(std.mem.span(item.type_name));
            self.allocator.free(std.mem.span(item.doc_string));
            self.last_hover = null;
        }
    }
    
    pub fn clearCompletionResults(self: *AnalysisContext) void {
         for (self.completion_results.items) |*item| {
            self.allocator.free(std.mem.span(item.name));
            self.allocator.free(std.mem.span(item.type_name));
            self.allocator.free(std.mem.span(item.doc_string));
        }
        self.completion_results.clearRetainingCapacity();
    }

    pub fn addDiagnostic(self: *AnalysisContext, info: errors.ErrorInfo) !void {
        const msg_copy = try self.allocator.dupeZ(u8, info.message);
        
        const diag = MufizDiagnostic{
            .range = .{
                .start = .{ .line = info.line, .column = info.column },
                .end = .{ .line = info.line, .column = info.column + info.length },
            },
            .severity = switch (info.severity) {
                .ERROR => .MUFIZ_DIAGNOSTIC_ERROR,
                .WARNING => .MUFIZ_DIAGNOSTIC_WARNING,
                else => .MUFIZ_DIAGNOSTIC_ERROR, // Default to error
            },
            .message = msg_copy,
        };
        try self.diagnostics.append(self.allocator, diag);
    }
    
    pub fn addSymbol(self: *AnalysisContext, name: []const u8, type_name: []const u8, kind: SymbolKind, line: u32, column: u32) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        const type_copy = try self.allocator.dupe(u8, type_name);
        const doc_copy = try self.allocator.dupe(u8, ""); // Doc strings not fully supported yet
        
        try self.symbols.append(self.allocator, Symbol{
            .name = name_copy,
            .type_name = type_copy,
            .doc_string = doc_copy,
            .kind = kind,
            .line = line,
            .column = column,
        });
    }

    pub fn updateSource(self: *AnalysisContext, source: []const u8) !void {
        self.clear();
        self.source_code = try self.allocator.dupe(u8, source);
        
        try self.source_lines.append(self.allocator, 0);
        for (source, 0..) |c, i| {
            if (c == '\n') {
                try self.source_lines.append(self.allocator, i + 1);
            }
        }
    }
    
    pub fn computeCompletions(self: *AnalysisContext, line: u32, column: u32) !usize {
        self.clearCompletionResults();
        
        for (self.symbols.items) |sym| {
             _ = line; 
             _ = column;
            
            const item = MufizCompletionItem{
                .name = try self.allocator.dupeZ(u8, sym.name),
                .type_name = try self.allocator.dupeZ(u8, sym.type_name),
                .doc_string = try self.allocator.dupeZ(u8, sym.doc_string),
                .kind = @intFromEnum(sym.kind),
            };
            try self.completion_results.append(self.allocator, item);
        }
        
        return self.completion_results.items.len;
    }
    
    pub fn getHover(self: *AnalysisContext, line: u32, column: u32) !?MufizCompletionItem {
         for (self.symbols.items) |sym| {
             if (sym.line == line) {
                 if (column >= sym.column and column <= sym.column + sym.name.len) {
                     return MufizCompletionItem{
                        .name = try self.allocator.dupeZ(u8, sym.name),
                        .type_name = try self.allocator.dupeZ(u8, sym.type_name),
                        .doc_string = try self.allocator.dupeZ(u8, sym.doc_string),
                        .kind = @intFromEnum(sym.kind),
                     };
                 }
             }
         }
         return null;
    }
};