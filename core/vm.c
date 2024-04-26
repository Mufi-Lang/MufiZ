#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "../include/common.h"
#include "../include/compiler.h"
#include "../include/vm.h"
#include "../include/debug.h"
#include "../include/memory.h"
#include "../include/value.h"
#include "../include/cstd.h"

// Global vm
VM vm;

// Resets the stack
static void resetStack()
{
    vm.stackTop = vm.stack;
    vm.frameCount = 0;
    vm.openUpvalues = NULL;
}

// returns runtime errors
void runtimeError(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputs("\n", stderr);

    for (int i = vm.frameCount - 1; i >= 0; i--)
    {
        CallFrame *frame = &vm.frames[i];
        ObjFunction *function = frame->closure->function;
        size_t instruction = frame->ip - function->chunk.code - 1;
        fprintf(stderr, "[line %d] in ", // [minus]
                function->chunk.lines[instruction]);
        if (function->name == NULL)
        {
            fprintf(stderr, "script\n");
        }
        else
        {
            fprintf(stderr, "%s()\n", function->name->chars);
        }
    }

    resetStack();
}

void defineNative(const char *name, NativeFn function)
{
    push(OBJ_VAL(copyString(name, (int)strlen(name))));
    push(OBJ_VAL(newNative(function)));
    tableSet(&vm.globals, AS_STRING(vm.stack[0]), vm.stack[1]);
    pop();
    pop();
}

void importCollections(void)
{
    defineNative("assert", assert_nf);
    defineNative("array", array_nf);
    defineNative("linked_list", linkedlist_nf);
    defineNative("hash_table", hashtable_nf);
    defineNative("matrix", matrix_nf);
    defineNative("fvec", fvector_nf);
    defineNative("range", range_nf);
    defineNative("linspace", linspace_nf);
    defineNative("slice", slice_nf);
    defineNative("splice", splice_nf);

    defineNative("push", push_nf);
    defineNative("pop", pop_nf);
    defineNative("push_front", push_front_nf);
    defineNative("pop_front", pop_front_nf);
    defineNative("nth", nth_nf);
    defineNative("sort", sort_nf);
    defineNative("contains", contains_nf);
    defineNative("insert", insert_nf);
    defineNative("len", len_nf);
    defineNative("search", search_nf);
    defineNative("is_empty", is_empty_nf);
    defineNative("equal_list", equal_list_nf);
    defineNative("reverse", reverse_nf);
    defineNative("merge", merge_nf);

    defineNative("put", put_nf);
    defineNative("get", get_nf);
    defineNative("remove", remove_nf);

    defineNative("set_row", set_row_nf);
    defineNative("set_col", set_col_nf);
    defineNative("set", set_nf);
    defineNative("kolasa", kolasa_nf);
    defineNative("rref", rref_nf);
    defineNative("rank", rank_nf);
    defineNative("transpose", transpose_nf);
    defineNative("det", determinant_nf);
    defineNative("lu", lu_nf);
    // defineNative("solve", solve_nf);

    defineNative("workspace", workspace_nf);
    defineNative("interp1", interp1_nf);
    defineNative("sum", sum_nf);
    defineNative("mean", mean_nf);
    defineNative("std", std_nf);
    defineNative("var", var_nf);
    defineNative("maxl", maxl_nf);
    defineNative("minl", minl_nf);

    defineNative("dot", dot_nf);
    defineNative("cross", cross_nf);
    defineNative("norm", norm_nf);
    defineNative("angle", angle_nf);
    defineNative("proj", proj_nf);
    defineNative("reflect", reflect_nf);
    defineNative("reject", reject_nf);
    defineNative("refract", refract_nf);
}

// Initializes the virtual machine
void initVM(void)
{
    resetStack();
    vm.objects = NULL;
    vm.bytesAllocated = 0;
    vm.nextGC = 1024 * 1024;
    vm.grayCount = 0;
    vm.grayCapacity = 0;
    vm.grayStack = NULL;

    initTable(&vm.globals);
    initTable(&vm.strings);

    vm.initString = NULL;
    vm.initString = copyString("init", 4);
}

