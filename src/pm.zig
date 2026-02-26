/// MufiZ Package Manager
/// Handles project creation, initialization, and management
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const cache = @import("cache.zig");
const resolver = @import("resolver.zig");
const docgen = @import("docgen.zig");

pub const PMError = error{
    ProjectAlreadyExists,
    InvalidProjectName,
    FileSystemError,
    ZonWriteError,
    ZonReadError,
    DirectoryCreationError,
    DependencyInstallFailed,
    InvalidDependencySpec,
};

pub const ProjectMetadata = struct {
    name: []const u8,
    version: []const u8,
    authors: []const []const u8,
    description: []const u8,
    license: []const u8,

    pub fn default(name: []const u8) ProjectMetadata {
        return .{
            .name = name,
            .version = "0.1.0",
            .authors = &[_][]const u8{},
            .description = "",
            .license = "MIT",
        };
    }
};

/// Initialize a new MufiZ project in the current directory
pub fn initProject(allocator: std.mem.Allocator, project_name: []const u8) !void {
    // Validate project name
    if (project_name.len == 0) {
        return PMError.InvalidProjectName;
    }

    // Check if mufi.zon already exists
    const cwd = fs.cwd();
    if (cwd.access("mufi.zon", .{})) |_| {
        std.debug.print("Error: Project already initialized (mufi.zon exists)\n", .{});
        return PMError.ProjectAlreadyExists;
    } else |_| {
        // File doesn't exist, we can proceed
    }

    std.debug.print("📦 Initializing MufiZ project: {s}\n", .{project_name});

    // Create project structure
    try createProjectStructure(allocator, cwd, project_name);

    std.debug.print("✅ Project '{s}' initialized successfully!\n", .{project_name});
    std.debug.print("\nProject structure:\n", .{});
    std.debug.print("  mufi.zon        - Project metadata\n", .{});
    std.debug.print("  src/main.mufi   - Entry point\n", .{});
    std.debug.print("\nNext steps:\n", .{});
    std.debug.print("  1. Edit src/main.mufi to write your code\n", .{});
    std.debug.print("  2. Run your project with: mufiz -r src/main.mufi\n", .{});
}

/// Create a new MufiZ project in a new directory
pub fn newProject(allocator: std.mem.Allocator, project_name: []const u8) !void {
    // Validate project name
    if (project_name.len == 0) {
        return PMError.InvalidProjectName;
    }

    // Check if directory already exists
    const cwd = fs.cwd();
    if (cwd.access(project_name, .{})) |_| {
        std.debug.print("Error: Directory '{s}' already exists\n", .{project_name});
        return PMError.ProjectAlreadyExists;
    } else |_| {
        // Directory doesn't exist, we can proceed
    }

    std.debug.print("📦 Creating new MufiZ project: {s}\n", .{project_name});

    // Create project directory
    try cwd.makeDir(project_name);
    var project_dir = try cwd.openDir(project_name, .{});
    defer project_dir.close();

    // Create project structure
    try createProjectStructure(allocator, project_dir, project_name);

    std.debug.print("✅ Project '{s}' created successfully!\n", .{project_name});
    std.debug.print("\nProject structure:\n", .{});
    std.debug.print("  {s}/\n", .{project_name});
    std.debug.print("  ├── mufi.zon\n", .{});
    std.debug.print("  └── src/\n", .{});
    std.debug.print("      └── main.mufi\n", .{});
    std.debug.print("\nNext steps:\n", .{});
    std.debug.print("  1. cd {s}\n", .{project_name});
    std.debug.print("  2. Edit src/main.mufi to write your code\n", .{});
    std.debug.print("  3. Run your project with: mufiz -r src/main.mufi\n", .{});
}

/// Create the project structure (mufi.zon and src/main.mufi)
fn createProjectStructure(allocator: std.mem.Allocator, dir: fs.Dir, project_name: []const u8) !void {
    // Create mufi.zon with formatted content
    const zon_content = try generateZonContent(allocator, project_name);
    defer allocator.free(zon_content);

    try writeFile(dir, "mufi.zon", zon_content);

    // Create src directory
    dir.makeDir("src") catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("Error creating src directory: {any}\n", .{err});
            return PMError.DirectoryCreationError;
        }
    };

    // Create src/main.mufi
    const main_content = generateMainMufiContent(project_name);
    var src_dir = try dir.openDir("src", .{});
    defer src_dir.close();
    try writeFile(src_dir, "main.mufi", main_content);
}

