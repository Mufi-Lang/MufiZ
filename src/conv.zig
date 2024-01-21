const value = @cImport(@cInclude("value.h"));
const Value = value.Value;

pub const Conv = struct {
    const VAL_INT = value.VAL_INT;
    const VAL_BOOL = value.VAL_BOOL;
    const VAL_DOUBLE = value.VAL_DOUBLE;
    const VAL_NIL = value.VAL_NIL;
    const VAL_OBJ = value.VAL_OBJ;

    
};
