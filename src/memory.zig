const std = @import("std");
const print = std.debug.print;
const exit = std.process.exit;

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const mem_utils = @import("mem_utils.zig");
const realloc = mem_utils.realloc;
const free = mem_utils.free;
const obj_h = @import("object.zig");
const Obj = obj_h.Obj;
const Node = obj_h.Node;
const ObjHashTable = obj_h.ObjHashTable;
const ObjMatrix = obj_h.ObjMatrix;
const fvec = @import("objects/fvec.zig");
const __obj = @import("objects/obj.zig");
const table_h = @import("table.zig");
const markTable = table_h.markTable;
const freeTable = table_h.freeTable;
const value_h = @import("value.zig");
const Value = value_h.Value;
const vm_h = @import("vm.zig");

pub const GC_HEAP_GROW_FACTOR = 2;

// Memory pool for frequent allocations
pub const MemoryPool = struct {
    const POOL_SIZE = 1024;
    const CHUNK_SIZE = 64; // Size for small objects like Values
    
    chunks: [POOL_SIZE][CHUNK_SIZE]u8 = undefined,
    free_chunks: [POOL_SIZE]bool = [_]bool{true} ** POOL_SIZE,
    next_free: usize = 0,
    
    pub fn alloc(self: *MemoryPool, size: usize) ?*anyopaque {
        if (size > CHUNK_SIZE) return null; // Use regular allocator for large objects
        
        // Find a free chunk
        for (0..POOL_SIZE) |i| {
            const idx = (self.next_free + i) % POOL_SIZE;
            if (self.free_chunks[idx]) {
                self.free_chunks[idx] = false;
                self.next_free = (idx + 1) % POOL_SIZE;
                return @ptrCast(&self.chunks[idx]);
            }
        }
        return null; // Pool exhausted, use regular allocator
    }
    
    pub fn free(self: *MemoryPool, ptr: *anyopaque) bool {
        const ptr_addr = @intFromPtr(ptr);
        const pool_start = @intFromPtr(&self.chunks[0]);
        const pool_end = pool_start + (POOL_SIZE * CHUNK_SIZE);
        
        if (ptr_addr >= pool_start and ptr_addr < pool_end) {
            const offset = ptr_addr - pool_start;
            const chunk_idx = offset / CHUNK_SIZE;
            if (chunk_idx < POOL_SIZE) {
                self.free_chunks[chunk_idx] = true;
                return true;
            }
        }
        return false; // Not from this pool
    }
};

// Global memory pool instance
var memory_pool: MemoryPool = .{};

// Performance monitoring for memory allocation patterns
pub const AllocStats = struct {
    total_allocs: u64 = 0,
    pool_allocs: u64 = 0,
    system_allocs: u64 = 0,
    pool_hits: u64 = 0,
    
    pub fn recordPoolAlloc(self: *AllocStats) void {
        self.total_allocs += 1;
        self.pool_allocs += 1;
        self.pool_hits += 1;
    }
    
    pub fn recordSystemAlloc(self: *AllocStats) void {
        self.total_allocs += 1;
        self.system_allocs += 1;
    }
    
    pub fn recordPoolMiss(self: *AllocStats) void {
        self.total_allocs += 1;
        self.system_allocs += 1;
    }
    
    pub fn getPoolHitRate(self: *const AllocStats) f64 {
        if (self.total_allocs == 0) return 0.0;
        return @as(f64, @floatFromInt(self.pool_hits)) / @as(f64, @floatFromInt(self.total_allocs));
    }
};

var alloc_stats: AllocStats = .{};

pub fn resetMemoryPool() void {
    memory_pool = .{};
    alloc_stats = .{};
}

pub fn getAllocStats() *const AllocStats {
    return &alloc_stats;
}

pub fn printAllocStats() void {
    if (debug_opts.log_gc) {
        const stats = &alloc_stats;
        print("=== Memory Allocation Statistics ===\n", .{});
        print("Total allocations: {d}\n", .{stats.total_allocs});
        print("Pool allocations: {d}\n", .{stats.pool_allocs});
        print("System allocations: {d}\n", .{stats.system_allocs});
        print("Pool hit rate: {d:.2}%\n", .{stats.getPoolHitRate() * 100.0});
        print("=====================================\n", .{});
    }
}