/// Generate the content for mufi.zon
fn generateZonContent(allocator: std.mem.Allocator, project_name: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        \\.{{
        \\    .package = .{{
        \\        .name = "{s}",
        \\        .version = "0.1.0",
        \\        .authors = .{{}},
        \\        .description = "A MufiZ project",
        \\        .license = "MIT",
        \\    }},
        \\    .project = .{{
        \\        .entry_point = "src/main.mufi",
        \\    }},
        \\}}
        \\
    , .{project_name});
}

/// Generate the content for src/main.mufi
fn generateMainMufiContent(project_name: []const u8) []const u8 {
    _ = project_name;
    return 
    \\// Welcome to your new MufiZ project!
    \\// This is the entry point of your application.
    \\
    \\println("Hello from MufiZ! 🚀");
    \\
    \\// Example: Simple function
    \\fun greet(name) {
    \\    println("Hello, " + name + "!");
    \\}
    \\
    \\greet("World");
    \\
    \\// Example: Using the math module
    \\import math;
    \\
    \\fun calculate_circle_area(radius) {
    \\    return math.PI * radius * radius;
    \\}
    \\
    \\var radius = 5;
    \\var area = calculate_circle_area(radius);
    \\println("Circle area with radius " + str(radius) + ": " + str(area));
    \\
    \\// Add your code here!
    \\
    ;
}

