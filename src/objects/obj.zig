pub const Obj = struct {
    type: ObjType,
    isMarked: bool = false,
    next: ?*Obj = null,

    // Reference counting fields
    refCount: u32 = 1,

    // Generational GC fields
    generation: Generation = .Young,
    age: u8 = 0,

    // Cycle detection
    inCycleDetection: bool = false,
    cycleColor: CycleColor = .White,
};

pub const Generation = enum(u8) {
    Young = 0, // Generation 0 - frequently collected
    Middle = 1, // Generation 1 - less frequently collected
    Old = 2, // Generation 2 - rarely collected
};

pub const CycleColor = enum(u8) {
    White = 0, // Potentially garbage
    Gray = 1, // Being processed
    Black = 2, // Definitely reachable
    Purple = 3, // Possible cycle root
};

pub const ObjType = enum(i32) {
    OBJ_CLOSURE = 0,
    OBJ_FUNCTION = 1,
    OBJ_INSTANCE = 2,
    OBJ_NATIVE = 3,
    OBJ_STRING = 4,
    OBJ_UPVALUE = 5,
    OBJ_BOUND_METHOD = 6,
    OBJ_CLASS = 7,
    OBJ_LINKED_LIST = 8,
    OBJ_HASH_TABLE = 9,
    OBJ_FVECTOR = 10,
    OBJ_RANGE = 11,
    OBJ_PAIR = 12,
};
