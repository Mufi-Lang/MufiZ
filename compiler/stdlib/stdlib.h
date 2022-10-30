
#ifndef mufi_stdlib_h
#define mufi_stdlib_h

//> From the functions inside each module
//> Stdlib creates a native function for it
#include <stdio.h>
#include "math_.h"
#include "files.h"
#include "os.h"
#include "conv.h"
#include "string.h"
#include "../value.h"
#include "../object.h"


//> Math native functions
Value powNative(int argCount, Value* args);
Value moduloNative(int argCount, Value* args);
Value sumNative(int argCount, Value* args);
Value productNative(int argCount, Value* args);
Value logNative(int argCount, Value* args);

//> File native functions
Value fileWriteNative(int argCount, Value* args);
Value fileReadNative(int argCount, Value* args);
Value fileAppendNative(int argCount, Value* args);
Value newDirNative(int argCount, Value* args);
//> OS native functions
Value cmdNative(int argCount, Value* args);
Value clockNative(int argCount, Value* args);
Value sysExitNative(int argCount, Value* args);
//> Conversion native functions
Value asDoubleNative(int argCount, Value* args);
Value asIntNative(int argCount, Value* args);
Value asStrNative(int argCount, Value* args);

//> String functions
Value charAtNative(int argCount, Value* args);
Value lenNative(int argCount, Value* args);
Value subStrNative(int argCount, Value* args);
Value trimNative(int argCount, Value* args);



#endif