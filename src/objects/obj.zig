pub const Obj = extern struct {
    type: ObjType,
    isMarked: bool = false,
    next: [*c]Obj = null,
};

pub const ObjType = enum(c_int) {
    OBJ_CLOSURE = 0,
    OBJ_FUNCTION = 1,
    OBJ_INSTANCE = 2,
    OBJ_NATIVE = 3,
    OBJ_STRING = 4,
    OBJ_UPVALUE = 5,
    OBJ_BOUND_METHOD = 6,
    OBJ_CLASS = 7,
    OBJ_ARRAY = 8,
    OBJ_LINKED_LIST = 9,
    OBJ_HASH_TABLE = 10,
    OBJ_MATRIX = 11,
    OBJ_FVECTOR = 12,
};