pub const GCState = enum(i32) {
    GC_IDLE = 0,
    GC_MARK_ROOTS = 1,
    GC_TRACING = 2,
    GC_SWEEPING = 3,
};

pub const GCData = struct {
    state: GCState = .GC_IDLE,
    rootIndex: usize = 0,
    sweepingObject: ?*Obj = null,

    // Generational GC data
    youngGen: ObjectList = .{},
    middleGen: ObjectList = .{},
    oldGen: ObjectList = .{},

    // Cycle detection
    cycleRoots: ObjectList = .{},

    // Collection counters
    youngCollections: u32 = 0,
    middleCollections: u32 = 0,
    oldCollections: u32 = 0,
};

pub const ObjectList = struct {
    head: ?*Obj = null,
    count: usize = 0,

    pub fn add(self: *ObjectList, obj: *Obj) void {
        obj.next = self.head;
        self.head = obj;
        self.count += 1;
    }

    pub fn remove(self: *ObjectList, obj: *Obj) void {
        if (self.head == obj) {
            self.head = obj.next;
            self.count -= 1;
            return;
        }

        var current = self.head;
        while (current) |curr| {
            if (curr.next == obj) {
                curr.next = obj.next;
                self.count -= 1;
                return;
            }
            current = curr.next;
        }
    }
};

pub var gcData: GCData = .{};
// Debug functions for monitoring GC activity
pub fn printGCStats() void {
    if (debug_opts.log_gc) {
        print("=== GC Statistics ===\n", .{});
        print("Young generation: {d} objects\n", .{gcData.youngGen.count});
        print("Middle generation: {d} objects\n", .{gcData.middleGen.count});
        print("Old generation: {d} objects\n", .{gcData.oldGen.count});
        print("Cycle roots: {d} objects\n", .{gcData.cycleRoots.count});
        print("Young collections: {d}\n", .{gcData.youngCollections});
        print("Middle collections: {d}\n", .{gcData.middleCollections});
        print("Old collections: {d}\n", .{gcData.oldCollections});
        print("Bytes allocated: {d}\n", .{vm_h.vm.bytesAllocated});
        print("Next GC threshold: {d}\n", .{vm_h.vm.nextGC});
        print("====================\n", .{});
    }
}

pub fn debugObjectGeneration(obj: *Obj, action: []const u8) void {
    if (debug_opts.log_gc) {
        print("[{s}] Object {p} - Gen: {any}, Age: {d}, RefCount: {d}\n", .{ action, @as(*anyopaque, @ptrCast(obj)), obj.generation, obj.age, obj.refCount });
    }
}

//todo: fix collect garbage debugging
pub fn reallocate(pointer: ?*anyopaque, oldSize: usize, newSize: usize) ?*anyopaque {
    if (newSize > oldSize) {
        if (debug_opts.stress_gc) collectGarbage();

        // Check for overflow
        if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) - (newSize - oldSize)) {
            std.debug.print("Memory allocation would cause overflow.\n", .{});
            std.process.exit(1);
        }

        vm_h.vm.bytesAllocated += newSize - oldSize;
    } else if (oldSize > newSize) {
        vm_h.vm.bytesAllocated -= oldSize - newSize;
    }

    if (vm_h.vm.bytesAllocated > vm_h.vm.nextGC) {
        collectGarbage();
    }

    if (newSize == 0) {
        if (pointer != null) {
            // Try to free from memory pool first
            if (!memory_pool.free(pointer.?)) {
                free(pointer);
            }
        }
        return null;
    }

    // For small allocations, try to use memory pool first
    if (pointer == null and newSize <= 64) {
        if (memory_pool.alloc(newSize)) |pooled| {
            alloc_stats.recordPoolAlloc();
            return pooled;
        } else {
            alloc_stats.recordPoolMiss();
        }
    }

    var result = realloc(pointer, newSize);
    if (result == null and newSize > 0) {
        std.debug.print("Memory allocation failed. Attempted to allocate {} bytes.\n", .{newSize});
        collectGarbage();
        result = realloc(pointer, newSize);
        if (result == null) {
            std.debug.print("Critical error: Memory allocation failed after garbage collection attempt.\n", .{});
            std.process.exit(1);
        }
    }
    
    if (result != null) {
        alloc_stats.recordSystemAlloc();
    }

    return result;
}