/// Write content to a file
fn writeFile(dir: fs.Dir, filename: []const u8, content: []const u8) !void {
    const file = try dir.createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

/// Display information about the current project
pub fn info(allocator: std.mem.Allocator) !void {
    const cwd = fs.cwd();

    // Check if mufi.zon exists
    if (cwd.access("mufi.zon", .{})) |_| {
        // mufi.zon exists, proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.zon not found)\n", .{});
        std.debug.print("Run 'mufiz pm init <project_name>' to initialize a project\n", .{});
        return;
    }

    // Read mufi.zon
    const file = try cwd.openFile("mufi.zon", .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const content = try file.readToEndAlloc(arena_allocator, 1024 * 1024);

    std.debug.print("📦 Project Information\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("\n{s}\n", .{content});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
}

/// Run the project (execute src/main.mufi)
pub fn run(allocator: std.mem.Allocator) !void {
    const cwd = fs.cwd();

    // Check if mufi.zon exists
    if (cwd.access("mufi.zon", .{})) |_| {
        // mufi.zon exists, proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.zon not found)\n", .{});
        std.debug.print("Run 'mufiz pm init <project_name>' to initialize a project\n", .{});
        return;
    }

    // Read project metadata to get entry point
    const entry_point = try readEntryPoint(allocator, cwd);
    defer allocator.free(entry_point);

    // Check if entry point exists
    if (cwd.access(entry_point, .{})) |_| {
        // Entry point exists, proceed
    } else |_| {
        std.debug.print("Error: Entry point not found ({s})\n", .{entry_point});
        return;
    }

    std.debug.print("🚀 Running MufiZ project...\n\n", .{});

    // Import the runner from lib.zig
    const mufiz = @import("lib.zig");
    const module_registry = @import("module_registry.zig");

    // Initialize mufiz (initializes module_registry)
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer mufiz.deinit();

    // Load and register dependencies
    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    var resolved: std.ArrayList(resolver.DependencySpec) = undefined;
    if (cwd.access("mufi.lock", .{})) |_| {
        resolved = try readLockfile(allocator, cwd);
    } else |_| {
        resolved = try resolveAllDependencies(allocator, cwd);
    }
    defer {
        for (resolved.items) |*dep| dep.deinit();
        resolved.deinit(allocator);
    }

    for (resolved.items) |dep| {
        if (try pkg_cache.getCachedPath(dep.url, dep.version)) |cached_path| {
            defer allocator.free(cached_path);
            var dep_dir = try fs.cwd().openDir(cached_path, .{});
            defer dep_dir.close();
            
            const dep_entry_point = try readEntryPoint(allocator, dep_dir);
            defer allocator.free(dep_entry_point);
            
            const full_dep_entry_path = try std.fs.path.join(allocator, &[_][]const u8{ cached_path, dep_entry_point });
            defer allocator.free(full_dep_entry_path);
            
            try module_registry.registerDependency(dep.name, full_dep_entry_path);
        } else {
            std.debug.print("Warning: Dependency '{s}' not found in cache. Run 'mufiz pm install' first.\n", .{dep.name});
        }
    }

    var runner = mufiz.Runner.init(allocator);
    defer runner.deinit();

    try runner.setMain(@constCast(entry_point));
    try runner.runFile();
}

/// Read the entry point from mufi.zon
fn readEntryPoint(allocator: std.mem.Allocator, dir: fs.Dir) ![]const u8 {
    const zon_bytes = dir.readFileAlloc(allocator, "mufi.zon", 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            return try allocator.dupe(u8, "src/main.mufi"); // Default
        }
        return err;
    };
    defer allocator.free(zon_bytes);

    if (extractQuotedField(zon_bytes, ".entry_point")) |entry| {
        return try allocator.dupe(u8, entry);
    }

    return try allocator.dupe(u8, "src/main.mufi"); // Default
}

/// Resolve all dependencies (including transitive) using topological sort
fn resolveAllDependencies(allocator: std.mem.Allocator, root_dir: fs.Dir) !std.ArrayList(resolver.DependencySpec) {
    // Initialize cache
    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    // Initialize resolver
    var dep_resolver = try resolver.Resolver.init(allocator);
    defer dep_resolver.deinit();

    // Queue for dependencies to process
    var queue = try std.ArrayList(resolver.DependencySpec).initCapacity(allocator, 0);
    defer {
        for (queue.items) |*item| {
            item.deinit();
        }
        queue.deinit(allocator);
    }

    // Visited set: key = "url@version"
    var visited = std.StringHashMap(void).init(allocator);
    defer {
        var iter = visited.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        visited.deinit();
    }

    // 1. Read root dependencies
    {
        var root_deps = try readDependencies(allocator, root_dir);
        defer root_deps.deinit(allocator);

        for (root_deps.items) |dep| {
            const clone = try dep.clone(allocator);
            try queue.append(allocator, clone);
            try dep_resolver.addDependency(try dep.clone(allocator));
        }
        for (root_deps.items) |*dep| {
            dep.deinit();
        }
    }

    // 2. Process Queue recursively
    var i: usize = 0;
    while (i < queue.items.len) : (i += 1) {
        const current_dep = queue.items[i];

        const visit_key = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ current_dep.url, current_dep.version });
        if (visited.contains(visit_key)) {
            allocator.free(visit_key);
            continue;
        }
        try visited.put(visit_key, {});

        std.debug.print("pm: resolving {s} ({s})\n", .{ current_dep.name, current_dep.version });

        // We MUST download/cache it now to see its dependencies
        const cached_pkg = try pkg_cache.cachePackage(current_dep.name, current_dep.url, current_dep.dep_type, current_dep.version);
        
        // Update hash in the spec and resolver
        if (queue.items[i].hash) |h| allocator.free(h);
        queue.items[i].hash = try allocator.dupe(u8, cached_pkg.hash);
        
        if (try dep_resolver.getNodeByName(current_dep.name)) |node| {
            if (node.spec.hash) |h| allocator.free(h);
            node.spec.hash = try allocator.dupe(u8, cached_pkg.hash);
        }

        const pkg_dir_path = try allocator.dupe(u8, cached_pkg.path);
        defer allocator.free(pkg_dir_path);
        
        defer {
            var mut_pkg = cached_pkg;
            mut_pkg.deinit();
        }

        var pkg_dir = fs.cwd().openDir(pkg_dir_path, .{}) catch continue;
        defer pkg_dir.close();

        if (pkg_dir.access("mufi.zon", .{})) |_| {
            var sub_deps = try readDependencies(allocator, pkg_dir);
            defer {
                for (sub_deps.items) |*d| d.deinit();
                sub_deps.deinit(allocator);
            }

            for (sub_deps.items) |sub_dep| {
                try queue.append(allocator, try sub_dep.clone(allocator));
                try dep_resolver.addDependency(try sub_dep.clone(allocator));
                try dep_resolver.addEdge(current_dep.name, sub_dep.name);
            }
        } else |_| {}
    }

    // 3. Final Resolve (Topological Sort)
    try dep_resolver.validate();
    return try dep_resolver.resolve();
}

