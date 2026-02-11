/// MufiZ Package Manager
/// Handles project creation, initialization, and management
const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub const PMError = error{
    ProjectAlreadyExists,
    InvalidProjectName,
    FileSystemError,
    TomlWriteError,
    DirectoryCreationError,
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

    // Check if mufi.toml already exists
    const cwd = fs.cwd();
    if (cwd.access("mufi.toml", .{})) |_| {
        std.debug.print("Error: Project already initialized (mufi.toml exists)\n", .{});
        return PMError.ProjectAlreadyExists;
    } else |_| {
        // File doesn't exist, we can proceed
    }

    std.debug.print("📦 Initializing MufiZ project: {s}\n", .{project_name});

    // Create project structure
    try createProjectStructure(allocator, cwd, project_name);

    std.debug.print("✅ Project '{s}' initialized successfully!\n", .{project_name});
    std.debug.print("\nProject structure:\n", .{});
    std.debug.print("  mufi.toml       - Project metadata\n", .{});
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
    std.debug.print("  ├── mufi.toml\n", .{});
    std.debug.print("  └── src/\n", .{});
    std.debug.print("      └── main.mufi\n", .{});
    std.debug.print("\nNext steps:\n", .{});
    std.debug.print("  1. cd {s}\n", .{project_name});
    std.debug.print("  2. Edit src/main.mufi to write your code\n", .{});
    std.debug.print("  3. Run your project with: mufiz -r src/main.mufi\n", .{});
}

/// Create the project structure (mufi.toml and src/main.mufi)
fn createProjectStructure(allocator: std.mem.Allocator, dir: fs.Dir, project_name: []const u8) !void {
    _ = allocator;

    // Create mufi.toml with formatted content
    var toml_buf: [2048]u8 = undefined;
    const toml_content = try std.fmt.bufPrint(&toml_buf,
        \\[package]
        \\name = "{s}"
        \\version = "0.1.0"
        \\authors = []
        \\description = "A MufiZ project"
        \\license = "MIT"
        \\
        \\[project]
        \\entry_point = "src/main.mufi"
        \\
        \\# Dependencies will be supported in future versions
        \\# [dependencies]
        \\
    , .{project_name});
    try writeFile(dir, "mufi.toml", toml_content);

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

/// Generate the content for mufi.toml
fn generateTomlContent(project_name: []const u8) []const u8 {
    _ = project_name;
    return 
    \\[package]
    \\name = "myproject"
    \\version = "0.1.0"
    \\authors = []
    \\description = "A MufiZ project"
    \\license = "MIT"
    \\
    \\[project]
    \\entry_point = "src/main.mufi"
    \\
    \\# Dependencies will be supported in future versions
    \\# [dependencies]
    \\
    ;
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

    // Check if mufi.toml exists
    if (cwd.access("mufi.toml", .{})) |_| {
        // mufi.toml exists, proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.toml not found)\n", .{});
        std.debug.print("Run 'mufiz pm init <project_name>' to initialize a project\n", .{});
        return;
    }

    // Read mufi.toml
    const file = try cwd.openFile("mufi.toml", .{});
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

    // Check if mufi.toml exists
    if (cwd.access("mufi.toml", .{})) |_| {
        // mufi.toml exists, proceed
    } else |_| {
        std.debug.print("Error: Not a MufiZ project (mufi.toml not found)\n", .{});
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

/// Print package manager help
pub fn printHelp() void {
    std.debug.print(
        \\MufiZ Package Manager (mufiz pm)
        \\
        \\USAGE:
        \\    mufiz pm <COMMAND> [OPTIONS]
        \\
        \\COMMANDS:
        \\    new <name>     Create a new MufiZ project in a new directory
        \\    init <name>    Initialize a MufiZ project in the current directory
        \\    info           Display information about the current project
        \\    run            Run the current project (execute src/main.mufi)
        \\    help           Display this help message
        \\
        \\EXAMPLES:
        \\    mufiz pm new my-project        Create a new project called 'my-project'
        \\    mufiz pm init my-app           Initialize current directory as 'my-app'
        \\    mufiz pm info                  Show current project information
        \\    mufiz pm run                   Run the current project
        \\
        \\PROJECT STRUCTURE:
        \\    my-project/
        \\    ├── mufi.toml      Project metadata and configuration
        \\    └── src/
        \\        └── main.mufi  Entry point of the application
        \\
        \\For more information, visit: https://github.com/mufiz-lang/mufiz
        \\
    , .{});
}
