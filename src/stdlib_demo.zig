const std = @import("std");
const stdlib_enhanced = @import("stdlib_enhanced.zig");
const stdlib_v2_main = @import("stdlib_v2_main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "demo")) {
        try runDemo();
    } else if (std.mem.eql(u8, command, "help")) {
        const subcmd = if (args.len > 2) args[2] else null;
        stdlib_enhanced.help(subcmd);
    } else if (std.mem.eql(u8, command, "v1")) {
        stdlib_enhanced.setVersion(.v1_legacy);
        try runVersion("V1 Legacy");
    } else if (std.mem.eql(u8, command, "v2")) {
        stdlib_enhanced.setVersion(.v2_new);
        try runVersion("V2 New");
    } else if (std.mem.eql(u8, command, "hybrid")) {
        stdlib_enhanced.setVersion(.hybrid);
        try runVersion("Hybrid");
    } else if (std.mem.eql(u8, command, "compare")) {
        try runComparison();
    } else if (std.mem.eql(u8, command, "migrate")) {
        try runMigrationDemo();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print("\n=== MufiZ Standard Library Demo ===\n");
    std.debug.print("Usage: stdlib_demo <command> [args]\n\n");
    std.debug.print("Commands:\n");
    std.debug.print("  demo           - Run interactive demo\n");
    std.debug.print("  help [cmd]     - Show help system\n");
    std.debug.print("  v1             - Demo V1 legacy system\n");
    std.debug.print("  v2             - Demo V2 new system\n");
    std.debug.print("  hybrid         - Demo hybrid mode\n");
    std.debug.print("  compare        - Compare V1 vs V2\n");
    std.debug.print("  migrate        - Show migration demo\n");
}

fn runDemo() !void {
    std.debug.print("\n🚀 Welcome to MufiZ Standard Library Demo!\n");
    std.debug.print("=========================================\n");

    // Demo different versions
    std.debug.print("\n1. Legacy V1 System:\n");
    stdlib_enhanced.setVersion(.v1_legacy);
    stdlib_enhanced.prelude();
    stdlib_enhanced.addMath();
    std.debug.print("   ✓ Initialized {} functions\n", .{stdlib_enhanced.getTotalFunctionCount()});

    std.debug.print("\n2. New V2 System:\n");
    stdlib_enhanced.setVersion(.v2_new);
    try stdlib_v2_main.initializeStdlib();
    stdlib_v2_main.registerWithVM();
    std.debug.print("   ✓ Initialized {} functions\n", .{stdlib_v2_main.getTotalFunctionCount()});

    std.debug.print("\n3. Hybrid Mode:\n");
    stdlib_enhanced.setVersion(.hybrid);
    stdlib_enhanced.prelude();
    stdlib_enhanced.addMath();
    stdlib_enhanced.addCollections();
    std.debug.print("   ✓ Initialized both systems\n");

    // Demo documentation system
    std.debug.print("\n📚 Documentation Demo:\n");
    std.debug.print("======================\n");

    // Show V2 math module docs
    stdlib_enhanced.setVersion(.v2_new);
    stdlib_enhanced.help("math");

    // Demo stats
    std.debug.print("\n📊 Statistics:\n");
    stdlib_enhanced.help("stats");
}

fn runVersion(version_name: []const u8) !void {
    std.debug.print("\n=== {} Demo ===\n", .{version_name});

    switch (stdlib_enhanced.getVersion()) {
        .v1_legacy => {
            stdlib_enhanced.prelude();
            stdlib_enhanced.addMath();
            stdlib_enhanced.addCollections();
            stdlib_enhanced.addTime();
            stdlib_enhanced.addUtils();
            std.debug.print("Initialized V1 system with {} functions\n", .{stdlib_enhanced.getTotalFunctionCount()});
        },
        .v2_new => {
            try stdlib_v2_main.initializeStdlib();
            stdlib_v2_main.registerWithVM();
            std.debug.print("Initialized V2 system with {} functions\n", .{stdlib_v2_main.getTotalFunctionCount()});
        },
        .hybrid => {
            // Initialize both systems
            stdlib_enhanced.prelude();
            stdlib_enhanced.addMath();
            stdlib_enhanced.addCollections();
            try stdlib_v2_main.initializeStdlib();
            std.debug.print("Initialized hybrid system\n");
        },
    }

    // Show documentation
    stdlib_enhanced.printDocs();
}