/// Install project dependencies recursively
pub fn install(allocator: std.mem.Allocator) !void {
    const cwd = fs.cwd();

    if (cwd.access("mufi.zon", .{})) |_| {
        // proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.zon not found)\n", .{});
        return;
    }

    std.debug.print("📦 Installing dependencies...\n\n", .{});

    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    var resolved: std.ArrayList(resolver.DependencySpec) = undefined;

    if (cwd.access("mufi.lock", .{})) |_| {
        std.debug.print("♻️  Using mufi.lock\n", .{});
        resolved = try readLockfile(allocator, cwd);
    } else |_| {
        resolved = try resolveAllDependencies(allocator, cwd);
    }
    defer {
        for (resolved.items) |*dep| dep.deinit();
        resolved.deinit(allocator);
    }

    // Ensure all resolved deps are actually cached (if they were added manually to lock or something)
    for (resolved.items) |*dep| {
        const cached = try pkg_cache.cachePackage(dep.name, dep.url, dep.dep_type, dep.version);
        // Ensure hash is up to date
        if (dep.hash) |h| allocator.free(h);
        dep.hash = try allocator.dupe(u8, cached.hash);
        
        var mut_cached = cached;
        mut_cached.deinit();
    }

    // Regenerate/Update lockfile
    try writeLockfile(allocator, cwd, resolved);

    std.debug.print("📊 Resolved {d} total dependencies (including transitive)\n", .{resolved.items.len});
    for (resolved.items) |dep| {
        std.debug.print("  - {s} @ {s}\n", .{ dep.name, dep.version });
    }

    std.debug.print("\n✅ All dependencies installed successfully!\n", .{});
}

    // (Optional) Print final install order
    for (resolved.items) |dep| {
        std.debug.print("  - {s} @ {s}\n", .{ dep.name, dep.version });
    }

    std.debug.print("\n✅ All dependencies installed successfully!\n", .{});
}

/// Write the resolved dependencies to mufi.lock
fn writeLockfile(allocator: std.mem.Allocator, root_dir: fs.Dir, resolved: std.ArrayList(resolver.DependencySpec)) !void {
    var content = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer content.deinit(allocator);

    try content.appendSlice(allocator, ".{\n");
    try content.appendSlice(allocator, "    .dependencies = .{\n");

    for (resolved.items) |dep| {
        const sanitized = try sanitizeDepName(allocator, dep.name);
        defer allocator.free(sanitized);

        const dep_type_str = switch (dep.dep_type) {
            .Git => ".Git",
            .Local => ".Local",
            .Http => ".Http",
        };

        const entry = try std.fmt.allocPrint(allocator,
            \\        .{s} = .{{
            \\            .name = "{s}",
            \\            .src = "{s}",
            \\            .type = {s},
            \\            .version = "{s}",
            \\            .hash = "{s}",
            \\        }},
            \\
        , .{ sanitized, dep.name, dep.url, dep_type_str, dep.version, dep.hash orelse "" });
        defer allocator.free(entry);
        try content.appendSlice(allocator, entry);
    }

    try content.appendSlice(allocator, "    },\n");
    try content.appendSlice(allocator, "}\n");

    try writeFile(root_dir, "mufi.lock", content.items);
    std.debug.print("📝 Generated mufi.lock\n", .{});
}

/// Read dependencies from mufi.lock in a specific directory
fn readLockfile(allocator: std.mem.Allocator, dir: fs.Dir) !std.ArrayList(resolver.DependencySpec) {
    var deps = try std.ArrayList(resolver.DependencySpec).initCapacity(allocator, 0);
    errdefer {
        for (deps.items) |*dep| dep.deinit();
        deps.deinit(allocator);
    }

    const lock_bytes = dir.readFileAlloc(allocator, "mufi.lock", 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) return deps;
        return err;
    };
    defer allocator.free(lock_bytes);

    const dep_marker = ".dependencies = .{";
    const deps_start = std.mem.indexOf(u8, lock_bytes, dep_marker) orelse return deps;
    const deps_block_start = deps_start + dep_marker.len;

    var brace_count: i32 = 1;
    var pos: usize = deps_block_start;
    while (pos < lock_bytes.len and brace_count > 0) : (pos += 1) {
        if (lock_bytes[pos] == '{') brace_count += 1 else if (lock_bytes[pos] == '}') brace_count -= 1;
    }
    const deps_block_end = if (pos > 0) pos - 1 else deps_block_start;
    const block = lock_bytes[deps_block_start..deps_block_end];

    const open_seq = "= .{";
    var scan_pos: usize = 0;
    while (scan_pos < block.len) {
        const rel_idx = std.mem.indexOf(u8, block[scan_pos..], open_seq) orelse break;
        const entry_open = scan_pos + rel_idx + open_seq.len;

        var bcount: i32 = 1;
        var p: usize = entry_open;
        while (p < block.len and bcount > 0) : (p += 1) {
            if (block[p] == '{') bcount += 1 else if (block[p] == '}') bcount -= 1;
        }
        const entry_close = p;
        const entry_slice = block[entry_open..entry_close];

        if (extractQuotedField(entry_slice, ".name")) |name_val| {
            var src_val_opt: ?[]const u8 = null;
            if (extractQuotedField(entry_slice, ".src")) |s| src_val_opt = s else if (extractQuotedField(entry_slice, ".url")) |u| src_val_opt = u;

            if (src_val_opt) |src_val| {
                if (extractQuotedField(entry_slice, ".version")) |ver_val| {
                    var type_enum: cache.SourceType = .Git;
                    if (extractEnumField(entry_slice, ".type")) |enum_tok| {
                        if (std.mem.eql(u8, enum_tok, "Local")) type_enum = .Local else if (std.mem.eql(u8, enum_tok, "Git")) type_enum = .Git else if (std.mem.eql(u8, enum_tok, "Http")) type_enum = .Http;
                    }
                    const hash_val = extractQuotedField(entry_slice, ".hash");
                    const spec = try resolver.DependencySpec.initAll(allocator, name_val, src_val, ver_val, type_enum, hash_val);
                    try deps.append(allocator, spec);
                }
            }
        }
        scan_pos = entry_close;
    }

    return deps;
}

