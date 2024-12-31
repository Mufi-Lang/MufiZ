pub const chunk_h = @import("chunk.zig");

pub const compiler_h = @import("compiler.zig");
pub const debug_h = @import("debug.zig");
pub const memory_h = @import("memory.zig");
pub const object_h = @import("object.zig");
pub const scanner_h = @import("scanner.zig");
pub const table_h = @import("table.zig");
pub const value_h = @import("value.zig");
pub const vm_h = @import("vm.zig");

/// Bindings to a Chunk of bytecode.
pub const Chunk = chunk_h.Chunk;
/// Bindings to Operation Codes.
pub const OpCode = chunk_h.OpCode;
/// Bindings to a Constant Operation.
pub const OP_CONSTANT = chunk_h.OP_CONSTANT;
/// Bindings to a Nil Operation.
pub const OP_NIL = chunk_h.OP_NIL;
/// Bindings to a True Operation.
pub const OP_TRUE = chunk_h.OP_TRUE;
/// Bindings to a False Operation.
pub const OP_FALSE = chunk_h.OP_FALSE;
/// Bindings to a Pop Operation (Pop the top of the stack).
pub const OP_POP = chunk_h.OP_POP;
/// Bindings to a Get Local Operation (Get a local variable in the scope).
pub const OP_GET_LOCAL = chunk_h.OP_GET_LOCAL;
/// Bindings to a Set Local Operation (Set a local variable in the scope).
pub const OP_SET_LOCAL = chunk_h.OP_SET_LOCAL;
/// Bindings to a Get Global Operation (Get a global variable).
pub const OP_GET_GLOBAL = chunk_h.OP_GET_GLOBAL;
/// Bindings to a Define Global Operation (Define a global variable).
pub const OP_DEFINE_GLOBAL = chunk_h.OP_DEFINE_GLOBAL;
/// Bindings to a Set Global Operation (Set a global variable).
pub const OP_SET_GLOBAL = chunk_h.OP_SET_GLOBAL;
/// Bindings to a Get Upvalue Operation (Get an upvalue).
pub const OP_GET_UPVALUE = chunk_h.OP_GET_UPVALUE;
/// Bindings to a Set Upvalue Operation (Set an upvalue).
pub const OP_SET_UPVALUE = chunk_h.OP_SET_UPVALUE;
/// Bindings to a Get Property Operation (Get a property from an object).
pub const OP_GET_PROPERTY = chunk_h.OP_GET_PROPERTY;
/// Bindings to a Set Property Operation (Set a property on an object).
pub const OP_SET_PROPERTY = chunk_h.OP_SET_PROPERTY;
/// Bindings to a Get Super Operation (Get a property from a superclass).
pub const OP_GET_SUPER = chunk_h.OP_GET_SUPER;
/// Bindings to a Equal Operation (Check if two values are equal).
pub const OP_EQUAL = chunk_h.OP_EQUAL;
/// Bindings to a Greater Operation (Check if one value is greater than another).
pub const OP_GREATER = chunk_h.OP_GREATER;
/// Bindings to a Less Operation (Check if one value is less than another).
pub const OP_LESS = chunk_h.OP_LESS;
/// Bindings to a Add Operation (Add two values).
pub const OP_ADD = chunk_h.OP_ADD;
/// Bindings to a Subtract Operation (Subtract two values).
pub const OP_SUBTRACT = chunk_h.OP_SUBTRACT;
/// Bindings to a Multiply Operation (Multiply two values).
pub const OP_MULTIPLY = chunk_h.OP_MULTIPLY;
/// Bindings to a Divide Operation (Divide two values).
pub const OP_DIVIDE = chunk_h.OP_DIVIDE;
/// Bindings to a Not Operation (Negate a boolean value)
pub const OP_NOT = chunk_h.OP_NOT;
/// Bindings to a Negate Operation (Negate a value).
pub const OP_NEGATE = chunk_h.OP_NEGATE;
/// Bindings to a Print Operation (Print a value).
pub const OP_PRINT = chunk_h.OP_PRINT;
/// Bindings to a Jump Operation (Jump to a specific offset).
pub const OP_JUMP = chunk_h.OP_JUMP;
/// Bindings to a Jump If False Operation (Jump to a specific offset if the value is false).
pub const OP_JUMP_IF_FALSE = chunk_h.OP_JUMP_IF_FALSE;
/// Bindings to a Loop Operation (Loop back to a specific offset).
pub const OP_LOOP = chunk_h.OP_LOOP;
/// Bindings to a Call Operation (Call a function).
pub const OP_CALL = chunk_h.OP_CALL;
/// Bindings to a Invoke Operation (Invoke a method).
pub const OP_INVOKE = chunk_h.OP_INVOKE;
/// Bindings to a Super Invoke Operation (Invoke a superclass method).
pub const OP_SUPER_INVOKE = chunk_h.OP_SUPER_INVOKE;
/// Bindings to a Closure Operation (Create a closure).
pub const OP_CLOSURE = chunk_h.OP_CLOSURE;
/// Bindings to a Close Upvalue Operation (Close an upvalue).
pub const OP_CLOSE_UPVALUE = chunk_h.OP_CLOSE_UPVALUE;
/// Bindings to a Return Operation (Return a value).
pub const OP_RETURN = chunk_h.OP_RETURN;
/// Bindings to a Class Operation (Define a class).
pub const OP_CLASS = chunk_h.OP_CLASS;
/// Bindings to a Inherit Operation (Inherit from a superclass).
pub const OP_INHERIT = chunk_h.OP_INHERIT;
/// Bindings to a Method Operation (Define a method).
pub const OP_METHOD = chunk_h.OP_METHOD;

