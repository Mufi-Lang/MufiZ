const system = @import("system.zig");

/// MufiZ Documentation Generator
/// Generates HTML documentation for MufiZ projects similar to cargo doc and zig doc
const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub const DocGenError = error{
    FileSystemError,
    ParseError,
    WriteError,
    InvalidProject,
};

pub const DocComment = struct {
    text: []const u8,
    line: usize,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DocComment) void {
        self.allocator.free(self.text);
    }
};

pub const FunctionDoc = struct {
    name: []const u8,
    params: []const []const u8,
    return_type: ?[]const u8,
    doc_comment: ?[]const u8,
    line: usize,
    is_pub: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *FunctionDoc) void {
        self.allocator.free(self.name);
        for (self.params) |param| {
            self.allocator.free(param);
        }
        self.allocator.free(self.params);
        if (self.return_type) |rt| {
            self.allocator.free(rt);
        }
        if (self.doc_comment) |dc| {
            self.allocator.free(dc);
        }
    }
};

pub const ClassDoc = struct {
    name: []const u8,
    doc_comment: ?[]const u8,
    methods: []FunctionDoc,
    line: usize,
    is_pub: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ClassDoc) void {
        self.allocator.free(self.name);
        if (self.doc_comment) |dc| {
            self.allocator.free(dc);
        }
        for (self.methods) |*method| {
            method.deinit();
        }
        self.allocator.free(self.methods);
    }
};

pub const ModuleDoc = struct {
    name: []const u8,
    path: []const u8,
    doc_comment: ?[]const u8,
    functions: []FunctionDoc,
    classes: []ClassDoc,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ModuleDoc) void {
        self.allocator.free(self.name);
        self.allocator.free(self.path);
        if (self.doc_comment) |dc| {
            self.allocator.free(dc);
        }
        for (self.functions) |*func| {
            func.deinit();
        }
        self.allocator.free(self.functions);
        for (self.classes) |*class| {
            class.deinit();
        }
        self.allocator.free(self.classes);
    }
};