/// Sanitize a dependency name for use as a ZON key:
/// Replace '-' with '_' to ensure valid Zig identifier-like keys
fn sanitizeDepName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const buf = try allocator.alloc(u8, name.len);
    var i: usize = 0;
    while (i < name.len) : (i += 1) {
        const c = name[i];
        if (c == '-') {
            buf[i] = '_';
        } else {
            buf[i] = c;
        }
    }
    return buf;
}

/// Add a dependency to mufi.zon
pub fn addDependency(
    allocator: std.mem.Allocator,
    name: []const u8,
    src: []const u8,
    dep_type: []const u8,
    version: []const u8,
) !void {
    std.debug.print("➕ Adding dependency: {s}@{s}\n", .{ name, version });

    // Validate inputs
    if (!resolver.isValidVersion(version)) {
        std.debug.print("Error: Invalid version format: {s}\n", .{version});
        return PMError.InvalidDependencySpec;
    }

    // Sanitize dependency name (replace '-' with '_') for use as ZON key
    const sanitized_name = try sanitizeDepName(allocator, name);
    defer allocator.free(sanitized_name);

    // Read current mufi.zon
    const cwd = fs.cwd();
    const file = try cwd.openFile("mufi.zon", .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const content = try file.readToEndAlloc(arena_allocator, 1024 * 1024);

    // Check if dependencies section exists
    const has_deps = std.mem.indexOf(u8, content, ".dependencies") != null;

    // Generate new content using sanitized name as the ZON key and store the canonical name
    var new_content: []const u8 = undefined;
    if (has_deps) {
        new_content = try addToExistingDeps(allocator, content, sanitized_name, name, src, dep_type, version);
    } else {
        new_content = try addNewDepsSection(allocator, content, sanitized_name, name, src, dep_type, version);
    }
    defer allocator.free(new_content);

    // Write back
    const out_file = try cwd.createFile("mufi.zon", .{});
    defer out_file.close();
    try out_file.writeAll(new_content);

    std.debug.print("✅ Dependency added to mufi.zon\n", .{});
    std.debug.print("   Run 'mufiz pm install' to download it\n", .{});
}

/// Helper to add dependency to existing dependencies section
fn addToExistingDeps(
    allocator: std.mem.Allocator,
    content: []const u8,
    key_name: []const u8,
    canonical_name: []const u8,
    src: []const u8,
    dep_type: []const u8,
    version: []const u8,
) ![]const u8 {
    // Find the dependencies section and add new entry
    // Simple approach: find ".dependencies = .{" and insert before the closing "}"
    const deps_start = std.mem.indexOf(u8, content, ".dependencies = .{") orelse return content;
    const deps_block_start = deps_start + ".dependencies = .{".len;

    // Find the matching closing brace
    var brace_count: i32 = 1;
    var pos = deps_block_start;
    while (pos < content.len and brace_count > 0) : (pos += 1) {
        if (content[pos] == '{') brace_count += 1;
        if (content[pos] == '}') brace_count -= 1;
    }
    const deps_end = pos - 1;

    // Build new dependency entry:
    // We store both the canonical name and the src/type/version. The key in the ZON object
    // uses the sanitized identifier (key_name) but we also store `.name = "canonical"` to
    // preserve the original package name (with hyphens).
    const dep_entry = try std.fmt.allocPrint(
        allocator,
        "\n        .{s} = .{{\n            .name = \"{s}\",\n            .src = \"{s}\",\n            .type = .{s},\n            .version = \"{s}\",\n        }},",
        .{ key_name, canonical_name, src, dep_type, version },
    );
    defer allocator.free(dep_entry);

    // Combine parts
    return try std.fmt.allocPrint(
        allocator,
        "{s}{s}\n    {s}",
        .{ content[0..deps_end], dep_entry, content[deps_end..] },
    );
}

/// Helper to add new dependencies section
fn addNewDepsSection(
    allocator: std.mem.Allocator,
    content: []const u8,
    key_name: []const u8,
    canonical_name: []const u8,
    src: []const u8,
    dep_type: []const u8,
    version: []const u8,
) ![]const u8 {
    // Find the closing brace of the root struct
    const last_brace = std.mem.lastIndexOf(u8, content, "}") orelse return content;

    const deps_section = try std.fmt.allocPrint(
        allocator,
        "    .dependencies = .{{\n        .{s} = .{{\n            .name = \"{s}\",\n            .src = \"{s}\",\n            .type = .{s},\n            .version = \"{s}\",\n        }},\n    }},\n",
        .{ key_name, canonical_name, src, dep_type, version },
    );
    defer allocator.free(deps_section);

    return try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ content[0..last_brace], deps_section, content[last_brace..] },
    );
}