// Frees the virtual machine
void freeVM(void)
{
    freeTable(&vm.globals);
    freeTable(&vm.strings);
    vm.initString = NULL;
    freeObjects();
}

// Pops value off of the stack
void push(Value value)
{
    *vm.stackTop = value; // Puts value on the top of the stack
    vm.stackTop++;        // Increment the stack top
}

Value pop()
{
    vm.stackTop--;       // Goes to the top value on the stack
    return *vm.stackTop; // Returns the value
}

static Value peek(int distance)
{
    return vm.stackTop[-1 - distance];
}

static bool call(ObjClosure *closure, int argCount)
{
    if (argCount != closure->function->arity)
    {
        runtimeError("Expected %d arguments but got %d.",
                     closure->function->arity, argCount);
        return false;
    }

    if (vm.frameCount == FRAMES_MAX)
    {
        runtimeError("Stack overflow.");
        return false;
    }

    CallFrame *frame = &vm.frames[vm.frameCount++];
    frame->closure = closure;
    frame->ip = closure->function->chunk.code;
    frame->slots = vm.stackTop - argCount - 1;
    return true;
}
static bool callValue(Value callee, int argCount)
{
    if (IS_OBJ(callee))
    {
        switch (OBJ_TYPE(callee))
        {
        case OBJ_BOUND_METHOD:
        {
            ObjBoundMethod *bound = AS_BOUND_METHOD(callee);
            vm.stackTop[-argCount - 1] = bound->receiver;
            return call(bound->method, argCount);
        }
        case OBJ_CLASS:
        {
            ObjClass *klass = AS_CLASS(callee);
            vm.stackTop[-argCount - 1] = OBJ_VAL(newInstance(klass));
            Value initializer;
            if (tableGet(&klass->methods, vm.initString, &initializer))
            {
                return call(AS_CLOSURE(initializer), argCount);
            }
            else if (argCount != 0)
            {
                runtimeError("Expected 0 arguments but got %d.", argCount);
                return false;
            }
            return true;
        }
        case OBJ_CLOSURE:
            return call(AS_CLOSURE(callee), argCount);
        case OBJ_INSTANCE:
        {
            ObjClass *klass = AS_CLASS(callee);
            vm.stackTop[-argCount - 1] = OBJ_VAL(newInstance(klass));
            return true;
        }
        case OBJ_NATIVE:
        {
            NativeFn native = AS_NATIVE(callee);
            Value result = native(argCount, vm.stackTop - argCount);
            vm.stackTop -= argCount + 1;
            push(result);
            return true;
        }
        default:
            break; // Non-callable object type.
        }
    }
    runtimeError("Can only call functions and classes.");
    return false;
}

static bool invokeFromClass(ObjClass *klass, ObjString *name, int argCount)
{
    Value method;
    if (!tableGet(&klass->methods, name, &method))
    {
        runtimeError("Undefined property '%s'.", name->chars);
        return false;
    }
    return call(AS_CLOSURE(method), argCount);
}

static bool invoke(ObjString *name, int argCount)
{
    Value receiver = peek(argCount);

    if (!IS_INSTANCE(receiver))
    {
        runtimeError("Only instances have methods.");
        return false;
    }

    ObjInstance *instance = AS_INSTANCE(receiver);

    Value value;
    if (tableGet(&instance->fields, name, &value))
    {
        vm.stackTop[-argCount - 1] = value;
        return callValue(value, argCount);
    }

    return invokeFromClass(instance->klass, name, argCount);
}

static bool bindMethod(ObjClass *klass, ObjString *name)
{
    Value method;
    if (!tableGet(&klass->methods, name, &method))
    {
        runtimeError("Undefined property '%s'.", name->chars);
        return false;
    }

    ObjBoundMethod *bound = newBoundMethod(peek(0), AS_CLOSURE(method));
    pop();
    push(OBJ_VAL(bound));
    return true;
}

