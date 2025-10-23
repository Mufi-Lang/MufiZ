const std = @import("std");

const conv = @import("../conv.zig");
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const object_h = @import("../object.zig");
const ObjClass = object_h.ObjClass;
const ObjInstance = object_h.ObjInstance;
const ObjString = object_h.ObjString;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const table_h = @import("../table.zig");
const Value = @import("../value.zig").Value;
const vm_h = @import("../vm.zig");

// Cache for imported modules to avoid re-importing
var module_cache: ?std.StringHashMap(*ObjInstance) = null;
var module_cache_initialized: bool = false;

fn ensureModuleCacheInitialized() void {
    if (!module_cache_initialized) {
        module_cache = std.StringHashMap(*ObjInstance).init(GlobalAlloc);
        module_cache_initialized = true;
    }
}

/// Import a MufiZ module file and return it as an object
/// Usage: const foo = import("foo.mufiz");
/// Then can call: foo.add(2, 3);
pub fn import(argc: i32, args: [*]Value) Value {
    if (argc != 1) {
        return stdlib_error("import() expects exactly 1 argument (file path)", .{ .argn = argc });
    }

    const arg = args[0];
    if (!arg.is_obj_type(.OBJ_STRING)) {
        return stdlib_error("import() argument must be a string", .{});
    }

    const filename = arg.as_string();
    const filename_slice = filename.chars[0..@intCast(filename.length)];

    // Initialize module cache if needed
    ensureModuleCacheInitialized();

    // Check if module is already cached
    if (module_cache.?.get(filename_slice)) |cached_module| {
        return Value.init_obj(@ptrCast(cached_module));
    }

    // Read the file
    const file_contents = std.fs.cwd().readFileAlloc(GlobalAlloc, filename_slice, 1024 * 1024) catch |err| {
        std.debug.print("Error reading file '{s}': {any}\n", .{ filename_slice, err });
        return Value.init_nil();
    };
    defer GlobalAlloc.free(file_contents);

    // Save current VM global table state
    const saved_globals = vm_h.vm.globals;
    
    // Create a new globals table for the module
    var module_globals: table_h.Table = undefined;
    table_h.initTable(&module_globals);
    vm_h.vm.globals = module_globals;

    // Execute the module code
    const result = vm_h.interpret(conv.cstr(file_contents));
    
    // Restore the original globals
    const imported_globals = vm_h.vm.globals;
    vm_h.vm.globals = saved_globals;

    if (result != .INTERPRET_OK) {
        table_h.freeTable(&imported_globals);
        std.debug.print("Error importing module '{s}'\n", .{filename_slice});
        return Value.init_nil();
    }

    // Create a class to hold the module's exports
    const module_name_str = object_h.copyString(filename_slice.ptr, filename_slice.len);
    const module_class = ObjClass.init(module_name_str);
    
    // Create an instance of the module class
    const module_instance = ObjInstance.init(module_class);

    // Copy all globals from the module into the instance fields
    if (imported_globals.entries) |entries| {
        var i: usize = 0;
        while (i < imported_globals.capacity) : (i += 1) {
            if (entries[i].key != null and entries[i].isActive()) {
                _ = table_h.tableSet(&module_instance.fields, entries[i].key.?, entries[i].value);
            }
        }
    }

    // Clean up the temporary module globals table
    table_h.freeTable(&imported_globals);

    // Cache the module for future imports
    const cached_filename = GlobalAlloc.dupe(u8, filename_slice) catch filename_slice;
    module_cache.?.put(cached_filename, module_instance) catch {};

    return Value.init_obj(@ptrCast(module_instance));
}

/// Clear the module cache (useful for development/testing)
pub fn clearModuleCache() void {
    if (module_cache_initialized and module_cache != null) {
        module_cache.?.clearAndFree();
    }
}