fn extractQuotedField(block: []const u8, field: []const u8) ?[]const u8 {
    // find field name
    const field_pos = std.mem.indexOf(u8, block, field) orelse return null;

    // slice after field
    var i: usize = field_pos + field.len;
    if (i >= block.len) return null;

    // skip whitespace
    while (i < block.len and std.ascii.isWhitespace(block[i])) : (i += 1) {}

    // expect '='
    if (i >= block.len or block[i] != '=') return null;
    i += 1;

    // skip whitespace
    while (i < block.len and std.ascii.isWhitespace(block[i])) : (i += 1) {}

    // expect opening quote
    if (i >= block.len or block[i] != '"') return null;
    i += 1;

    const start = i;

    // find closing quote
    while (i < block.len and block[i] != '"') : (i += 1) {}
    if (i >= block.len) return null;

    return block[start..i];
}

/// Extract an enum literal token for a field (expects `.Token` form)
/// Example supported forms inside the block:
///    .type = .Local,
///    .type = .Git
/// Returns the token (without the leading dot), e.g. "Local" or "Git".
fn extractEnumField(block: []const u8, field: []const u8) ?[]const u8 {
    // find field name
    const field_pos = std.mem.indexOf(u8, block, field) orelse return null;

    // slice after field
    var i: usize = field_pos + field.len;
    if (i >= block.len) return null;

    // skip whitespace
    while (i < block.len and std.ascii.isWhitespace(block[i])) : (i += 1) {}

    // expect '='
    if (i >= block.len or block[i] != '=') return null;
    i += 1;

    // skip whitespace
    while (i < block.len and std.ascii.isWhitespace(block[i])) : (i += 1) {}

    // expect leading dot for enum literal
    if (i >= block.len or block[i] != '.') return null;
    i += 1;

    const start = i;

    // identifier chars: alnum or underscore
    while (i < block.len and (std.ascii.isAlphanumeric(block[i]) or block[i] == '_')) : (i += 1) {}

    if (start == i) return null;

    return block[start..i];
}

