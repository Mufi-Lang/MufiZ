#!/bin/bash

# Test script for REPL const functionality
# Tests const vs var behavior in interactive mode

echo "Testing MufiZ REPL const functionality..."
echo "======================================="

# Test 1: Basic const functionality
echo ""
echo "Test 1: Basic const declaration and usage"
echo "Expected: Should declare const and print value"
echo ""

(
    echo "const PI = 3.14159;"
    sleep 0.2
    echo "print(PI);"
    sleep 0.2
    echo "exit"
) | ./zig-out/bin/mufiz --repl

echo ""
echo "Test 2: Const reassignment (should fail)"
echo "Expected: Should show error when trying to reassign const"
echo ""

(
    echo "const x = 5;"
    sleep 0.2
    echo "print(x);"
    sleep 0.2
    echo "x = 10;"
    sleep 0.2
    echo "exit"
) | ./zig-out/bin/mufiz --repl

echo ""
echo "Test 3: Var reassignment (should work)"
echo "Expected: Should allow reassignment of var"
echo ""

(
    echo "var y = 5;"
    sleep 0.2
    echo "print(y);"
    sleep 0.2
    echo "y = 10;"
    sleep 0.2
    echo "print(y);"
    sleep 0.2
    echo "exit"
) | ./zig-out/bin/mufiz --repl

echo ""
echo "Test 4: Mixed const and var"
echo "Expected: const should be read-only, var should be mutable"
echo ""

(
    echo "const name = \"MufiZ\";"
    sleep 0.2
    echo "var version = 1;"
    sleep 0.2
    echo "print(name);"
    sleep 0.2
    echo "print(version);"
    sleep 0.2
    echo "version = 2;"
    sleep 0.2
    echo "print(version);"
    sleep 0.2
    echo "name = \"Other\";"
    sleep 0.2
    echo "exit"
) | ./zig-out/bin/mufiz --repl

echo ""
echo "Test 5: Const in expressions"
echo "Expected: Should be able to use const in calculations"
echo ""

(
    echo "const PI = 3.14159;"
    sleep 0.2
    echo "var radius = 5;"
    sleep 0.2
    echo "print(PI * radius * radius);"
    sleep 0.2
    echo "exit"
) | ./zig-out/bin/mufiz --repl

echo ""
echo "======================================="
echo "REPL const tests completed!"
echo ""
echo "Summary:"
echo "- const should prevent reassignment"
echo "- var should allow reassignment"
echo "- const should work in expressions"
echo "- Both should work for initial declaration"
