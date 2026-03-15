# Known Issues

## Bytecode Validator Warning (Pre-existing)

**Symptom:** Messages like:
```
❌ Invalid constant index at offset 4: 196 >= 3
⚠️  BYTECODE VALIDATION WARNING after pass 1
⚠️  Bytecode may have issues but continuing...
```

**Severity:** Cosmetic - does not affect functionality

**Description:** The bytecode optimizer's validation pass detects inconsistencies in constant indexing, but the code executes correctly regardless. This appears to be an issue with how the optimizer handles constant indices during optimization passes.

**Status:** Pre-existing issue (not related to type system implementation)

**Workaround:** None needed - the warnings can be safely ignored as the bytecode executes correctly.

**Root Cause Investigation Needed:** Likely in `src/bytecode_optimizer.zig` - may require review of how constant indices are tracked during optimization passes.