/// Read dependencies from mufi.zon in a specific directory
fn readDependencies(allocator: std.mem.Allocator, dir: fs.Dir) !std.ArrayList(resolver.DependencySpec) {
    // Lightweight ad-hoc parser for the .dependencies block in mufi.zon.
    // We intentionally avoid relying on std.zon.parse here to keep parsing simple
    // and to avoid version-specific stdlib API constraints.
    var deps = try std.ArrayList(resolver.DependencySpec).initCapacity(allocator, 0);
    errdefer {
        for (deps.items) |*dep| {
            dep.deinit();
        }
        deps.deinit(allocator);
    }

    const zon_bytes = dir.readFileAlloc(allocator, "mufi.zon", 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            return deps; // Return empty list if no manifest
        }
        return err;
    };
    defer allocator.free(zon_bytes);

    // Debug: show top-level bytes length and a short preview
    // std.debug.print("pm: readDependencies — zon size: {d} bytes\\n", .{zon_bytes.len});

    const dep_marker = ".dependencies = .{";
    if (std.mem.indexOf(u8, zon_bytes, dep_marker) == null) {
        // std.debug.print("pm: no dependencies marker '{s}' found in mufi.zon\\n", .{dep_marker});
        return deps;
    }
    const deps_start = std.mem.indexOf(u8, zon_bytes, dep_marker) orelse return deps;
    const deps_block_start = deps_start + dep_marker.len;

    // Find matching closing brace for the dependencies block
    var brace_count: i32 = 1;
    var pos: usize = deps_block_start;
    while (pos < zon_bytes.len and brace_count > 0) : (pos += 1) {
        if (zon_bytes[pos] == '{') {
            brace_count += 1;
        } else if (zon_bytes[pos] == '}') {
            brace_count -= 1;
        }
    }
    const deps_block_end = if (pos > 0) pos - 1 else deps_block_start;
    const block = zon_bytes[deps_block_start..deps_block_end];

    // Each dependency entry is written like:
    //     .some_key = .{
    //         .name = "mufi-foo",
    //         .url = "https://...",
    //         .version = "v1.0.0",
    //     },
    //
    // We'll scan for the '= .{' sequence which marks an entry start, then find the
    // corresponding closing brace for that entry and extract quoted fields inside it.
    const open_seq = "= .{";
    var scan_pos: usize = 0;
    while (scan_pos < block.len) {
        const rel_idx = std.mem.indexOf(u8, block[scan_pos..], open_seq) orelse break;
        const entry_open = scan_pos + rel_idx + open_seq.len;

        // Find matching brace for this entry
        var bcount: i32 = 1;
        var p: usize = entry_open;
        while (p < block.len and bcount > 0) : (p += 1) {
            if (block[p] == '{') {
                bcount += 1;
            } else if (block[p] == '}') {
                bcount -= 1;
            }
        }
        const entry_close = p;
        if (entry_close <= entry_open) {
            scan_pos = entry_open;
            continue;
        }

        const entry_slice = block[entry_open..entry_close];

        // Extract fields using the helper already present in this file.
        // The helper returns a slice that references the original buffer, which
        // is fine because we duplicate strings into DependencySpec.
        if (extractQuotedField(entry_slice, ".name")) |name_val| {
            // Accept either `.src` (new) or `.url` (legacy) as the source field.
            var src_val_opt: ?[]const u8 = null;
            if (extractQuotedField(entry_slice, ".src")) |s| {
                src_val_opt = s;
            } else if (extractQuotedField(entry_slice, ".url")) |u| {
                src_val_opt = u;
            }

            if (src_val_opt) |src_val| {
                if (extractQuotedField(entry_slice, ".version")) |ver_val| {
                    // optional type field (enum literal only; default to .Git when absent)
                    var type_enum: cache.SourceType = cache.SourceType.Git;
                    if (extractEnumField(entry_slice, ".type")) |enum_tok| {
                        // Accept enum literal tokens .Local, .Git, .Http
                        if (std.mem.eql(u8, enum_tok, "Local")) {
                            type_enum = cache.SourceType.Local;
                        } else if (std.mem.eql(u8, enum_tok, "Git")) {
                            type_enum = cache.SourceType.Git;
                        } else if (std.mem.eql(u8, enum_tok, "Http")) {
                            type_enum = cache.SourceType.Http;
                        } else {
                            // Unknown enum literal: default to .Git but log for visibility
                            // std.debug.print("pm: unknown .type enum literal '{s}', defaulting to .Git\n", .{enum_tok});
                        }
                    }
                    const spec = try resolver.DependencySpec.init(allocator, name_val, src_val, ver_val, type_enum);
                    try deps.append(allocator, spec);
                    // std.debug.print("pm: appended dependency {s} src={s} version={s} type={any}\n", .{ name_val, src_val, ver_val, type_enum });
                }
            }
        }

        // Continue scanning after this entry
        scan_pos = entry_close;
    }

    return deps;
}