fn runComparison() !void {
    std.debug.print("\n📊 V1 vs V2 Comparison\n");
    std.debug.print("========================\n");

    // V1 Stats
    stdlib_enhanced.setVersion(.v1_legacy);
    stdlib_enhanced.prelude();
    stdlib_enhanced.addMath();
    stdlib_enhanced.addCollections();
    stdlib_enhanced.addTime();
    stdlib_enhanced.addUtils();
    const v1_count = stdlib_enhanced.getTotalFunctionCount();

    // V2 Stats
    stdlib_enhanced.setVersion(.v2_new);
    try stdlib_v2_main.initializeStdlib();
    const v2_count = stdlib_v2_main.getTotalFunctionCount();
    const v2_stats = stdlib_v2_main.getStats();

    std.debug.print("\n📈 Function Counts:\n");
    std.debug.print("V1 Legacy: {} functions\n", .{v1_count});
    std.debug.print("V2 New:    {} functions\n", .{v2_count});

    std.debug.print("\n📋 Feature Comparison:\n");
    std.debug.print("┌─────────────────────────┬───────┬───────┐\n");
    std.debug.print("│ Feature                 │  V1   │  V2   │\n");
    std.debug.print("├─────────────────────────┼───────┼───────┤\n");
    std.debug.print("│ Parameter Validation    │  ❌   │  ✅   │\n");
    std.debug.print("│ Type-Safe Parameters    │  ❌   │  ✅   │\n");
    std.debug.print("│ Rich Error Messages     │  ❌   │  ✅   │\n");
    std.debug.print("│ Auto Documentation     │  ❌   │  ✅   │\n");
    std.debug.print("│ Function Examples       │  ❌   │  ✅   │\n");
    std.debug.print("│ Auto Registration      │  ❌   │  ✅   │\n");
    std.debug.print("│ Parameter Names in Errors│  ❌   │  ✅   │\n");
    std.debug.print("│ Optional Parameters     │  ❌   │  ✅   │\n");
    std.debug.print("│ Module Statistics       │  ❌   │  ✅   │\n");
    std.debug.print("│ Consistent API          │  ❌   │  ✅   │\n");
    std.debug.print("└─────────────────────────┴───────┴───────┘\n");

    std.debug.print("\n🏆 V2 Advantages:\n");
    std.debug.print("• ~70% less boilerplate code per function\n");
    std.debug.print("• Automatic parameter validation with clear errors\n");
    std.debug.print("• Built-in documentation with examples\n");
    std.debug.print("• Type-safe parameter specifications\n");
    std.debug.print("• Consistent error message formatting\n");
    std.debug.print("• Easier to add new functions and modules\n");
    std.debug.print("• Better developer experience\n");

    // Show side-by-side example
    std.debug.print("\n📝 Code Comparison Example (sqrt function):\n");
    std.debug.print("\nV1 Legacy:\n");
    std.debug.print("```zig\n");
    std.debug.print("pub fn sqrt(argc: i32, args: [*]Value) Value {{\n");
    std.debug.print("    if (argc != 1) return stdlib_error(\"sqrt() expects one argument!\", .{{ .argn = argc }});\n");
    std.debug.print("    if (!type_check(1, args, 6)) return stdlib_error(\"sqrt() expects a Number!\", .{{ .value_type = conv.what_is(args[0]) }});\n");
    std.debug.print("    const double = args[0].as_num_double();\n");
    std.debug.print("    return Value.init_double(@sqrt(double));\n");
    std.debug.print("}}\n");
    std.debug.print("```\n");

    std.debug.print("\nV2 New:\n");
    std.debug.print("```zig\n");
    std.debug.print("fn sqrt_impl(argc: i32, args: [*]Value) Value {{\n");
    std.debug.print("    const double = args[0].as_num_double();\n");
    std.debug.print("    return Value.init_double(@sqrt(double));\n");
    std.debug.print("}}\n\n");
    std.debug.print("pub const sqrt = DefineFunction(\n");
    std.debug.print("    \"sqrt\", \"math\", \"Square root function\",\n");
    std.debug.print("    OneNumber, .double,\n");
    std.debug.print("    &[_][]const u8{{\"sqrt(16) -> 4.0\"}},\n");
    std.debug.print("    sqrt_impl,\n");
    std.debug.print(");\n");
    std.debug.print("```\n");

    std.debug.print("\n✨ Benefits:\n");
    std.debug.print("• Implementation focuses on logic, not validation\n");
    std.debug.print("• Rich metadata includes examples and parameter info\n");
    std.debug.print("• Automatic registration and documentation generation\n");
    std.debug.print("• Better error messages: 'sqrt() parameter \"value\" expects Number, got String'\n");
}

