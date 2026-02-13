# Perfect Hash Implementation for Keyword Lookup

## Overview

This document describes the perfect hash function implementation used for O(1) keyword lookup in the MufiZ scanner. The implementation provides zero-collision, constant-time keyword recognition, replacing the previous binary search approach.

## Implementation Details

### Hash Function

The perfect hash function uses a combination of four character-based features:

```zig
inline fn perfectHash(str: []const u8) u8 {
    const len = str.len;
    const first = str[0];
    const last = str[len - 1];
    const middle = if (len > 2) str[len / 2] else first;
    
    const hash = (first * 2) + (last * 5) + (middle * 37) + (len * 11);
    return @truncate(hash & 63);
}
```

**Features used:**
- First character
- Last character
- Middle character (or first character for strings ≤2 chars)
- String length

**Multipliers:** 2, 5, 37, 11 (found via compile-time search)

**Table size:** 64 entries (power of 2 for fast modulo via bitwise AND)

### Compile-Time Verification

The implementation includes compile-time verification to ensure zero collisions:

```zig
fn findPerfectHashMultipliers() void {
    comptime {
        // Test all 30 keywords
        var used = [_]bool{false} ** PERFECT_HASH_SIZE;
        for (keywords) |kw| {
            const hash = perfectHash(kw);
            if (used[hash]) {
                @compileError("Perfect hash collision detected...");
            }
            used[hash] = true;
        }
    }
}
```

If the multipliers are changed and cause collisions, compilation will fail with a clear error message.

### Hash Table Structure

The hash table is a 64-entry array built at compile time:

```zig
const PERFECT_HASH_TABLE = blk: {
    var table: [PERFECT_HASH_SIZE]?PerfectHashEntry = [_]?PerfectHashEntry{null} ** PERFECT_HASH_SIZE;
    
    // Insert all keywords at their perfect hash positions
    for (keywords) |kw| {
        const hash = perfectHash(kw.str);
        table[hash] = PerfectHashEntry{
            .keyword = kw.str,
            .token = kw.tok,
        };
    }
    
    break :blk table;
};
```

### Lookup Algorithm

The lookup is a simple O(1) operation:

1. Compute perfect hash for the identifier
2. Index into the hash table
3. If slot is occupied, verify string equality (protects against non-keywords hashing to occupied slots)
4. Return token type or IDENTIFIER

```zig
pub fn identifierType() TokenType {
    const identifier_slice = scanner.start[0..length];
    const hash = perfectHash(identifier_slice);
    
    if (PERFECT_HASH_TABLE[hash]) |entry| {
        if (std.mem.eql(u8, identifier_slice, entry.keyword)) {
            return entry.token;
        }
    }
    
    return .TOKEN_IDENTIFIER;
}
```

## Keyword Distribution

The hash function distributes all 30 MufiZ keywords across 64 table slots with zero collisions:

```
Keyword     Hash    Keyword     Hash    Keyword     Hash
--------    ----    --------    ----    --------    ----
and         61      break       43      case        10
class       1       const       39      continue    4
each        13      else        14      end         5
false       24      for         50      foreach     58
from        36      fun         60      if          19
import      35      in          59      item        56
let         22      nil         6       or          57
print       8       return      53      self        44
super       7       switch      52      true        54
var         12      while       11      as          28
```

Load factor: 30/64 = 46.875% (good balance between space and collision avoidance)

## Performance Improvements

### Benchmark Results

Compared to the previous binary search implementation:

| Benchmark       | Before  | After   | Improvement |
|----------------|---------|---------|-------------|
| Keywords       | 0.24 μs | 0.20 μs | **16.7% faster** |
| Identifiers    | 0.12 μs | 0.10 μs | **16.7% faster** |
| Real-world     | 0.41 μs | 0.39 μs | **4.9% faster** |

### Algorithmic Improvements

- **Binary search:** O(log n) with ~4.9 comparisons for 30 keywords
- **Perfect hash:** O(1) with 1 hash computation + 1 string comparison

The perfect hash eliminates:
- Log(n) iterations
- Multiple hash computations per lookup
- Branch mispredictions from binary search

## Finding Perfect Hash Multipliers

The multipliers were found using a brute-force search tool (`tools/find_perfect_hash.zig`):

```bash
$ zig run tools/find_perfect_hash.zig
Searching for perfect hash multipliers...
Keywords: 30
Hash table size: 64

✓ Found #1: m1=2, m2=5, m3=37, m4=11
```

The tool tests combinations of prime numbers until finding multipliers that produce zero collisions for all keywords.

To find alternative multipliers (e.g., if keywords change):

```bash
cd tools
zig run find_perfect_hash.zig
```

## Testing

Comprehensive test suite in `src/test_perfect_hash.zig`:

- ✓ All 30 keywords correctly recognized
- ✓ Non-keywords return IDENTIFIER
- ✓ Case sensitivity (keywords are lowercase only)
- ✓ Keywords with surrounding whitespace
- ✓ Multiple keywords in sequence
- ✓ Coverage validation (no collisions)
- ✓ Edge cases (empty input, single chars)
- ✓ Keywords in various source positions

Run tests:
```bash
zig test src/test_perfect_hash.zig -I src/
```

All 9 tests pass.

## Maintenance

### Adding New Keywords

If new keywords are added to MufiZ:

1. Add the keyword to the `keywords` array in `scanner_optimized.zig`
2. Run the multiplier finder: `zig run tools/find_perfect_hash.zig`
3. If collisions occur, update `HASH_MULT_*` constants with new multipliers
4. The compile-time verification will catch any issues during build
5. Update tests in `test_perfect_hash.zig`

### Modifying Hash Function

If the hash formula needs to change:

1. Update `perfectHash()` in `scanner_optimized.zig`
2. Update the same function in `tools/find_perfect_hash.zig`
3. Run the multiplier finder to get new constants
4. Verify with `zig build test`
5. Run benchmarks to measure impact: `zig build bench-scanner`

## Technical Notes

### Why Power-of-Two Table Size?

Using 64 (2^6) allows fast modulo via bitwise AND:
```zig
hash & 63  // Fast: single AND instruction
vs
hash % 64  // Slower: division operation
```

### Memory Overhead

- Table: 64 × (1 byte tag + 16 bytes entry) ≈ 1 KB
- Completely initialized at compile time (zero runtime cost)
- Efficient cache utilization due to compact representation

### String Comparison Cost

Even with perfect hashing, we still need string comparison to handle:
- Non-keywords that hash to occupied slots
- Security: prevent hash collision attacks

However, this happens only once per identifier (vs. log(n) times in binary search).

## References

- Original implementation: `src/scanner_optimized.zig`
- Multiplier finder: `tools/find_perfect_hash.zig`
- Test suite: `src/test_perfect_hash.zig`
- Benchmark suite: `benchmark/scanner_bench.zig`

## Future Optimizations

Potential further improvements:

1. **SIMD string comparison**: Use vector instructions for string equality checks
2. **Length-based pre-filtering**: Check length before hash (most keywords have unique lengths)
3. **Inline string comparison**: For short keywords (≤8 bytes), compare as integers
4. **Hash table compaction**: Use only occupied slots (sparse array optimization)

These are tracked in Phase 2+ of the scanner optimization roadmap.

---

**Status:** ✅ Implemented and tested (Phase 1)  
**Performance gain:** ~17% faster keyword/identifier scanning  
**Maintenance cost:** Low (compile-time verification prevents regressions)