static ObjUpvalue *captureUpvalue(Value *local)
{
    ObjUpvalue *prevUpvalue = NULL;
    ObjUpvalue *upvalue = vm.openUpvalues;
    while (upvalue != NULL && upvalue->location > local)
    {
        prevUpvalue = upvalue;
        upvalue = upvalue->next;
    }

    while (upvalue != NULL && upvalue->location == local)
    {
        return upvalue;
    }
    ObjUpvalue *createdUpvalue = newUpvalue(local);
    createdUpvalue->next = upvalue;

    if (prevUpvalue == NULL)
    {
        vm.openUpvalues = createdUpvalue;
    }
    else
    {
        prevUpvalue->next = createdUpvalue;
    }

    return createdUpvalue;
}

static void closeUpvalues(Value *last)
{
    while (vm.openUpvalues != NULL && vm.openUpvalues->location >= last)
    {
        ObjUpvalue *upvalue = vm.openUpvalues;
        upvalue->closed = *upvalue->location;
        upvalue->location = &upvalue->closed;
        vm.openUpvalues = upvalue->next;
    }
}

static void defineMethod(ObjString *name)
{
    Value method = peek(0);
    ObjClass *klass = AS_CLASS(peek(1));
    tableSet(&klass->methods, name, method);
    pop();
}

static bool isFalsey(Value value)
{
    return IS_NIL(value) || (IS_BOOL(value) && !AS_BOOL(value));
}

static void concatenate()
{
    ObjString *b = AS_STRING(peek(0));
    ObjString *a = AS_STRING(peek(1));
    int length = a->length + b->length;
    char *chars = ALLOCATE(char, length + 1);
    memcpy(chars, a->chars, a->length);
    memcpy(chars + a->length, b->chars, b->length);
    chars[length] = '\0';

    ObjString *result = takeString(chars, length);
    pop();
    pop();
    push(OBJ_VAL(result));
}

static void complex_add()
{
    Complex b = AS_COMPLEX(pop());
    Complex a = AS_COMPLEX(pop());
    Complex result;
    result.r = a.r + b.r;
    result.i = a.i + b.i;
    push(COMPLEX_VAL(result));
}

static void complex_sub()
{
    Complex b = AS_COMPLEX(pop());
    Complex a = AS_COMPLEX(pop());
    Complex result;
    result.r = a.r - b.r;
    result.i = a.i - b.i;
    push(COMPLEX_VAL(result));
}

static void complex_mul()
{
    Complex b = AS_COMPLEX(pop());
    Complex a = AS_COMPLEX(pop());
    Complex result;
    result.r = a.r * b.r - a.i * b.i;
    result.i = a.r * b.i + a.i * b.r;
    push(COMPLEX_VAL(result));
}

static void complex_div()
{
    Complex b = AS_COMPLEX(pop());
    Complex a = AS_COMPLEX(pop());
    Complex result;
    result.r = (a.r * b.r + a.i * b.i) / (b.r * b.r + b.i * b.i);
    result.i = (a.i * b.r - a.r * b.i) / (b.r * b.r + b.i * b.i);
    push(COMPLEX_VAL(result));
}