/// Show cache statistics
pub fn cacheInfo(allocator: std.mem.Allocator) !void {
    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    const stats = try pkg_cache.getStats(allocator);
    const size_str = try stats.formatSize(allocator);
    defer allocator.free(size_str);

    std.debug.print("\n📊 Package Cache Statistics\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("  Cached Packages: {d}\n", .{stats.package_count});
    std.debug.print("  Total Size: {s}\n", .{size_str});
    std.debug.print("  Cache Location: {s}\n", .{pkg_cache.cache_dir});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

/// Clear the package cache
pub fn cacheClear(allocator: std.mem.Allocator) !void {
    var package_cache = try cache.Cache.init(allocator);
    defer package_cache.deinit();

    try package_cache.clear();
}

/// Generate documentation for the current project
pub fn docs(allocator: std.mem.Allocator) !void {
    // Read project name from mufi.zon
    const cwd = fs.cwd();
    const zon_content = cwd.readFileAlloc(allocator, "mufi.zon", 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("❌ Error: mufi.zon not found\n", .{});
            std.debug.print("   Make sure you're in a MufiZ project directory.\n", .{});
            return PMError.InvalidProjectName;
        }
        return err;
    };
    defer allocator.free(zon_content);

    // Extract project name (simple parsing)
    var project_name: []const u8 = "project";
    if (std.mem.indexOf(u8, zon_content, ".name = .")) |start| {
        const after_name = zon_content[start + 9 ..];
        if (std.mem.indexOf(u8, after_name, ",")) |end| {
            project_name = std.mem.trim(u8, after_name[0..end], " \t\r\n");
        }
    }

    // Generate documentation
    try docgen.generateDocs(allocator, project_name);
}

/// Update project dependencies (ignore lockfile)
pub fn update(allocator: std.mem.Allocator) !void {
    const cwd = fs.cwd();

    if (cwd.access("mufi.zon", .{})) |_| {
        // proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.zon not found)\n", .{});
        return;
    }

    // Delete lockfile if it exists to force re-resolution
    cwd.deleteFile("mufi.lock") catch |err| {
        if (err != error.FileNotFound) return err;
    };

    std.debug.print("🔄 Updating dependencies...\n", .{});
    try install(allocator);
}

/// Print package manager help
pub fn printHelp() void {
    std.debug.print(
        \\MufiZ Package Manager (mufiz pm)
        \\
        \\USAGE:
        \\    mufiz pm <COMMAND> [OPTIONS]
        \\
        \\COMMANDS:
        \\    new <name>           Create a new MufiZ project in a new directory
        \\    init <name>          Initialize a MufiZ project in the current directory
        \\    info                 Display information about the current project
        \\    run                  Run the current project (execute src/main.mufi)
        \\    install              Install project dependencies
        \\    update               Update dependencies and refresh mufi.lock
        \\    add <name> <url> <v> Add a dependency to mufi.zon
        \\    docs                 Generate HTML documentation for the project
        \\    cache info           Show package cache statistics
        \\    cache clear          Clear the package cache
        \\    help                 Display this help message
        \\
        \\EXAMPLES:
        \\    mufiz pm new my-project        Create a new project called 'my-project'
        \\    mufiz pm init my-app           Initialize current directory as 'my-app'
        \\    mufiz pm info                  Show current project information
        \\    mufiz pm run                   Run the current project
        \\    mufiz pm install               Install all dependencies
        \\    mufiz pm update                Refresh all dependencies
        \\    mufiz pm add http https://github.com/user/mufiz-http v1.0.0
        \\                                   Add a dependency
        \\    mufiz pm docs                  Generate documentation
        \\    mufiz pm cache info            View cache statistics
        \\    mufiz pm cache clear           Clear downloaded packages
        \\
        \\PROJECT STRUCTURE:
        \\    my-project/
        \\    ├── mufi.zon       Project metadata and configuration (ZON format)
        \\    ├── mufi.lock      Resolved dependencies (Auto-generated)
        \\    └── src/
        \\        └── main.mufi  Entry point of the application
        \\
        \\DEPENDENCIES:
        \\    Dependencies are specified in mufi.zon:
        \\    .dependencies = .{{
        \\        .http = .{{
        \\            .url = "https://github.com/user/mufiz-http",
        \\            .version = "v1.0.0",
        \\        }},
        \\    }}
        \\
        \\ABOUT ZON FORMAT:
        \\    ZON (Zig Object Notation) is a simple, readable format similar to JSON
        \\    but with Zig syntax. It's the native format used by the Zig build system.
        \\
        \\For more information, visit: https://github.com/mufiz-lang/mufiz
        \\
    , .{});
}