// Reference counting operations
pub fn incRef(object: ?*Obj) void {
    if (object == null) return;
    const obj = object.?;
    obj.refCount += 1;

    if (debug_opts.log_gc) {
        print("{p} inc ref to {d}\n", .{ @as(*anyopaque, @ptrCast(obj)), obj.refCount });
    }
}

pub fn decRef(object: ?*Obj) void {
    if (object == null) return;
    const obj = object.?;

    if (obj.refCount == 0) return;
    obj.refCount -= 1;

    if (debug_opts.log_gc) {
        print("{p} dec ref to {d}\n", .{ @as(*anyopaque, @ptrCast(obj)), obj.refCount });
    }

    // If ref count hits zero, immediately free (unless it might be in a cycle)
    if (obj.refCount == 0) {
        if (obj.cycleColor == .Purple) {
            // Don't free immediately - might be in cycle, let cycle collector handle it
            addToCycleRoots(obj);
        } else {
            freeObject(obj);
        }
    }
}

pub fn addToCycleRoots(obj: *Obj) void {
    if (obj.inCycleDetection) return;
    obj.inCycleDetection = true;
    gcData.cycleRoots.add(obj);
}

pub fn markObject(object: ?*Obj) void {
    if (object == null) return;

    const obj = object.?;
    if (obj.isMarked) return;

    if (debug_opts.log_gc) {
        print("{p} mark ", .{@as(*anyopaque, @ptrCast(obj))});
        value_h.printValue(value_h.OBJ_VAL(obj));
        print("\n", .{});
    }

    obj.isMarked = true;
    if (vm_h.vm.grayCapacity < (vm_h.vm.grayCount + 1)) {
        vm_h.vm.grayCapacity = if (vm_h.vm.grayCapacity < 8) 8 else vm_h.vm.grayCapacity * 2;
        vm_h.vm.grayStack = @ptrCast(@alignCast(realloc(@ptrCast(vm_h.vm.grayStack), @intCast(@sizeOf(*Obj) *% vm_h.vm.grayCapacity))));
    }
    vm_h.vm.grayCount += 1;
    if (vm_h.vm.grayStack) |stack| {
        stack[@intCast(vm_h.vm.grayCount - 1)] = @ptrCast(@alignCast(obj));
    }
}

pub fn markValue(value: Value) void {
    if (value.type == .VAL_OBJ)
        markObject(value.as.obj);
}

pub fn collectGarbage() void {
    // First try cycle collection
    collectCycles();

    // Then do generational collection based on allocation pressure
    if (shouldCollectYoung()) {
        collectGeneration(.Young);
        gcData.youngCollections += 1;
    }

    if (shouldCollectMiddle()) {
        collectGeneration(.Middle);
        gcData.middleCollections += 1;
    }

    if (shouldCollectOld()) {
        collectGeneration(.Old);
        gcData.oldCollections += 1;
    }

    // Fallback to traditional GC if needed
    while (gcData.state != .GC_IDLE) {
        incrementalGC();
    }
}

pub fn shouldCollectYoung() bool {
    return gcData.youngGen.count > 100 or vm_h.vm.bytesAllocated > vm_h.vm.nextGC;
}

pub fn shouldCollectMiddle() bool {
    return gcData.youngCollections % 5 == 0 and gcData.middleGen.count > 50;
}

pub fn shouldCollectOld() bool {
    return gcData.middleCollections % 10 == 0 and gcData.oldGen.count > 25;
}

pub fn collectGeneration(gen: __obj.Generation) void {
    if (debug_opts.log_gc) {
        print("Starting collection for generation {any}\n", .{gen});
        printGCStats();
    }

    const list = switch (gen) {
        .Young => &gcData.youngGen,
        .Middle => &gcData.middleGen,
        .Old => &gcData.oldGen,
    };

    const startTime = std.time.milliTimestamp();
    const initialCount = list.count;

    // Mark phase - mark all reachable objects
    markRootsForGeneration(gen);

    // Sweep phase - free unmarked objects and age survivors
    sweepGeneration(list, gen);

    if (debug_opts.log_gc) {
        const endTime = std.time.milliTimestamp();
        const collected = initialCount - list.count;
        print("Generation {any} collection completed in {d}ms\n", .{ gen, endTime - startTime });
        print("Collected {d} objects, {d} remaining\n", .{ collected, list.count });
        printGCStats();
    }
}

