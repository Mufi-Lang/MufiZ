#!/bin/bash

# Test script to validate REPL foreach functionality

echo "Testing MufiZ REPL foreach functionality..."

# Test 1: Single-line foreach
echo "=== Test 1: Single-line foreach ==="
echo -e "var nums = {1, 2, 3}\nforeach (n in nums) { print n; }\nexit" | zig build run -- --repl

echo ""

# Test 2: Multi-line foreach
echo "=== Test 2: Multi-line foreach ==="
echo -e "var nums = {1, 2, 3}\nforeach (n in nums) {\n    print \"Number:\";\n    print n;\n}\nexit" | zig build run -- --repl

echo ""

# Test 3: Nested braces
echo "=== Test 3: Nested braces ==="
echo -e "var nums = {1, 2, 3}\nforeach (n in nums) {\n    if (n == 2) {\n        print \"Found two!\";\n    }\n    print n;\n}\nexit" | zig build run -- --repl

echo ""

# Test 4: Break statement
echo "=== Test 4: Break statement ==="
echo -e "var nums = {1, 2, 3, 4, 5}\nforeach (n in nums) {\n    print n;\n    if (n == 3) {\n        break;\n    }\n}\nexit" | zig build run -- --repl

echo ""

# Test 5: Continue statement
echo "=== Test 5: Continue statement ==="
echo -e "var nums = {1, 2, 3, 4, 5}\nforeach (n in nums) {\n    if (n == 3) {\n        continue;\n    }\n    print n;\n}\nexit" | zig build run -- --repl

echo ""

# Test 6: Range-based foreach
echo "=== Test 6: Range-based foreach ==="
echo -e "foreach (i in 1..=5) {\n    print i;\n}\nexit" | zig build run -- --repl

echo ""

echo "All REPL foreach tests completed!"
