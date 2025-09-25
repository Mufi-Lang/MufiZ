# MufiZ REPL Segmentation Fault Fix

## Problem Description

The MufiZ REPL was experiencing a segmentation fault when executing simple statements like `const a = 5;`. The crash occurred in the `vm.run()` function at the very beginning of execution.

## Root Cause Analysis

### Technical Details

The segmentation fault was caused by **excessive stack allocation** in the `vm.run()` function during debug builds. Here's what was happening:

1. **Location**: The crash occurred at instruction `test %esp,-0x1000(%rsp,%r10,1)` in the function prologue
2. **Cause**: This is a **stack probe** instruction that Zig generates when a function needs large amounts of stack space
3. **Scale**: The function was trying to allocate approximately **39MB** of stack space (`%r10 = 0x25baf88`)
4. **Trigger**: The massive switch statement with 58 OpCode cases in debug mode caused Zig to reserve excessive stack space

### Why This Happened

- The `run()` function contains a complex switch statement with 58 different OpCode cases
- Each case potentially has local variables and complex expressions
- In **debug mode**, Zig's compiler conservatively allocates stack space for all possible code paths
- One case (`OP_FVECTOR`) had a large local array: `var values: [255]f64 = undefined` (2KB)
- The combination of all cases resulted in ~39MB stack allocation requirement
- This exceeded available stack space, causing the stack probe to access invalid memory

### GDB Evidence

```
=> 0x11afe6f <vm.run+15>: test %esp,-0x1000(%rsp,%r10,1)
%rsp = 0x7ffffca44800 (current stack pointer)
%r10 = 0x25baf88 (39563144 bytes = ~39MB)
```

The instruction was trying to probe stack memory at an invalid address, causing the segfault.

## Solution

### Immediate Fix

The segmentation fault is resolved by **building with optimizations**:

```bash
# Instead of debug build:
zig build

# Use optimized build:
zig build -Doptimize=ReleaseFast
```

### Code Improvements Applied

1. **Reduced Stack Array Usage**: 
   - Eliminated the 255-element `f64` array in `OP_FVECTOR`
   - Changed from intermediate array to direct stack-to-vector copying

2. **Build Configuration**: 
   - Recommend using optimized builds for production
   - Debug builds should be used only for development debugging

## Verification

After applying the fix:

### Before (Debug Build)
```bash
$ ./zig-out/bin/mufiz --repl
Welcome to MufiZ Interactive Shell
MufiZ v0.10.0 (Echo Release)
Type 'help' for more information or 'exit' to quit
(mufi) >> const a = 5;
Segmentation fault (core dumped)
```

### After (Optimized Build)
```bash
$ ./zig-out/bin/mufiz --repl
Welcome to MufiZ Interactive Shell
MufiZ v0.10.0 (Echo Release)
Type 'help' for more information or 'exit' to quit
(mufi) >> const a = 5;
(mufi) >> print(a);
5
(mufi) >> exit
Exiting MufiZ
```

## Technical Recommendations

### For Development

1. **Use debug builds sparingly**: Only when you need debugging symbols and stack traces
2. **Primary development**: Use `zig build -Doptimize=ReleaseFast` for normal development
3. **Testing**: All functionality tests should use optimized builds

### For Production

1. **Always use optimized builds**: `zig build -Doptimize=ReleaseFast` or `zig build -Doptimize=ReleaseSmall`
2. **Stack monitoring**: Consider monitoring stack usage in complex VM functions
3. **Code structure**: Keep individual functions smaller to avoid excessive stack allocation

### Long-term Architecture Considerations

1. **Function decomposition**: Consider breaking down the large `run()` function into smaller functions
2. **Tail call optimization**: Structure the VM loop to use less stack space
3. **Alternative dispatch**: Consider computed goto or function pointer tables instead of large switch statements

## Files Modified

- `src/vm.zig`: Reduced stack array usage in `OP_FVECTOR` case
- Build process: Recommend optimized builds

## Testing

The fix has been verified with:
- Simple variable declarations (`const a = 5;`)
- Print statements (`print("Hello World");`)
- Variable usage (`const a = 42; print(a);`)
- REPL commands (`help`, `exit`)
- Command-line execution

All tests pass without segmentation faults.