const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;
const Obj = @import("obj.zig").Obj;
const Value = @import("../value.zig").Value;

// The goal to have this by its own to help optimize this, 
// easily look over the bounded methods and start putting optimizations 
// similar to whats in the Zig ArrayList. 

pub const ObjArray = extern struct {
    obj: Obj,
    capacity: Int,
    count: Int,
    pos: Int,
    _static: bool,
    values: [*c]Value,

    const Self = [*c]@This();
    const Int = i32;

    pub fn init(cap: Int, static: bool) Self {
        const self: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(ObjArray), .OBJ_ARRAY)));
        self.*.capacity = cap;
        self.*.count = 0;
        self.*.values = @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(Value) *% cap))));
        self.*._static = static;
        return self;
    }
};