pub fn markRootsForGeneration(gen: __obj.Generation) void {
    // Mark stack roots
    const stackSize: usize = @intCast(@intFromPtr(vm_h.vm.stackTop) - @intFromPtr(&vm_h.vm.stack));
    const stackItemCount = stackSize / @sizeOf(Value);
    for (0..stackItemCount) |i| {
        markValueForGeneration(vm_h.vm.stack[i], gen);
    }

    // Mark frame roots
    for (0..@intCast(vm_h.vm.frameCount)) |i| {
        markObjectForGeneration(@ptrCast(@alignCast(vm_h.vm.frames[i].closure)), gen);
    }

    // Mark global roots
    markTableForGeneration(&vm_h.vm.globals, gen);
    markObjectForGeneration(@ptrCast(@alignCast(vm_h.vm.initString)), gen);
}

pub fn markValueForGeneration(value: Value, gen: __obj.Generation) void {
    if (value.type == .VAL_OBJ and value.as.obj != null) {
        markObjectForGeneration(value.as.obj, gen);
    }
}

pub fn markObjectForGeneration(object: ?*Obj, gen: __obj.Generation) void {
    if (object == null) return;
    const obj = object.?;

    // Only mark objects in this generation or younger
    if (@intFromEnum(obj.generation) > @intFromEnum(gen)) return;

    if (obj.isMarked) return;
    obj.isMarked = true;

    // Add to gray stack for processing
    if (vm_h.vm.grayCapacity < (vm_h.vm.grayCount + 1)) {
        vm_h.vm.grayCapacity = if (vm_h.vm.grayCapacity < 8) 8 else vm_h.vm.grayCapacity * 2;
        vm_h.vm.grayStack = @ptrCast(@alignCast(realloc(@ptrCast(vm_h.vm.grayStack), @intCast(@sizeOf(*Obj) *% vm_h.vm.grayCapacity))));
    }
    vm_h.vm.grayCount += 1;
    if (vm_h.vm.grayStack) |stack| {
        stack[@intCast(vm_h.vm.grayCount - 1)] = @ptrCast(@alignCast(obj));
    }
}

pub fn markTableForGeneration(table: *table_h.Table, gen: __obj.Generation) void {
    if (table.entries) |entries| {
        for (0..@intCast(table.capacity)) |i| {
            const entry = &entries[i];
            markObjectForGeneration(@ptrCast(@alignCast(entry.key)), gen);
            markValueForGeneration(entry.value, gen);
        }
    }
}

pub fn sweepGeneration(list: *ObjectList, gen: __obj.Generation) void {
    var current = list.head;
    var prev: ?*Obj = null;

    while (current) |obj| {
        const next = obj.next;

        if (obj.isMarked) {
            // Object survived - age it and potentially promote
            obj.isMarked = false;
            obj.age += 1;

            if (shouldPromote(obj, gen)) {
                promoteObject(obj, gen);
                // Remove from current list
                if (prev) |p| {
                    p.next = next;
                } else {
                    list.head = next;
                }
                list.count -= 1;
            } else {
                prev = obj;
            }
        } else {
            // Object is garbage - remove and free
            if (prev) |p| {
                p.next = next;
            } else {
                list.head = next;
            }
            list.count -= 1;
            freeObject(obj);
        }

        current = next;
    }
}

pub fn shouldPromote(obj: *Obj, currentGen: __obj.Generation) bool {
    return switch (currentGen) {
        .Young => obj.age >= 3,
        .Middle => obj.age >= 10,
        .Old => false,
    };
}