fn runMigrationDemo() !void {
    std.debug.print("\n🔄 Migration Demo\n");
    std.debug.print("=================\n");

    std.debug.print("This demo shows the migration process from V1 to V2:\n\n");

    std.debug.print("1️⃣  Start with V1 Legacy System\n");
    stdlib_enhanced.setVersion(.v1_legacy);
    stdlib_enhanced.prelude();
    stdlib_enhanced.addMath();
    std.debug.print("   ✓ V1 system initialized ({} functions)\n", .{stdlib_enhanced.getTotalFunctionCount()});

    std.debug.print("\n2️⃣  Switch to Hybrid Mode (both V1 and V2)\n");
    stdlib_enhanced.setVersion(.hybrid);
    try stdlib_v2_main.initializeStdlib();
    std.debug.print("   ✓ Hybrid mode active - both systems available\n");
    std.debug.print("   ✓ Test your code with both systems running\n");

    std.debug.print("\n3️⃣  Migrate to V2 Only\n");
    stdlib_enhanced.setVersion(.v2_new);
    std.debug.print("   ✓ V2 system only ({} functions)\n", .{stdlib_v2_main.getTotalFunctionCount()});
    std.debug.print("   ✓ Better error messages and documentation\n");

    std.debug.print("\n📚 Migration Status:\n");
    const v2_stats = stdlib_v2_main.getStats();
    std.debug.print("   Migrated Modules:\n");
    std.debug.print("     ✅ Core ({} functions)\n", .{v2_stats.core_functions});
    std.debug.print("     ✅ Math ({} functions)\n", .{v2_stats.math_functions});
    std.debug.print("     ✅ I/O ({} functions)\n", .{v2_stats.io_functions});
    std.debug.print("     ✅ Types ({} functions)\n", .{v2_stats.types_functions});
    std.debug.print("     ✅ Time ({} functions)\n", .{v2_stats.time_functions});
    std.debug.print("     ✅ Utils ({} functions)\n", .{v2_stats.utils_functions});
    std.debug.print("     ✅ Collections ({} functions)\n", .{v2_stats.collections_functions});

    std.debug.print("\n   Pending Migration:\n");
    std.debug.print("     🔄 Filesystem (2 functions)\n");
    std.debug.print("     🔄 Network (6 functions)\n");
    std.debug.print("     🔄 Matrix (20 functions)\n");

    std.debug.print("\n📖 Documentation Improvements:\n");
    stdlib_enhanced.setVersion(.v2_new);
    std.debug.print("   Example: 'help math' now shows:\n");
    stdlib_enhanced.help("sin");

    std.debug.print("\n🎯 Next Steps:\n");
    std.debug.print("   1. Review migration guide: src/stdlib_v2/MIGRATION_GUIDE.md\n");
    std.debug.print("   2. Start with hybrid mode for testing\n");
    std.debug.print("   3. Migrate remaining modules (fs, network, matrix)\n");
    std.debug.print("   4. Switch to V2 only when ready\n");

    std.debug.print("\n💡 Pro Tips:\n");
    std.debug.print("   • Use 'help stats' to see function counts\n");
    std.debug.print("   • Use 'help <module>' for detailed docs\n");
    std.debug.print("   • V2 error messages include parameter names\n");
    std.debug.print("   • All V2 functions have examples in help\n");
}

// Example of how error messages improved
fn demonstrateErrorMessages() void {
    std.debug.print("\n🚨 Error Message Improvements:\n");
    std.debug.print("================================\n");

    std.debug.print("V1 Legacy Error Messages:\n");
    std.debug.print("  ❌ sin() expects one argument! (argc = 2)\n");
    std.debug.print("  ❌ sin() expects a Number! (value_type = \"String\")\n");
    std.debug.print("  ❌ pow() expects 2 Number! (magic number 6)\n");

    std.debug.print("\nV2 New Error Messages:\n");
    std.debug.print("  ✅ sin() expects 1-1 arguments, got 2\n");
    std.debug.print("  ✅ sin() parameter 'value' expects Number, got String\n");
    std.debug.print("  ✅ pow() parameter 'base' expects Number, got Boolean\n");
    std.debug.print("  ✅ clamp() missing required parameter: value\n");
    std.debug.print("  ✅ format() parameter 'template' expects String, got Int\n");

    std.debug.print("\n💬 Benefits:\n");
    std.debug.print("  • Parameter names in error messages\n");
    std.debug.print("  • Clear expected vs actual types\n");
    std.debug.print("  • Consistent error formatting\n");
    std.debug.print("  • Better debugging experience\n");
}
