/// MufiZ Package Manager
/// Handles project creation, initialization, and management
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const cache = @import("cache.zig");
const resolver = @import("resolver.zig");

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

    // Check if src/main.mufi exists
    if (cwd.access("src/main.mufi", .{})) |_| {
        // src/main.mufi exists, proceed
    } else |_| {
        std.debug.print("Error: Entry point not found (src/main.mufi)\n", .{});
        return;
    }

    std.debug.print("🚀 Running MufiZ project...\n\n", .{});

    // Import the runner from lib.zig
    const mufiz = @import("lib.zig");
    var runner = mufiz.Runner.init(allocator);
    defer runner.deinit();

    try runner.setMain(@constCast("src/main.mufi"));
    try runner.runFile();
}

/// Install project dependencies
pub fn install(allocator: std.mem.Allocator) !void {
    const cwd = fs.cwd();

    // Check if mufi.zon exists
    if (cwd.access("mufi.zon", .{})) |_| {
        // mufi.zon exists, proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.zon not found)\n", .{});
        return;
    }

    std.debug.print("📦 Installing dependencies...\n\n", .{});

    // Initialize cache
    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    // Read and parse mufi.zon
    var deps = try readDependencies(allocator);
    defer {
        for (deps.items) |*dep| {
            dep.deinit();
        }
        deps.deinit(allocator);
    }

    if (deps.items.len == 0) {
        std.debug.print("✅ No dependencies to install\n", .{});
        return;
    }

    // Initialize resolver
    var dep_resolver = try resolver.Resolver.init(allocator);
    defer dep_resolver.deinit();

    // Add all dependencies to resolver
    for (deps.items) |dep| {
        try dep_resolver.addDependency(dep);
    }

    // Validate and resolve
    try dep_resolver.validate();
    var resolved = try dep_resolver.resolve();
    defer {
        for (resolved.items) |*item| {
            item.deinit();
        }
        resolved.deinit(allocator);
    }

    std.debug.print("📊 Resolved {d} dependencies\n\n", .{resolved.items.len});

    // Install each dependency
    for (resolved.items) |dep| {
        const cached_pkg = try pkg_cache.cachePackage(dep.name, dep.url, dep.version);
        defer {
            var mut_pkg = cached_pkg;
            mut_pkg.deinit();
        }
    }

    std.debug.print("\n✅ All dependencies installed successfully!\n", .{});
}

/// Add a dependency to mufi.zon
pub fn addDependency(
    allocator: std.mem.Allocator,
    name: []const u8,
    url: []const u8,
    version: []const u8,
) !void {
    std.debug.print("➕ Adding dependency: {s}@{s}\n", .{ name, version });

    // Validate inputs
    if (!resolver.isValidVersion(version)) {
        std.debug.print("Error: Invalid version format: {s}\n", .{version});
        return PMError.InvalidDependencySpec;
    }

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

    // Generate new content
    const new_content = if (has_deps)
        try addToExistingDeps(allocator, content, name, url, version)
    else
        try addNewDepsSection(allocator, content, name, url, version);
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
    name: []const u8,
    url: []const u8,
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

    // Build new dependency entry
    const dep_entry = try std.fmt.allocPrint(
        allocator,
        "\n        .{s} = .{{\n            .url = \"{s}\",\n            .version = \"{s}\",\n        }},",
        .{ name, url, version },
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
    name: []const u8,
    url: []const u8,
    version: []const u8,
) ![]const u8 {
    // Find the closing brace of the root struct
    const last_brace = std.mem.lastIndexOf(u8, content, "}") orelse return content;

    const deps_section = try std.fmt.allocPrint(
        allocator,
        "    .dependencies = .{{\n        .{s} = .{{\n            .url = \"{s}\",\n            .version = \"{s}\",\n        }},\n    }},\n",
        .{ name, url, version },
    );
    defer allocator.free(deps_section);

    return try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ content[0..last_brace], deps_section, content[last_brace..] },
    );
}

/// Read dependencies from mufi.zon
fn readDependencies(allocator: std.mem.Allocator) !std.ArrayList(resolver.DependencySpec) {
    var deps = try std.ArrayList(resolver.DependencySpec).initCapacity(allocator, 0);
    errdefer {
        for (deps.items) |*dep| {
            dep.deinit();
        }
        deps.deinit(allocator);
    }

    // For now, return empty list - full ZON parsing would use std.zon.parse
    // TODO: Implement full ZON parsing for dependencies
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

/// Clear package cache
pub fn cacheClear(allocator: std.mem.Allocator) !void {
    var pkg_cache = try cache.Cache.init(allocator);
    defer pkg_cache.deinit();

    try pkg_cache.clear();
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
        \\    install              Install project dependencies from mufi.zon
        \\    add <name> <url> <v> Add a dependency to mufi.zon
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
        \\    mufiz pm add http https://github.com/user/mufiz-http v1.0.0
        \\                                   Add a dependency
        \\    mufiz pm cache info            View cache statistics
        \\    mufiz pm cache clear           Clear downloaded packages
        \\
        \\PROJECT STRUCTURE:
        \\    my-project/
        \\    ├── mufi.zon       Project metadata and configuration (ZON format)
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