pub fn promoteObject(obj: *Obj, fromGen: __obj.Generation) void {
    const newGen: __obj.Generation = switch (fromGen) {
        .Young => .Middle,
        .Middle => .Old,
        .Old => .Old,
    };

    obj.generation = newGen;
    obj.age = 0;

    const targetList = switch (newGen) {
        .Young => &gcData.youngGen,
        .Middle => &gcData.middleGen,
        .Old => &gcData.oldGen,
    };

    targetList.add(obj);

    debugObjectGeneration(obj, "PROMOTE");
}

// Cycle collection using purple-gray-black algorithm
pub fn collectCycles() void {
    if (debug_opts.log_gc) {
        print("Starting cycle collection with {d} roots\n", .{gcData.cycleRoots.count});
    }

    const startTime = std.time.milliTimestamp();
    const initialRoots = gcData.cycleRoots.count;
    var cyclesCollected: u32 = 0;

    // Mark possible cycle roots
    var current = gcData.cycleRoots.head;
    while (current) |obj| {
        if (obj.cycleColor == .Purple) {
            markCycleRoots(obj);
        }
        current = obj.next;
    }

    // Scan for cycles
    current = gcData.cycleRoots.head;
    while (current) |obj| {
        if (obj.cycleColor == .Gray) {
            scanCycles(obj);
        }
        current = obj.next;
    }

    // Collect white objects (garbage cycles)
    current = gcData.cycleRoots.head;
    var prev: ?*Obj = null;
    while (current) |obj| {
        const next = obj.next;

        if (obj.cycleColor == .White) {
            collectWhite(obj);
            cyclesCollected += 1;
            // Remove from cycle roots
            if (prev) |p| {
                p.next = next;
            } else {
                gcData.cycleRoots.head = next;
            }
            gcData.cycleRoots.count -= 1;
        } else {
            obj.cycleColor = .Black;
            obj.inCycleDetection = false;
            prev = obj;
        }

        current = next;
    }

    if (debug_opts.log_gc) {
        const endTime = std.time.milliTimestamp();
        print("Cycle collection completed in {d}ms\n", .{endTime - startTime});
        print("Processed {d} roots, collected {d} cycles\n", .{ initialRoots, cyclesCollected });
    }
}

pub fn markCycleRoots(obj: *Obj) void {
    if (obj.cycleColor != .Purple) return;
    obj.cycleColor = .Gray;

    // Decrement ref count of children
    decrementChildren(obj);

    // Add children to processing queue
    addChildrenToCycleDetection(obj);
}

pub fn scanCycles(obj: *Obj) void {
    if (obj.cycleColor != .Gray) return;

    if (obj.refCount > 0) {
        // Object is still reachable
        scanBlack(obj);
    } else {
        // Object might be in a cycle
        obj.cycleColor = .White;
        scanChildrenForCycles(obj);
    }
}

pub fn scanBlack(obj: *Obj) void {
    obj.cycleColor = .Black;
    scanChildrenBlack(obj);
}

pub fn scanChildrenBlack(obj: *Obj) void {
    // Implementation depends on object type - similar to blackenObject
    switch (obj.type) {
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(obj));
            if (closure.function.obj.cycleColor != .Black) scanBlack(&closure.function.obj);
            if (closure.upvalues) |upvalues| {
                for (0..@intCast(closure.upvalueCount)) |i| {
                    if (upvalues[i]) |upvalue| {
                        if (upvalue.obj.cycleColor != .Black) scanBlack(&upvalue.obj);
                    }
                }
            }
        },
        else => {}, // Add other object types as needed
    }
}

pub fn scanChildrenForCycles(obj: *Obj) void {
    // Similar to scanChildrenBlack but marks children as white if gray
    switch (obj.type) {
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(obj));
            if (closure.function.obj.cycleColor == .Gray) scanCycles(&closure.function.obj);
            if (closure.upvalues) |upvalues| {
                for (0..@intCast(closure.upvalueCount)) |i| {
                    if (upvalues[i]) |upvalue| {
                        if (upvalue.obj.cycleColor == .Gray) scanCycles(&upvalue.obj);
                    }
                }
            }
        },
        else => {},
    }
}

pub fn collectWhite(obj: *Obj) void {
    if (obj.cycleColor == .White and !obj.isMarked) {
        obj.cycleColor = .Black; // Prevent recursive collection
        collectWhiteChildren(obj);
        freeObject(obj);
    }
}