pub const DocGenerator = struct {
    allocator: std.mem.Allocator,
    project_name: []const u8,
    output_dir: []const u8,
    modules: std.ArrayList(ModuleDoc),

    pub fn init(allocator: std.mem.Allocator, project_name: []const u8, output_dir: []const u8) !DocGenerator {
        return DocGenerator{
            .allocator = allocator,
            .project_name = try allocator.dupe(u8, project_name),
            .output_dir = try allocator.dupe(u8, output_dir),
            .modules = std.ArrayList(ModuleDoc).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *DocGenerator) void {
        self.allocator.free(self.project_name);
        self.allocator.free(self.output_dir);
        for (self.modules.items) |*module| {
            module.deinit();
        }
        self.modules.deinit(self.allocator);
    }

    /// Scan a directory for .mufi files and parse them
    pub fn scanDirectory(self: *DocGenerator, dir_path: []const u8) !void {
        var dir = try std.Io.Dir.cwd().openDir(system.global_io, dir_path, .{ .iterate = true });
        defer dir.close(system.global_io);

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        while (try walker.next(system.global_io)) |entry| {
            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.path, ".mufi")) {
                    const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ dir_path, entry.path });
                    defer self.allocator.free(full_path);

                    try self.parseFile(full_path, entry.path);
                }
            }
        }
    }

    /// Parse a single .mufi file and extract documentation
    fn parseFile(self: *DocGenerator, file_path: []const u8, relative_path: []const u8) !void {
        const file = try std.Io.Dir.cwd().openFile(system.global_io, file_path, .{});
        defer file.close(system.global_io);

        var buf: [4096]u8 = undefined;
        var reader = file.reader(system.global_io, &buf);
        const content = try reader.interface.readAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        var module = ModuleDoc{
            .name = try self.allocator.dupe(u8, relative_path),
            .path = try self.allocator.dupe(u8, file_path),
            .doc_comment = null,
            .functions = &[_]FunctionDoc{},
            .classes = &[_]ClassDoc{},
            .allocator = self.allocator,
        };

        var functions = std.ArrayList(FunctionDoc).initCapacity(self.allocator, 0) catch unreachable;
        var classes = std.ArrayList(ClassDoc).initCapacity(self.allocator, 0) catch unreachable;

        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: usize = 1;
        var pending_doc_comment: ?[]const u8 = null;
        var module_doc_captured = false;

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Check for doc comments (/// or /** */)
            if (std.mem.startsWith(u8, trimmed, "///")) {
                const comment_text = std.mem.trim(u8, trimmed[3..], " \t");
                if (pending_doc_comment) |prev| {
                    const combined = try std.fmt.allocPrint(self.allocator, "{s}\n{s}", .{ prev, comment_text });
                    self.allocator.free(prev);
                    pending_doc_comment = combined;
                } else {
                    pending_doc_comment = try self.allocator.dupe(u8, comment_text);
                }
                continue;
            }

            // Check for optional "pub" visibility modifier
            var is_pub = false;
            var decl_start = trimmed;
            if (std.mem.startsWith(u8, trimmed, "pub ")) {
                is_pub = true;
                decl_start = std.mem.trimStart(u8, trimmed[4..], " \t");
            }

            // Check for function definitions
            if (std.mem.startsWith(u8, decl_start, "fun ") or std.mem.startsWith(u8, decl_start, "fn ")) {
                var func_doc = try self.parseFunction(decl_start, line_num, pending_doc_comment);
                func_doc.is_pub = is_pub;
                try functions.append(self.allocator, func_doc);
                pending_doc_comment = null;
                continue;
            }

            // Check for class definitions
            if (std.mem.startsWith(u8, decl_start, "class ")) {
                var class_doc = try self.parseClass(decl_start, line_num, pending_doc_comment);
                class_doc.is_pub = is_pub;
                try classes.append(self.allocator, class_doc);
                pending_doc_comment = null;
                continue;
            }

            // Empty line after doc comment becomes module doc (before any declarations)
            if (trimmed.len == 0 and !module_doc_captured and pending_doc_comment != null) {
                module.doc_comment = pending_doc_comment;
                pending_doc_comment = null;
                module_doc_captured = true;
                continue;
            }

            // If line is not empty and not a continuation, clear pending doc
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "///")) {
                if (pending_doc_comment) |dc| {
                    self.allocator.free(dc);
                    pending_doc_comment = null;
                }
            }
        }

        if (pending_doc_comment) |dc| {
            self.allocator.free(dc);
        }

        module.functions = try functions.toOwnedSlice(self.allocator);
        module.classes = try classes.toOwnedSlice(self.allocator);

        try self.modules.append(self.allocator, module);
    }

    fn parseFunction(self: *DocGenerator, line: []const u8, line_num: usize, doc_comment: ?[]const u8) !FunctionDoc {
        // Parse: fun name(params) or fn name(params)
        const start_idx = if (std.mem.startsWith(u8, line, "fun ")) @as(usize, 4) else @as(usize, 3);
        const after_keyword = line[start_idx..];

        var name_end: usize = 0;
        while (name_end < after_keyword.len and after_keyword[name_end] != '(') : (name_end += 1) {}

        const name = std.mem.trim(u8, after_keyword[0..name_end], " \t");

        // Extract parameters between parentheses
        var params = std.ArrayList([]const u8).initCapacity(self.allocator, 0) catch unreachable;
        if (std.mem.indexOf(u8, after_keyword, "(")) |paren_start| {
            if (std.mem.indexOf(u8, after_keyword[paren_start..], ")")) |paren_len| {
                const params_str = std.mem.trim(u8, after_keyword[paren_start + 1 .. paren_start + paren_len], " \t");
                if (params_str.len > 0) {
                    var param_iter = std.mem.splitScalar(u8, params_str, ',');
                    while (param_iter.next()) |param| {
                        const trimmed_param = std.mem.trim(u8, param, " \t");
                        if (trimmed_param.len > 0) {
                            try params.append(self.allocator, try self.allocator.dupe(u8, trimmed_param));
                        }
                    }
                }
            }
        }

        return FunctionDoc{
            .name = try self.allocator.dupe(u8, name),
            .params = try params.toOwnedSlice(self.allocator),
            .return_type = null,
            .doc_comment = if (doc_comment) |dc| try self.allocator.dupe(u8, dc) else null,
            .line = line_num,
            .is_pub = false,
            .allocator = self.allocator,
        };
    }

    fn parseClass(self: *DocGenerator, line: []const u8, line_num: usize, doc_comment: ?[]const u8) !ClassDoc {
        // Simple parser: class Name
        const after_keyword = std.mem.trim(u8, line[6..], " \t");

        var name_end: usize = 0;
        while (name_end < after_keyword.len and
            after_keyword[name_end] != ' ' and
            after_keyword[name_end] != '{' and
            after_keyword[name_end] != '<') : (name_end += 1)
        {}

        const name = after_keyword[0..name_end];

        return ClassDoc{
            .name = try self.allocator.dupe(u8, name),
            .doc_comment = if (doc_comment) |dc| try self.allocator.dupe(u8, dc) else null,
            .methods = &[_]FunctionDoc{},
            .line = line_num,
            .is_pub = false,
            .allocator = self.allocator,
        };
    }

    /// Generate documentation
    pub fn generate(self: *DocGenerator) !void {
        // Create output directory
        std.Io.Dir.cwd().createDirPath(system.global_io, self.output_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Generate index.html
        try self.generateIndex();

        // Generate individual module pages
        for (self.modules.items) |module| {
            try self.generateModulePage(module);
        }

        // Generate stylesheet
        try self.generateStylesheet();

        // Generate search data (JSON)
        try self.generateSearchData();

        std.debug.print("✅ Documentation generated at: {s}/index.html\n", .{self.output_dir});
    }

    fn generateIndex(self: *DocGenerator) !void {
        const index_path = try std.fmt.allocPrint(self.allocator, "{s}/index.html", .{self.output_dir});
        defer self.allocator.free(index_path);

        const file = try std.Io.Dir.cwd().createFile(system.global_io, index_path, .{});
        defer file.close(system.global_io);

        try file.writeStreamingAll(system.global_io, 
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\    <title>
        );
        const title = try std.fmt.allocPrint(self.allocator, "{s} - Documentation</title>\n", .{self.project_name});
        defer self.allocator.free(title);
        try file.writeStreamingAll(system.global_io, title);
        try file.writeStreamingAll(system.global_io, 
            \\    <link rel="stylesheet" href="style.css">
            \\</head>
            \\<body>
            \\    <header class="header">
            \\        <div class="header-content">
            \\            <div class="header-left">
            \\                <h1 class="project-name">
        );
        const h1 = try std.fmt.allocPrint(self.allocator, "{s}</h1>\n", .{self.project_name});
        defer self.allocator.free(h1);
        try file.writeStreamingAll(system.global_io, h1);
        try file.writeStreamingAll(system.global_io, 
            \\                <span class="header-divider">|</span>
            \\                <span class="header-version">Documentation</span>
            \\            </div>
            \\            <div class="header-right">
            \\                <input type="text" id="search" class="search-input" placeholder="Search modules..." />
            \\            </div>
            \\        </div>
            \\    </header>
            \\    <nav class="sidebar">
            \\        <div class="sidebar-section">
            \\            <h3>Modules</h3>
            \\            <ul class="module-list">
            \\
        );

        // List all modules
        for (self.modules.items) |module| {
            const module_file = try self.getModuleFileName(module.name);
            defer self.allocator.free(module_file);
            const li = try std.fmt.allocPrint(self.allocator, "                <li><a href=\"{s}\">{s}</a></li>\n", .{ module_file, module.name });
            defer self.allocator.free(li);
            try file.writeStreamingAll(system.global_io, li);
        }

        try file.writeStreamingAll(system.global_io, 
            \\            </ul>
            \\        </div>
            \\    </nav>
            \\    <main class="content">
            \\        <div class="main-content">
            \\            <div class="page-header">
            \\                <h1>
        );
        const main_h1 = try std.fmt.allocPrint(self.allocator, "{s}</h1>\n", .{self.project_name});
        defer self.allocator.free(main_h1);
        try file.writeStreamingAll(system.global_io, main_h1);
        try file.writeStreamingAll(system.global_io, 
            \\                <p class="page-description">MufiZ project documentation</p>
            \\            </div>
            \\
            \\            <section class="section">
            \\                <h2 class="section-title">Modules</h2>
            \\                <div class="item-table">
            \\
        );

        for (self.modules.items) |module| {
            const module_file = try self.getModuleFileName(module.name);
            defer self.allocator.free(module_file);

            try file.writeStreamingAll(system.global_io, "                    <div class=\"item-row\">\n");
            try file.writeStreamingAll(system.global_io, "                        <div class=\"item-name\">\n");
            const a_tag = try std.fmt.allocPrint(self.allocator, "                            <a href=\"{s}\">{s}</a>\n", .{ module_file, module.name });
            defer self.allocator.free(a_tag);
            try file.writeStreamingAll(system.global_io, a_tag);
            try file.writeStreamingAll(system.global_io, "                        </div>\n");
            try file.writeStreamingAll(system.global_io, "                        <div class=\"item-desc\">\n");
            if (module.doc_comment) |dc| {
                const first_line_end = std.mem.indexOfScalar(u8, dc, '\n') orelse dc.len;
                const max_len = if (first_line_end > 120) 120 else first_line_end;
                const preview = dc[0..max_len];
                const p_tag = try std.fmt.allocPrint(self.allocator, "                            {s}\n", .{preview});
                defer self.allocator.free(p_tag);
                try file.writeStreamingAll(system.global_io, p_tag);
            }
            try file.writeStreamingAll(system.global_io, "                        </div>\n");
            try file.writeStreamingAll(system.global_io, "                    </div>\n");
        }

        try file.writeStreamingAll(system.global_io, 
            \\                </div>
            \\            </section>
            \\        </div>
            \\    </main>
            \\    <script src="search.js"></script>
            \\</body>
            \\</html>
            \\
        );
    }

    fn generateModulePage(self: *DocGenerator, module: ModuleDoc) !void {
        const module_file = try self.getModuleFileName(module.name);
        defer self.allocator.free(module_file);

        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.output_dir, module_file });
        defer self.allocator.free(file_path);

        const file = try std.Io.Dir.cwd().createFile(system.global_io, file_path, .{});
        defer file.close(system.global_io);

        // HTML header
        try file.writeStreamingAll(system.global_io, 
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\    <title>
        );
        const mod_title = try std.fmt.allocPrint(self.allocator, "{s} - {s}</title>\n", .{ module.name, self.project_name });
        defer self.allocator.free(mod_title);
        try file.writeStreamingAll(system.global_io, mod_title);
        try file.writeStreamingAll(system.global_io, 
            \\    <link rel="stylesheet" href="style.css">
            \\</head>
            \\<body>
            \\    <header class="header">
            \\        <div class="header-content">
            \\            <div class="header-left">
            \\                <h1 class="project-name">
        );
        const sidebar_h1 = try std.fmt.allocPrint(self.allocator, "{s}</h1>\n", .{self.project_name});
        defer self.allocator.free(sidebar_h1);
        try file.writeStreamingAll(system.global_io, sidebar_h1);
        try file.writeStreamingAll(system.global_io, 
            \\                <span class="header-divider">|</span>
            \\                <a href="index.html" class="breadcrumb">Documentation</a>
            \\                <span class="breadcrumb-sep">›</span>
            \\                <span class="breadcrumb-current">
        );
        const breadcrumb = try std.fmt.allocPrint(self.allocator, "{s}</span>\n", .{module.name});
        defer self.allocator.free(breadcrumb);
        try file.writeStreamingAll(system.global_io, breadcrumb);
        try file.writeStreamingAll(system.global_io, 
            \\            </div>
            \\            <div class="header-right">
            \\                <input type="text" id="search" class="search-input" placeholder="Search..." />
            \\            </div>
            \\        </div>
            \\    </header>
            \\
        );
        try file.writeStreamingAll(system.global_io, 
            \\    <nav class="sidebar">
            \\        <div class="sidebar-section">
            \\            <h3>Modules</h3>
            \\            <ul class="module-list">
            \\
        );

        // Add all modules to sidebar
        for (self.modules.items) |mod| {
            const mod_file = try self.getModuleFileName(mod.name);
            defer self.allocator.free(mod_file);

            const is_current = mem.eql(u8, mod.name, module.name);
            const li_class = if (is_current) " class=\"active\"" else "";
            const li_start = try std.fmt.allocPrint(self.allocator, "                <li{s}><a href=\"{s}\">{s}</a></li>\n", .{ li_class, mod_file, mod.name });
            defer self.allocator.free(li_start);
            try file.writeStreamingAll(system.global_io, li_start);
        }

        try file.writeStreamingAll(system.global_io, 
            \\            </ul>
            \\        </div>
            \\
        );

        // Add quick navigation for current module
        if (module.functions.len > 0 or module.classes.len > 0) {
            try file.writeStreamingAll(system.global_io, 
                \\        <div class="sidebar-section">
                \\            <h3>On This Page</h3>
                \\            <ul class="module-list">
                \\
            );

            if (module.functions.len > 0) {
                try file.writeStreamingAll(system.global_io, "                <li class=\"sidebar-category\">Functions</li>\n");
                for (module.functions) |func| {
                    const func_link = try std.fmt.allocPrint(self.allocator, "                <li class=\"sidebar-item\"><a href=\"#fn-{s}\">{s}</a></li>\n", .{ func.name, func.name });
                    defer self.allocator.free(func_link);
                    try file.writeStreamingAll(system.global_io, func_link);
                }
            }

            if (module.classes.len > 0) {
                try file.writeStreamingAll(system.global_io, "                <li class=\"sidebar-category\">Classes</li>\n");
                for (module.classes) |class| {
                    const class_link = try std.fmt.allocPrint(self.allocator, "                <li class=\"sidebar-item\"><a href=\"#class-{s}\">{s}</a></li>\n", .{ class.name, class.name });
                    defer self.allocator.free(class_link);
                    try file.writeStreamingAll(system.global_io, class_link);
                }
            }

            try file.writeStreamingAll(system.global_io, 
                \\            </ul>
                \\        </div>
                \\
            );
        }

        try file.writeStreamingAll(system.global_io, 
            \\    </nav>
            \\    <main class="content">
            \\        <div class="main-content">
            \\            <div class="page-header">
            \\                <h1>
        );
        const mod_h1 = try std.fmt.allocPrint(self.allocator, "{s}</h1>\n", .{module.name});
        defer self.allocator.free(mod_h1);
        try file.writeStreamingAll(system.global_io, mod_h1);

        if (module.doc_comment) |dc| {
            try file.writeStreamingAll(system.global_io, "                <div class=\"module-doc\">\n");
            const mod_desc = try std.fmt.allocPrint(self.allocator, "                    <p>{s}</p>\n", .{dc});
            defer self.allocator.free(mod_desc);
            try file.writeStreamingAll(system.global_io, mod_desc);
            try file.writeStreamingAll(system.global_io, "                </div>\n");
        }

        try file.writeStreamingAll(system.global_io, "            </div>\n");

        // Functions section
        if (module.functions.len > 0) {
            try file.writeStreamingAll(system.global_io, 
                \\
                \\            <section class="section">
                \\                <h2 class="section-title">Functions</h2>
                \\                <div class="item-table">
                \\
            );

            for (module.functions) |func| {
                const func_id = try std.fmt.allocPrint(self.allocator, "                    <div class=\"item-row\" id=\"fn-{s}\">\n", .{func.name});
                defer self.allocator.free(func_id);
                try file.writeStreamingAll(system.global_io, func_id);
                try file.writeStreamingAll(system.global_io, "                        <div class=\"item-header\">\n");

                // Add visibility tag
                if (func.is_pub) {
                    try file.writeStreamingAll(system.global_io, "                            <span class=\"visibility public\">pub</span>\n");
                } else {
                    try file.writeStreamingAll(system.global_io, "                            <span class=\"visibility private\">priv</span>\n");
                }

                // Build function signature
                var signature = std.ArrayList(u8).initCapacity(self.allocator, 0) catch unreachable;
                defer signature.deinit(self.allocator);
                try signature.appendSlice(self.allocator, "fun ");
                try signature.appendSlice(self.allocator, func.name);
                try signature.append(self.allocator, '(');
                for (func.params, 0..) |param, i| {
                    if (i > 0) try signature.appendSlice(self.allocator, ", ");
                    try signature.appendSlice(self.allocator, param);
                }
                try signature.append(self.allocator, ')');

                const func_sig = try std.fmt.allocPrint(self.allocator, "                            <code class=\"signature\">{s}</code>\n", .{signature.items});
                defer self.allocator.free(func_sig);
                try file.writeStreamingAll(system.global_io, func_sig);
                try file.writeStreamingAll(system.global_io, "                        </div>\n");

                if (func.doc_comment) |dc| {
                    try file.writeStreamingAll(system.global_io, "                        <div class=\"item-desc\">\n");
                    const func_p = try std.fmt.allocPrint(self.allocator, "                            {s}\n", .{dc});
                    defer self.allocator.free(func_p);
                    try file.writeStreamingAll(system.global_io, func_p);
                    try file.writeStreamingAll(system.global_io, "                        </div>\n");
                }

                try file.writeStreamingAll(system.global_io, "                    </div>\n");
            }

            try file.writeStreamingAll(system.global_io, "                </div>\n");
            try file.writeStreamingAll(system.global_io, "            </section>\n");
        }

        // Classes section
        if (module.classes.len > 0) {
            try file.writeStreamingAll(system.global_io, 
                \\
                \\            <section class="section">
                \\                <h2 class="section-title">Classes</h2>
                \\                <div class="item-table">
                \\
            );

            for (module.classes) |class| {
                const class_id = try std.fmt.allocPrint(self.allocator, "                    <div class=\"item-row\" id=\"class-{s}\">\n", .{class.name});
                defer self.allocator.free(class_id);
                try file.writeStreamingAll(system.global_io, class_id);
                try file.writeStreamingAll(system.global_io, "                        <div class=\"item-header\">\n");

                // Add visibility tag
                if (class.is_pub) {
                    try file.writeStreamingAll(system.global_io, "                            <span class=\"visibility public\">pub</span>\n");
                } else {
                    try file.writeStreamingAll(system.global_io, "                            <span class=\"visibility private\">priv</span>\n");
                }

                const class_sig = try std.fmt.allocPrint(self.allocator, "                            <code class=\"signature\">class {s}</code>\n", .{class.name});
                defer self.allocator.free(class_sig);
                try file.writeStreamingAll(system.global_io, class_sig);
                try file.writeStreamingAll(system.global_io, "                        </div>\n");

                if (class.doc_comment) |dc| {
                    try file.writeStreamingAll(system.global_io, "                        <div class=\"item-desc\">\n");
                    const class_p = try std.fmt.allocPrint(self.allocator, "                            {s}\n", .{dc});
                    defer self.allocator.free(class_p);
                    try file.writeStreamingAll(system.global_io, class_p);
                    try file.writeStreamingAll(system.global_io, "                        </div>\n");
                }

                try file.writeStreamingAll(system.global_io, "                    </div>\n");
            }

            try file.writeStreamingAll(system.global_io, "                </div>\n");
            try file.writeStreamingAll(system.global_io, "            </section>\n");
        }

        try file.writeStreamingAll(system.global_io, 
            \\        </div>
            \\    </main>
            \\    <script src="search.js"></script>
            \\</body>
            \\</html>
            \\
        );
    }

    fn generateStylesheet(self: *DocGenerator) !void {
        const css_path = try std.fmt.allocPrint(self.allocator, "{s}/style.css", .{self.output_dir});
        defer self.allocator.free(css_path);

        const file = try std.Io.Dir.cwd().createFile(system.global_io, css_path, .{});
        defer file.close(system.global_io);

        try file.writeStreamingAll(system.global_io, 
            \\* {
            \\    margin: 0;
            \\    padding: 0;
            \\    box-sizing: border-box;
            \\}
            \\
            \\:root {
            \\    --gradient-start: #667eea;
            \\    --gradient-end: #764ba2;
            \\    --bg-dark: #0d1117;
            \\    --bg-secondary: #161b22;
            \\    --bg-tertiary: #21262d;
            \\    --text-primary: #c9d1d9;
            \\    --text-secondary: #8b949e;
            \\    --text-muted: #6e7681;
            \\    --border: #30363d;
            \\    --accent: #58a6ff;
            \\    --accent-hover: #79c0ff;
            \\}
            \\
            \\body {
            \\    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            \\    background: var(--bg-dark);
            \\    color: var(--text-primary);
            \\    line-height: 1.6;
            \\    min-height: 100vh;
            \\}
            \\
            \\/* Header with gradient */
            \\.header {
            \\    background: linear-gradient(135deg, var(--gradient-start) 0%, var(--gradient-end) 100%);
            \\    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            \\    position: sticky;
            \\    top: 0;
            \\    z-index: 100;
            \\    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
            \\}
            \\
            \\.header-content {
            \\    max-width: 1400px;
            \\    margin: 0 auto;
            \\    padding: 1rem 2rem;
            \\    display: flex;
            \\    justify-content: space-between;
            \\    align-items: center;
            \\}
            \\
            \\.header-left {
            \\    display: flex;
            \\    align-items: center;
            \\    gap: 1rem;
            \\}
            \\
            \\.project-name {
            \\    font-size: 1.5rem;
            \\    font-weight: 600;
            \\    color: white;
            \\    margin: 0;
            \\}
            \\
            \\.header-divider {
            \\    color: rgba(255, 255, 255, 0.5);
            \\    font-weight: 300;
            \\}
            \\
            \\.header-version {
            \\    color: rgba(255, 255, 255, 0.9);
            \\    font-size: 1rem;
            \\}
            \\
            \\.breadcrumb {
            \\    color: rgba(255, 255, 255, 0.9);
            \\    text-decoration: none;
            \\    transition: color 0.2s;
            \\}
            \\
            \\.breadcrumb:hover {
            \\    color: white;
            \\    text-decoration: underline;
            \\}
            \\
            \\.breadcrumb-sep {
            \\    color: rgba(255, 255, 255, 0.5);
            \\    margin: 0 0.5rem;
            \\}
            \\
            \\.breadcrumb-current {
            \\    color: rgba(255, 255, 255, 0.7);
            \\}
            \\
            \\.search-input {
            \\    padding: 0.5rem 1rem;
            \\    border: 1px solid rgba(255, 255, 255, 0.2);
            \\    background: rgba(255, 255, 255, 0.1);
            \\    color: white;
            \\    border-radius: 6px;
            \\    font-size: 0.9rem;
            \\    min-width: 300px;
            \\    transition: all 0.2s;
            \\}
            \\
            \\.search-input::placeholder {
            \\    color: rgba(255, 255, 255, 0.5);
            \\}
            \\
            \\.search-input:focus {
            \\    outline: none;
            \\    background: rgba(255, 255, 255, 0.15);
            \\    border-color: rgba(255, 255, 255, 0.3);
            \\}
            \\
            \\/* Sidebar */
            \\.sidebar {
            \\    position: fixed;
            \\    top: 73px;
            \\    left: 0;
            \\    width: 250px;
            \\    height: calc(100vh - 73px);
            \\    background: var(--bg-secondary);
            \\    border-right: 1px solid var(--border);
            \\    overflow-y: auto;
            \\    padding: 1.5rem;
            \\}
            \\
            \\.sidebar-section h3 {
            \\    font-size: 0.875rem;
            \\    text-transform: uppercase;
            \\    letter-spacing: 0.05em;
            \\    color: var(--text-muted);
            \\    margin-bottom: 0.75rem;
            \\    font-weight: 600;
            \\}
            \\
            \\.module-list {
            \\    list-style: none;
            \\}
            \\
            \\.module-list li {
            \\    margin-bottom: 0.25rem;
            \\}
            \\
            \\.module-list a {
            \\    display: block;
            \\    padding: 0.5rem 0.75rem;
            \\    color: var(--text-secondary);
            \\    text-decoration: none;
            \\    border-radius: 6px;
            \\    transition: all 0.2s;
            \\    font-size: 0.95rem;
            \\}
            \\
            \\.module-list a:hover {
            \\    background: var(--bg-tertiary);
            \\    color: var(--accent-hover);
            \\}
            \\
            \\.module-list li.active a {
            \\    background: var(--bg-tertiary);
            \\    color: var(--accent);
            \\    font-weight: 600;
            \\}
            \\
            \\.sidebar-section + .sidebar-section {
            \\    margin-top: 2rem;
            \\    padding-top: 1.5rem;
            \\    border-top: 1px solid var(--border);
            \\}
            \\
            \\.sidebar-category {
            \\    color: var(--text-muted);
            \\    font-size: 0.8rem;
            \\    font-weight: 600;
            \\    text-transform: uppercase;
            \\    letter-spacing: 0.05em;
            \\    padding: 0.5rem 0.75rem;
            \\    margin-top: 0.5rem;
            \\}
            \\
            \\.sidebar-item a {
            \\    font-size: 0.875rem;
            \\    padding-left: 1.5rem;
            \\}
            \\
            \\/* Main content */
            \\.content {
            \\    margin-left: 250px;
            \\    padding: 2rem;
            \\}
            \\
            \\.content-full {
            \\    margin-left: 0;
            \\    max-width: 1200px;
            \\    margin: 0 auto;
            \\}
            \\
            \\.main-content {
            \\    max-width: 1000px;
            \\}
            \\
            \\.page-header {
            \\    margin-bottom: 2rem;
            \\    padding-bottom: 1rem;
            \\    border-bottom: 1px solid var(--border);
            \\}
            \\
            \\.page-header h1 {
            \\    font-size: 2.5rem;
            \\    font-weight: 600;
            \\    margin-bottom: 0.5rem;
            \\    background: linear-gradient(135deg, var(--gradient-start) 0%, var(--gradient-end) 100%);
            \\    -webkit-background-clip: text;
            \\    -webkit-text-fill-color: transparent;
            \\    background-clip: text;
            \\}
            \\
            \\.page-description {
            \\    font-size: 1.1rem;
            \\    color: var(--text-secondary);
            \\}
            \\
            \\.module-doc {
            \\    margin-top: 1rem;
            \\    padding: 1rem;
            \\    background: var(--bg-secondary);
            \\    border-left: 3px solid var(--gradient-start);
            \\    border-radius: 4px;
            \\}
            \\
            \\.module-doc p {
            \\    color: var(--text-primary);
            \\    line-height: 1.7;
            \\}
            \\
            \\/* Sections */
            \\.section {
            \\    margin-bottom: 3rem;
            \\}
            \\
            \\.section-title {
            \\    font-size: 1.75rem;
            \\    font-weight: 600;
            \\    margin-bottom: 1.5rem;
            \\    color: var(--text-primary);
            \\}
            \\
            \\/* Item table */
            \\.item-table {
            \\    border: 1px solid var(--border);
            \\    border-radius: 8px;
            \\    overflow: hidden;
            \\    background: var(--bg-secondary);
            \\}
            \\
            \\.item-row {
            \\    padding: 1.25rem 1.5rem;
            \\    border-bottom: 1px solid var(--border);
            \\    transition: background 0.2s;
            \\}
            \\
            \\.item-row:last-child {
            \\    border-bottom: none;
            \\}
            \\
            \\.item-row:hover {
            \\    background: var(--bg-tertiary);
            \\}
            \\
            \\.item-name {
            \\    margin-bottom: 0.5rem;
            \\}
            \\
            \\.item-name a {
            \\    font-size: 1.1rem;
            \\    font-weight: 500;
            \\    color: var(--accent);
            \\    text-decoration: none;
            \\    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            \\}
            \\
            \\.item-name a:hover {
            \\    color: var(--accent-hover);
            \\    text-decoration: underline;
            \\}
            \\
            \\.item-header {
            \\    margin-bottom: 0.75rem;
            \\}
            \\
            \\.signature {
            \\    display: inline-block;
            \\    padding: 0.5rem 0.75rem;
            \\    background: var(--bg-tertiary);
            \\    border: 1px solid var(--border);
            \\    border-radius: 6px;
            \\    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            \\    font-size: 1rem;
            \\    color: var(--accent);
            \\    font-weight: 500;
            \\}
            \\
            \\.visibility {
            \\    display: inline-block;
            \\    padding: 0.2rem 0.5rem;
            \\    border-radius: 4px;
            \\    font-size: 0.8rem;
            \\    font-weight: 600;
            \\    text-transform: uppercase;
            \\    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            \\}
            \\
            \\.visibility.public {
            \\    background: rgba(46, 160, 67, 0.15);
            \\    color: #3fb950;
            \\    border: 1px solid rgba(46, 160, 67, 0.4);
            \\}
            \\
            \\.visibility.private {
            \\    background: rgba(248, 81, 73, 0.15);
            \\    color: #f85149;
            \\    border: 1px solid rgba(248, 81, 73, 0.4);
            \\}
            \\
            \\.item-desc {
            \\    color: var(--text-secondary);
            \\    font-size: 1rem;
            \\    line-height: 1.6;
            \\}
            \\
            \\/* Responsive */
            \\@media (max-width: 768px) {
            \\    .sidebar {
            \\        display: none;
            \\    }
            \\
            \\    .content {
            \\        margin-left: 0;
            \\    }
            \\
            \\    .header-content {
            \\        flex-direction: column;
            \\        gap: 1rem;
            \\        align-items: flex-start;
            \\    }
            \\
            \\    .search-input {
            \\        width: 100%;
            \\    }
            \\
            \\    .page-header h1 {
            \\        font-size: 2rem;
            \\    }
            \\}
            \\
        );
    }

    fn generateSearchData(self: *DocGenerator) !void {
        const js_path = try std.fmt.allocPrint(self.allocator, "{s}/search.js", .{self.output_dir});
        defer self.allocator.free(js_path);

        const file = try std.Io.Dir.cwd().createFile(system.global_io, js_path, .{});
        defer file.close(system.global_io);

        try file.writeStreamingAll(system.global_io, 
            \\// Enhanced search functionality
            \\document.addEventListener('DOMContentLoaded', function() {
            \\    const searchInput = document.getElementById('search');
            \\    if (!searchInput) return;
            \\
            \\    searchInput.addEventListener('input', function(e) {
            \\        const query = e.target.value.toLowerCase().trim();
            \\
            \\        // Search in sidebar modules
            \\        const moduleLinks = document.querySelectorAll('.sidebar-section:first-child .module-list li');
            \\        moduleLinks.forEach(li => {
            \\            const link = li.querySelector('a');
            \\            if (!link) return;
            \\            const text = link.textContent.toLowerCase();
            \\            li.style.display = text.includes(query) ? 'block' : 'none';
            \\        });
            \\
            \\        // Search in page content (functions, classes)
            \\        const items = document.querySelectorAll('.item-row');
            \\        items.forEach(item => {
            \\            const signature = item.querySelector('.signature');
            \\            const desc = item.querySelector('.item-desc');
            \\            const sigText = signature ? signature.textContent.toLowerCase() : '';
            \\            const descText = desc ? desc.textContent.toLowerCase() : '';
            \\
            \\            if (sigText.includes(query) || descText.includes(query)) {
            \\                item.style.display = '';
            \\            } else {
            \\                item.style.display = 'none';
            \\            }
            \\        });
            \\
            \\        // If query is empty, show all
            \\        if (query === '') {
            \\            moduleLinks.forEach(li => li.style.display = 'block');
            \\            items.forEach(item => item.style.display = '');
            \\        }
            \\    });
            \\
            \\    // Focus search with '/' key
            \\    document.addEventListener('keydown', function(e) {
            \\        if (e.key === '/' && document.activeElement !== searchInput) {
            \\            e.preventDefault();
            \\            searchInput.focus();
            \\        }
            \\    });
            \\});
            \\
        );
    }

    fn getModuleFileName(self: *DocGenerator, module_name: []const u8) ![]const u8 {
        // Convert src/foo.mufi -> foo.html
        var name = module_name;

        // Remove .mufi extension if present
        if (std.mem.endsWith(u8, name, ".mufi")) {
            name = name[0 .. name.len - 5];
        }

        // Remove src/ prefix if present
        if (std.mem.startsWith(u8, name, "src/")) {
            name = name[4..];
        }

        // Replace / with _ for nested modules
        var result = try self.allocator.alloc(u8, name.len + 5); // +5 for ".html"
        var i: usize = 0;
        for (name) |c| {
            result[i] = if (c == '/' or c == '\\') '_' else c;
            i += 1;
        }

        // Add .html extension
        @memcpy(result[i .. i + 5], ".html");

        return result;
    }
};

/// Generate documentation for a MufiZ project
pub fn generateDocs(allocator: std.mem.Allocator, project_name: []const u8) !void {
    std.debug.print("📚 Generating documentation for '{s}'...\n", .{project_name});

    var doc_gen = try DocGenerator.init(allocator, project_name, "docs");
    defer doc_gen.deinit();

    // Scan src directory for .mufi files
    doc_gen.scanDirectory("src") catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("❌ Error: src/ directory not found\n", .{});
            return;
        }
        return err;
    };

    // Generate documentation
    try doc_gen.generate();

    std.debug.print("\n💡 To view the documentation:\n", .{});
    std.debug.print("   Open docs/index.html in your browser\n", .{});
    std.debug.print("   Or run: python3 -m http.server -d docs\n", .{});
}