/// Bindings to the Object Type.
pub const ObjType = object_h.ObjType;
/// Bindings to a Native Object (Native Function) Type.
pub const OBJ_NATIVE = object_h.OBJ_NATIVE;
/// Bindings to a String Object Type.
pub const OBJ_STRING = object_h.OBJ_STRING;
/// Bindings to a Upvalue Object Type.
pub const OBJ_UPVALUE = object_h.OBJ_UPVALUE;
/// Bindings to a Class Object Type.
pub const OBJ_CLASS = object_h.OBJ_CLASS;
/// Bindings to a Instance Object Type.
pub const OBJ_INSTANCE = object_h.OBJ_INSTANCE;
/// Bindings to a Bound Method Object Type.
pub const OBJ_BOUND_METHOD = object_h.OBJ_BOUND_METHOD;
/// Bindings to a Array Object Type.
pub const OBJ_ARRAY = object_h.OBJ_ARRAY;
/// Bindings to a Hash Table Object Type.
pub const OBJ_HASH_TABLE = object_h.OBJ_HASH_TABLE;
/// Bindings to a Linked List Object Type.
pub const OBJ_LINKED_LIST = object_h.OBJ_LINKED_LIST;
/// Bindings to a Matrix Object Type.
pub const OBJ_MATRIX = object_h.OBJ_MATRIX;
/// Bindings to a Vector Object Type.
pub const OBJ_FVECTOR = object_h.OBJ_FVECTOR;

/// Bindings to the Object Linked List Node Type.
pub const Obj = object_h.Obj;
/// Bindings to a String Object.
pub const ObjString = object_h.ObjString;
/// Bindings to a Function Object.
pub const ObjFunction = object_h.ObjFunction;
/// Bindings to a Upvalue Object.
pub const ObjUpvalue = object_h.ObjUpvalue;
/// Bindings to a Closure Object.
pub const ObjClosure = object_h.ObjClosure;
/// Bindings to a Native Object (Native Function).
pub const ObjNative = object_h.ObjNative;
/// Bindings to a Class Object.
pub const ObjClass = object_h.ObjClass;
/// Bindings to a Instance Object.
pub const ObjInstance = object_h.ObjInstance;
/// Bindings to a Bound Method Object.
pub const ObjBoundMethod = object_h.ObjBoundMethod;
/// Bindings to a Node Object.
pub const Node = object_h.Node;
/// Bindings to a Linked List Object.
pub const ObjLinkedList = object_h.ObjLinkedList;
/// Bindings to a Hash Table Object.
pub const ObjHashTable = object_h.ObjHashTable;
/// Bindings to a Array Object.
pub const ObjArray = object_h.ObjArray;
/// Bindings to `copyString` function which creates a new string object.
pub const copyString = object_h.copyString;

/// Bindings to the Value Type which represents all possible values in the language.
pub const Value = value_h.Value;
/// Bindings to ValueType which represents all possible value types in the language.
pub const ValueType = value_h.ValueType;
/// Bindings to a Value Array Type which represents an array of values.
pub const ValueArray = value_h.ValueArray;
/// Bindings to a Complex Value.
pub const Complex = value_h.Complex;
/// Bindings to a Hash Table implementation.
pub const Table = table_h.Table;