pub fn collectWhiteChildren(obj: *Obj) void {
    // Free children that are also white
    switch (obj.type) {
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(obj));
            collectWhite(&closure.function.obj);
            if (closure.upvalues) |upvalues| {
                for (0..@intCast(closure.upvalueCount)) |i| {
                    if (upvalues[i]) |upvalue| {
                        collectWhite(&upvalue.obj);
                    }
                }
            }
        },
        else => {},
    }
}

pub fn decrementChildren(obj: *Obj) void {
    // Decrement ref count of all children
    switch (obj.type) {
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(obj));
            closure.function.obj.refCount -= 1;
            if (closure.upvalues) |upvalues| {
                for (0..@intCast(closure.upvalueCount)) |i| {
                    if (upvalues[i]) |upvalue| {
                        upvalue.obj.refCount -= 1;
                    }
                }
            }
        },
        else => {},
    }
}

pub fn addChildrenToCycleDetection(obj: *Obj) void {
    // Add children to cycle detection if they're purple
    switch (obj.type) {
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(obj));
            if (closure.function.obj.cycleColor == .Purple) {
                addToCycleRoots(&closure.function.obj);
            }
            if (closure.upvalues) |upvalues| {
                for (0..@intCast(closure.upvalueCount)) |i| {
                    if (upvalues[i]) |upvalue| {
                        if (upvalue.obj.cycleColor == .Purple) {
                            addToCycleRoots(&upvalue.obj);
                        }
                    }
                }
            }
        },
        else => {},
    }
}

pub fn freeObjects() void {
    // Free traditional object list only (hybrid GC objects are also in this list)
    var object: ?*Obj = vm_h.vm.objects;
    while (object) |current| {
        const next = current.next;
        freeObject(@ptrCast(@alignCast(current)));
        object = next;
    }

    // Clear hybrid GC lists without freeing (objects already freed above)
    gcData.youngGen.head = null;
    gcData.youngGen.count = 0;
    gcData.middleGen.head = null;
    gcData.middleGen.count = 0;
    gcData.oldGen.head = null;
    gcData.oldGen.count = 0;
    gcData.cycleRoots.head = null;
    gcData.cycleRoots.count = 0;

    if (vm_h.vm.grayStack) |stack| {
        free(@ptrCast(stack));
    }
}

pub fn freeObjectList(list: *ObjectList) void {
    // Clear the list without freeing objects (they're freed via vm.objects list)
    list.head = null;
    list.count = 0;
}

pub fn freeObject(object: *Obj) void {
    if (debug_opts.log_gc) print("{p} free type {any}\n", .{ @as(*anyopaque, @ptrCast(object)), object.*.type });

    switch (object.*.type) {
        .OBJ_BOUND_METHOD => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjBoundMethod), 0);
        },
        .OBJ_CLASS => {
            const klass: *obj_h.ObjClass = @ptrCast(object);
            freeTable(&klass.*.methods);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjClass), 0);
        },
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(object));
            _ = reallocate(@ptrCast(closure.*.upvalues), @intCast(@sizeOf(?*obj_h.ObjUpvalue) *% closure.*.upvalueCount), 0);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjClosure), 0);
        },
        .OBJ_FUNCTION => {
            const function: *obj_h.ObjFunction = @ptrCast(@alignCast(object));

            chunk_h.freeChunk(&function.*.chunk);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjFunction), 0);
        },
        .OBJ_INSTANCE => {
            const instance: *obj_h.ObjInstance = @ptrCast(@alignCast(object));
            freeTable(&instance.*.fields);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjInstance), 0);
        },
        .OBJ_NATIVE => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjNative), 0);
        },
        .OBJ_STRING => {
            const string: *obj_h.ObjString = @ptrCast(@alignCast(object));
            _ = reallocate(@ptrCast(string.chars), @intCast(@sizeOf(u8) *% string.length + 1), 0);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjString), 0);
        },
        .OBJ_UPVALUE => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjUpvalue), 0);
        },

        .OBJ_LINKED_LIST => {
            const linkedList: *obj_h.ObjLinkedList = @ptrCast(@alignCast(object));
            obj_h.freeObjectLinkedList(linkedList);
        },
        .OBJ_HASH_TABLE => {
            const hashTable: *obj_h.ObjHashTable = @ptrCast(@alignCast(object));
            obj_h.freeObjectHashTable(hashTable);
        },
        .OBJ_FVECTOR => {
            const fvector: *obj_h.FloatVector = @ptrCast(@alignCast(object));
            fvec.FloatVector.deinit(fvector);
        },
        .OBJ_RANGE => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjRange), 0);
        },
        .OBJ_PAIR => {
            const pair: *obj_h.ObjPair = @ptrCast(@alignCast(object));
            pair.key.release();
            pair.value.release();
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjPair), 0);
        },
    }
}

