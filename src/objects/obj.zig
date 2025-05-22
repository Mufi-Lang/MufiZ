pub const Obj = extern struct {
    type: ObjType,
    isMarked: bool = false,
    next: [*c]Obj = null,
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
};