// runs the virtual machine
static InterpretResult run()
{
    CallFrame *frame = &vm.frames[vm.frameCount - 1];

#define READ_BYTE() (*frame->ip++)

#define READ_SHORT() \
    (frame->ip += 2, \
     (uint16_t)((frame->ip[-2] << 8) | frame->ip[-1]))

#define READ_CONSTANT() \
    (frame->closure->function->chunk.constants.values[READ_BYTE()])

#define READ_STRING() AS_STRING(READ_CONSTANT())
#define BINARY_OP(op)                                      \
    do                                                     \
    {                                                      \
        if (IS_INT(peek(0)) && IS_INT(peek(1)))            \
        {                                                  \
            int b = AS_INT(pop());                         \
            int a = AS_INT(pop());                         \
            push(INT_VAL(a op b));                         \
        }                                                  \
        else if (IS_DOUBLE(peek(0)) && IS_DOUBLE(peek(1))) \
        {                                                  \
            double b = AS_DOUBLE(pop());                   \
            double a = AS_DOUBLE(pop());                   \
            push(DOUBLE_VAL(a op b));                      \
        }                                                  \
        else                                               \
        {                                                  \
            runtimeError("Invalid Binary Operation.");     \
            return INTERPRET_RUNTIME_ERROR;                \
        }                                                  \
    } while (false)
#define BINARY_OP_COMPARISON(op)                                                 \
    do                                                                           \
    {                                                                            \
        if (IS_INT(peek(0)) && IS_INT(peek(1)))                                  \
        {                                                                        \
            int b = AS_INT(pop());                                               \
            int a = AS_INT(pop());                                               \
            push(BOOL_VAL(a op b));                                              \
        }                                                                        \
        else if (IS_DOUBLE(peek(0)) && IS_DOUBLE(peek(1)))                       \
        {                                                                        \
            double b = AS_DOUBLE(pop());                                         \
            double a = AS_DOUBLE(pop());                                         \
            push(BOOL_VAL(a op b));                                              \
        }                                                                        \
        else                                                                     \
        {                                                                        \
            runtimeError("Operands must be numeric type (double/int/complex)."); \
            return INTERPRET_RUNTIME_ERROR;                                      \
        }                                                                        \
    } while (false)
#ifdef DEBUG_TRACE_EXECUTION
    printf("         ");
    for (Value *slot = vm.stack; slot < vm.stackTop; slot++)
    {
        printf("[ ");
        printValue(*slot);
        printf(" ]");
    }
    printf("\n");
    disassembleInstruction(&frame->closure->function->chunk,
                           (int)(frame->ip - frame->closure->function->chunk.code));
#endif
    for (;;)
    {
        uint8_t instruction;
        switch (instruction = READ_BYTE())
        {
        case OP_CONSTANT:
        {
            Value constant = READ_CONSTANT();
            push(constant);
            break;
        }
        case OP_NIL:
            push(NIL_VAL);
            break;
        case OP_TRUE:
            push(BOOL_VAL(true));
            break;
        case OP_FALSE:
            push(BOOL_VAL(false));
            break;
        case OP_POP:
            pop();
            break;
        case OP_GET_LOCAL:
        {
            uint8_t slot = READ_BYTE();
            push(frame->slots[slot]);
            break;
        }
        case OP_SET_LOCAL:
        {
            uint8_t slot = READ_BYTE();
            frame->slots[slot] = peek(0);
            break;
        }
        case OP_GET_GLOBAL:
        {
            ObjString *name = READ_STRING();
            Value value;
            if (!tableGet(&vm.globals, name, &value))
            {
                runtimeError("Undefined variable '%s'.", name->chars);
                return INTERPRET_RUNTIME_ERROR;
            }
            push(value);
            break;
        }
        case OP_DEFINE_GLOBAL:
        {
            ObjString *name = READ_STRING();
            tableSet(&vm.globals, name, peek(0));
            pop();
            break;
        }
        case OP_SET_GLOBAL:
        {
            ObjString *name = READ_STRING();
            if (tableSet(&vm.globals, name, peek(0)))
            {
                tableDelete(&vm.globals, name); // [delete]
                runtimeError("Undefined variable '%s'.", name->chars);
                return INTERPRET_RUNTIME_ERROR;
            }
            break;
        }
        case OP_GET_UPVALUE:
        {
            uint8_t slot = READ_BYTE();
            push(*frame->closure->upvalues[slot]->location);
            break;
        }
        case OP_SET_UPVALUE:
        {
            uint8_t slot = READ_BYTE();
            *frame->closure->upvalues[slot]->location = peek(0);
            break;
        }
        case OP_GET_PROPERTY:
        {
            if (!IS_INSTANCE(peek(0)))
            {
                runtimeError("Only instances have properties.");
                return INTERPRET_RUNTIME_ERROR;
            }

            ObjInstance *instance = AS_INSTANCE(peek(0));
            ObjString *name = READ_STRING();

            Value value;
            if (tableGet(&instance->fields, name, &value))
            {
                pop();       // Instance
                push(value); // puts the values on top of the stack
                break;
            }
            if (!bindMethod(instance->klass, name))
            {
                return INTERPRET_RUNTIME_ERROR;
            }

            break;
        }
        case OP_SET_PROPERTY:
        {
            if (!IS_INSTANCE(peek(1)))
            {
                runtimeError("Only instances have fields.");
                return INTERPRET_RUNTIME_ERROR;
            }
            ObjInstance *instance = AS_INSTANCE(peek(1));
            tableSet(&instance->fields, READ_STRING(), peek(0));
            Value value = pop();
            pop();
            push(value);
            break;
        }
        case OP_GET_SUPER:
        {
            ObjString *name = READ_STRING();
            ObjClass *superclass = AS_CLASS(pop());
            if (!bindMethod(superclass, name))
            {
                return INTERPRET_RUNTIME_ERROR;
            }
            break;
        }
        case OP_EQUAL:
        {
            if (IS_ARRAY(peek(0)) && IS_ARRAY(peek(1)))
            {
                ObjArray *b = AS_ARRAY(pop());
                ObjArray *a = AS_ARRAY(pop());
                push(BOOL_VAL(equalArray(a, b)));
            }
            else if (IS_LINKED_LIST(peek(0)) && IS_LINKED_LIST(peek(1)))
            {
                ObjLinkedList *b = AS_LINKED_LIST(pop());
                ObjLinkedList *a = AS_LINKED_LIST(pop());
                push(BOOL_VAL(equalLinkedList(a, b)));
            }
            else
            {
                Value b = pop();
                Value a = pop();
                push(BOOL_VAL(valuesEqual(a, b)));
            }

            break;
        }
        case OP_GREATER:
            BINARY_OP_COMPARISON(>);
            break;
        case OP_LESS:
            BINARY_OP_COMPARISON(<);
            break;
        case OP_ADD:
        {
            if (IS_STRING(peek(0)) && IS_STRING(peek(1)))
            {
                concatenate();
            }
            else if (IS_COMPLEX(peek(0)) && IS_COMPLEX(peek(1)))
            {
                complex_add();
            }
            else if (IS_ARRAY(peek(0)) && IS_ARRAY(peek(1)))
            {
                ObjArray *b = AS_ARRAY(pop());
                ObjArray *a = AS_ARRAY(pop());
                ObjArray *result = addArray(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_FVECTOR(peek(1)))
            {
                FloatVector *b = AS_FVECTOR(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = addFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(1)) && IS_DOUBLE(peek(0)))
            {
                double b = AS_DOUBLE(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = singleAddFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_MATRIX(peek(0)) && IS_MATRIX(peek(1)))
            {
                ObjMatrix *b = AS_MATRIX(pop());
                ObjMatrix *a = AS_MATRIX(pop());
                ObjMatrix *result = addMatrix(a, b);
                push(OBJ_VAL(result));
            }
            else
            {
                BINARY_OP(+);
            }
        }
        break;
        case OP_SUBTRACT:
            if (IS_COMPLEX(peek(0)) && IS_COMPLEX(peek(1)))
            {
                complex_sub();
            }
            else if (IS_MATRIX(peek(0)) && IS_MATRIX(peek(1)))
            {
                ObjMatrix *b = AS_MATRIX(pop());
                ObjMatrix *a = AS_MATRIX(pop());
                ObjMatrix *merged = subMatrix(a, b);
                push(OBJ_VAL(merged));
            }
            else if (IS_ARRAY(peek(0)) && IS_ARRAY(peek(1)))
            {
                ObjArray *b = AS_ARRAY(pop());
                ObjArray *a = AS_ARRAY(pop());
                ObjArray *result = subArray(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_FVECTOR(peek(1)))
            {
                FloatVector *b = AS_FVECTOR(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = subFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_DOUBLE(peek(1)))
            {
                double b = AS_DOUBLE(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = singleSubFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else
            {
                BINARY_OP(-);
            }
            break;
        case OP_MULTIPLY:
            if (IS_COMPLEX(peek(0)) && IS_COMPLEX(peek(1)))
            {
                complex_mul();
            }
            else if (IS_MATRIX(peek(0)) && IS_MATRIX(peek(1)))
            {
                ObjMatrix *b = AS_MATRIX(pop());
                ObjMatrix *a = AS_MATRIX(pop());
                ObjMatrix *merged = mulMatrix(a, b);
                push(OBJ_VAL(merged));
            }
            else if (IS_ARRAY(peek(0)) && IS_ARRAY(peek(1)))
            {
                ObjArray *b = AS_ARRAY(pop());
                ObjArray *a = AS_ARRAY(pop());
                ObjArray *result = mulArray(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_FVECTOR(peek(1)))
            {
                FloatVector *b = AS_FVECTOR(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = mulFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_DOUBLE(peek(1)))
            {
                double b = AS_DOUBLE(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = scaleFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else
            {
                BINARY_OP(*);
            }
            break;
        case OP_DIVIDE:
            if (IS_COMPLEX(peek(0)) && IS_COMPLEX(peek(1)))
            {
                complex_div();
            }
            else if (IS_MATRIX(peek(0)) && IS_MATRIX(peek(1)))
            {
                ObjMatrix *b = AS_MATRIX(pop());
                ObjMatrix *a = AS_MATRIX(pop());
                ObjMatrix *merged = divMatrix(a, b);
                push(OBJ_VAL(merged));
            }
            else if (IS_FVECTOR(peek(0)) && IS_FVECTOR(peek(1)))
            {
                FloatVector *b = AS_FVECTOR(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = divFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_ARRAY(peek(0)) && IS_ARRAY(peek(1)))
            {
                ObjArray *b = AS_ARRAY(pop());
                ObjArray *a = AS_ARRAY(pop());
                ObjArray *result = divArray(a, b);
                push(OBJ_VAL(result));
            }
            else if (IS_FVECTOR(peek(0)) && IS_DOUBLE(peek(1)))
            {
                double b = AS_DOUBLE(pop());
                FloatVector *a = AS_FVECTOR(pop());
                FloatVector *result = singleDivFloatVector(a, b);
                push(OBJ_VAL(result));
            }
            else
            {
                BINARY_OP(/);
            }
            break;
        case OP_MODULO:
        {
            if (IS_INT(peek(0)) && IS_INT(peek(1)))
            {
                int b = AS_INT(pop());
                int a = AS_INT(pop());
                push(INT_VAL(a % b));
            }
            else
            {
                runtimeError("Operands must be integers.");
                return INTERPRET_RUNTIME_ERROR;
            }
            break;
        }
        case OP_EXPONENT:
        {
            if (IS_INT(peek(0)) && IS_INT(peek(1)))
            {
                int b = AS_INT(pop());
                int a = AS_INT(pop());
                push(INT_VAL(pow(a, b)));
            }
            else if (IS_DOUBLE(peek(0)) && IS_DOUBLE(peek(1)))
            {
                double b = AS_DOUBLE(pop());
                double a = AS_DOUBLE(pop());
                push(DOUBLE_VAL(pow(a, b)));
            }
            else if (IS_COMPLEX(peek(0)) && IS_DOUBLE(peek(1)))
            {
                double b = AS_DOUBLE(pop());
                Complex a = AS_COMPLEX(pop());
                Complex result;
                double r = sqrt(a.r * a.r + a.i * a.i);
                double theta = atan2(a.i, a.r);
                result.r = pow(r, b) * cos(b * theta);
                result.i = pow(r, b) * sin(b * theta);
                push(COMPLEX_VAL(result));
            }
            else
            {
                runtimeError("Operands must be numeric type.");
                return INTERPRET_RUNTIME_ERROR;
            }
            break;
        }
        case OP_NOT:
            push(BOOL_VAL(isFalsey(pop())));
            break;
        case OP_NEGATE:
            if (!IS_INT(peek(0)) && !IS_DOUBLE(peek(0)) && !IS_COMPLEX(peek(0)))
            {
                runtimeError("Operand must be a number (int/double).");
                return INTERPRET_RUNTIME_ERROR;
            }
            if (IS_INT(peek(0)))
            {
                push(INT_VAL(-AS_INT(pop())));
            }
            else if (IS_COMPLEX(peek(0)))
            {
                Complex c = AS_COMPLEX(pop());
                c.r *= -1;
                c.i *= -1;
                push(COMPLEX_VAL(c));
            }
            else
            {
                push(DOUBLE_VAL(-AS_DOUBLE(pop())));
            }
            break;
        case OP_PRINT:
        {
            printValue(pop());
            printf("\n");
            break;
        }
        case OP_JUMP:
        {
            uint16_t offset = READ_SHORT();
            frame->ip += offset;
            break;
        }
        case OP_JUMP_IF_FALSE:
        {
            uint16_t offset = READ_SHORT();
            if (isFalsey(peek(0)))
                frame->ip += offset;
            break;
        }
        case OP_LOOP:
        {
            uint16_t offset = READ_SHORT();
            frame->ip -= offset;
            break;
        }
        case OP_CALL:
        {
            int argCount = READ_BYTE();
            if (!callValue(peek(argCount), argCount))
            {
                return INTERPRET_RUNTIME_ERROR;
            }
            frame = &vm.frames[vm.frameCount - 1];
            break;
        }
        case OP_INVOKE:
        {
            ObjString *method = READ_STRING();
            int argCount = READ_BYTE();
            if (!invoke(method, argCount))
            {
                return INTERPRET_RUNTIME_ERROR;
            }
            frame = &vm.frames[vm.frameCount - 1];
            break;
        }
        case OP_SUPER_INVOKE:
        {
            ObjString *method = READ_STRING();
            int argCount = READ_BYTE();
            ObjClass *superclass = AS_CLASS(pop());
            if (!invokeFromClass(superclass, method, argCount))
            {
                return INTERPRET_RUNTIME_ERROR;
            }
            frame = &vm.frames[vm.frameCount - 1];
            break;
        }
        case OP_CLOSURE:
        {
            ObjFunction *function = AS_FUNCTION(READ_CONSTANT());
            ObjClosure *closure = newClosure(function);
            push(OBJ_VAL(closure));

            for (int i = 0; i < closure->upvalueCount; i++)
            {
                uint8_t isLocal = READ_BYTE();
                uint8_t index = READ_BYTE();
                if (isLocal)
                {
                    closure->upvalues[i] = captureUpvalue(frame->slots + index);
                }
                else
                {
                    closure->upvalues[i] = frame->closure->upvalues[index];
                }
            }

            break;
        }
        case OP_CLOSE_UPVALUE:
        {
            closeUpvalues(vm.stackTop - 1);
            pop();
            break;
        }
        case OP_RETURN:
        {
            Value result = pop();
            closeUpvalues(frame->slots);
            vm.frameCount--;
            if (vm.frameCount == 0)
            {
                pop();
                return INTERPRET_OK;
            }

            vm.stackTop = frame->slots;
            push(result);
            frame = &vm.frames[vm.frameCount - 1];
            break;
        }
        case OP_CLASS:
        {
            push(OBJ_VAL(newClass(READ_STRING())));
            break;
        }
        case OP_INHERIT:
        {
            Value superclass = peek(1);
            if (!IS_CLASS(superclass))
            {
                runtimeError("Superclass must be a class.");
                return INTERPRET_RUNTIME_ERROR;
            }
            ObjClass *subclass = AS_CLASS(peek(0));
            tableAddAll(&AS_CLASS(superclass)->methods, &subclass->methods);
            pop();
            break;
        }
        case OP_METHOD:
        {
            defineMethod(READ_STRING());
            break;
        }
        }
    }

#undef READ_BYTE
#undef READ_SHORT
#undef READ_CONSTANT
#undef READ_STRING
#undef BINARY_OP
#undef BINARY_OP_COMPARISON
}

// Interprets the chunks
InterpretResult interpret(const char *source)
{
    ObjFunction *function = compile(source);
    if (function == NULL)
        return INTERPRET_COMPILE_ERROR;

    push(OBJ_VAL(function));
    ObjClosure *closure = newClosure(function);
    pop();
    push(OBJ_VAL(closure));
    call(closure, 0);

    return run();
}