pub fn blackenObject(object: *Obj) void {
    if (debug_opts.log_gc) {
        print("{p} blacken ", .{@as(*anyopaque, @ptrCast(object))});
        value_h.printValue(value_h.OBJ_VAL(object));
        print("\n", .{});
    }

    switch (object.*.type) {
        .OBJ_BOUND_METHOD => {
            const bound: *obj_h.ObjBoundMethod = @ptrCast(@alignCast(object));
            markValue(bound.*.receiver);
            markObject(@ptrCast(@alignCast(bound.*.method)));
        },
        .OBJ_RANGE => {
            // ObjRange has no GC-managed fields to mark
        },
        .OBJ_CLASS => {
            var klass: *obj_h.ObjClass = @ptrCast(@alignCast(object));
            _ = &klass;
            markObject(@ptrCast(@alignCast(klass.*.name)));
            markTable(&klass.*.methods);
        },
        .OBJ_CLOSURE => {
            const closure: *obj_h.ObjClosure = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(closure.*.function)));
            for (0..@intCast(closure.*.upvalueCount)) |i| {
                if (closure.upvalues.?[i]) |upvalue| {
                    markObject(@ptrCast(@alignCast(upvalue)));
                }
            }
        },
        .OBJ_FUNCTION => {
            const function: *obj_h.ObjFunction = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(function.*.name)));
            markArray(&function.*.chunk.constants);
        },
        .OBJ_INSTANCE => {
            const instance: *obj_h.ObjInstance = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(instance.*.klass)));
            markTable(&instance.*.fields);
        },
        .OBJ_UPVALUE => {
            markValue(@as(*obj_h.ObjUpvalue, @ptrCast(@alignCast(object))).*.closed);
        },
        // .OBJ_ARRAY => {
        //     const array: *obj_h.ObjArray = @ptrCast(object);
        //     for (0..@intCast(array.*.count)) |i| {
        //         markValue(array.*.values[i]);
        //     }
        // },
        .OBJ_LINKED_LIST => {
            const linkedList: *obj_h.ObjLinkedList = @ptrCast(@alignCast(object));
            var current: ?*Node = linkedList.head;
            while (current) |node| {
                markValue(node.data);
                current = node.next;
            }
        },
        .OBJ_HASH_TABLE => {
            const hashTable: *ObjHashTable = @ptrCast(@alignCast(object));
            markTable(&hashTable.*.table);
        },
        .OBJ_PAIR => {
            const pair: *obj_h.ObjPair = @ptrCast(@alignCast(object));
            markValue(pair.key);
            markValue(pair.value);
        },

        else => {},
    }
}

pub fn markArray(array: *value_h.ValueArray) void {
    for (0..@intCast(array.*.count)) |i| {
        markValue(array.*.values[i]);
    }
}

