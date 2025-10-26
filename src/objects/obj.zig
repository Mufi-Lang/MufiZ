pub const Obj = struct {
    // 8-byte aligned fields first (optimal packing)
    type: ObjType,              // 4 bytes (enum backed by i32)
    refCount: u32 = 1,          // 4 bytes (packed next to type, no padding)
    next: ?*Obj = null,         // 8 bytes (pointer, naturally 8-byte aligned)
    
    // Pack all 1-byte fields together to minimize padding
    generation: Generation = .Young,  // 1 byte (enum backed by u8)
    age: u8 = 0,                      // 1 byte
    cycleColor: CycleColor = .White,  // 1 byte (enum backed by u8)
    isMarked: bool = false,           // 1 byte
    inCycleDetection: bool = false,   // 1 byte
    // Compiler adds 3 bytes padding here to align struct to 8 bytes
    // Total size: 24 bytes (down from ~48 bytes with old layout)
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