pub fn incrementalGC() void {
    // Dynamic increment limit based on allocation pressure
    const baseLimit: i32 = 500;
    const pressureMultiplier = if (vm_h.vm.bytesAllocated > vm_h.vm.nextGC / 2) @as(i32, 2) else @as(i32, 1);
    const INCREMENT_LIMIT: i32 = baseLimit * pressureMultiplier;

    var workDone: i32 = 0;
    while (workDone < INCREMENT_LIMIT) {
        switch (gcData.state) {
            .GC_IDLE => {
                // Only start GC if we actually need it
                if (vm_h.vm.bytesAllocated < vm_h.vm.nextGC / 4) return;
                
                gcData.state = .GC_MARK_ROOTS;
                gcData.rootIndex = 0;
                gcData.sweepingObject = null;
                
                if (debug_opts.log_gc) {
                    print("Starting incremental GC cycle - allocated: {d}, threshold: {d}\n", 
                          .{ vm_h.vm.bytesAllocated, vm_h.vm.nextGC });
                }
            },
            .GC_MARK_ROOTS => {
                const stackSize: usize = @intCast(@intFromPtr(vm_h.vm.stackTop) - @intFromPtr(&vm_h.vm.stack));
                const stackItemCount = stackSize / @sizeOf(Value);
                
                // Process stack roots in batches for better cache locality
                const batchSize = @min(INCREMENT_LIMIT - workDone, 50);
                const endIndex = @min(gcData.rootIndex + @as(usize, @intCast(batchSize)), stackItemCount);
                
                while (gcData.rootIndex < endIndex) : (gcData.rootIndex += 1) {
                    markValue(vm_h.vm.stack[gcData.rootIndex]);
                    workDone += 1;
                }
                
                if (gcData.rootIndex >= stackItemCount) {
                    // Mark other roots efficiently
                    for (0..@intCast(vm_h.vm.frameCount)) |i| {
                        markObject(@ptrCast(@alignCast(vm_h.vm.frames[i].closure)));
                    }
                    markTable(&vm_h.vm.globals);
                    markTable(&vm_h.vm.strings);
                    markObject(@ptrCast(@alignCast(vm_h.vm.initString)));

                    // Mark upvalues
                    var upvalue: ?*obj_h.ObjUpvalue = vm_h.vm.openUpvalues;
                    while (upvalue) |current| {
                        markObject(@ptrCast(@alignCast(current)));
                        upvalue = current.next;
                    }

                    gcData.state = .GC_TRACING;
                }
            },
            .GC_TRACING => {
                // Process gray objects in batches for better performance
                const batchSize = @min(INCREMENT_LIMIT - workDone, @min(vm_h.vm.grayCount, 100));
                
                for (0..@intCast(batchSize)) |_| {
                    if (vm_h.vm.grayCount <= 0) break;
                    
                    vm_h.vm.grayCount -= 1;
                    if (vm_h.vm.grayStack) |stack| {
                        const object = stack[@intCast(vm_h.vm.grayCount)];
                        blackenObject(@ptrCast(@alignCast(object)));
                        workDone += 1;
                    }
                }
                
                if (vm_h.vm.grayCount == 0) {
                    gcData.state = .GC_SWEEPING;
                    gcData.sweepingObject = vm_h.vm.objects;
                }
            },
            .GC_SWEEPING => {
                // Adaptive sweeping - process more objects when under memory pressure
                var objectsProcessed: i32 = 0;
                const maxObjects = if (vm_h.vm.bytesAllocated > vm_h.vm.nextGC) 200 else 100;
                
                while ((gcData.sweepingObject != null) and (objectsProcessed < maxObjects) and (workDone < INCREMENT_LIMIT)) {
                    if (gcData.sweepingObject) |current| {
                        const next: ?*Obj = current.next;
                        if (!current.isMarked) {
                            freeObject(@ptrCast(@alignCast(current)));
                            vm_h.vm.objects = next;
                        } else {
                            current.isMarked = false;
                        }
                        gcData.sweepingObject = next;
                        objectsProcessed += 1;
                        workDone += 1;
                    }
                }
                
                if (gcData.sweepingObject == null) {
                    gcData.state = .GC_IDLE;
                    
                    // Calculate next GC threshold more conservatively
                    const minGrowth = @max(vm_h.vm.bytesAllocated / 4, 1024 * 1024); // At least 1MB growth
                    if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) / 2) {
                        vm_h.vm.nextGC = std.math.maxInt(usize);
                    } else {
                        vm_h.vm.nextGC = vm_h.vm.bytesAllocated + minGrowth;
                    }
                    
                    if (debug_opts.log_gc) {
                        print("Incremental GC cycle completed - new threshold: {d}\n", .{vm_h.vm.nextGC});
                    }
                }
            },
        }
        if (gcData.state == .GC_IDLE) {
            break;
        }
    }
}
