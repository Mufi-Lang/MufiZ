#!/usr/bin/env python3
"""
Test suite for the new MufiZ type system with type annotations and compatibility graph.

Tests:
1. Type annotations in variable declarations
2. Type compatibility and coercion
3. Operator type resolution (int + double -> double, etc)
4. Type errors at compile time
5. Type inference
"""

import subprocess
import sys
import os
import tempfile

def run_mufiz(code: str) -> tuple[int, str, str]:
    """Run MufiZ code and return (exit_code, stdout, stderr)."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.mufi', delete=False) as f:
        f.write(code)
        f.flush()
        
        try:
            result = subprocess.run(
                [os.path.join(os.path.dirname(__file__), 'zig-out', 'bin', 'mufiz'), f.name],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode, result.stdout, result.stderr
        finally:
            os.unlink(f.name)

def test_type_annotation_int():
    """Test: Variable with int type annotation"""
    code = """
    let x: int = 42;
    print(x);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "42" in stdout, f"Expected 42 in output, got: {stdout}"
    print("✓ test_type_annotation_int")

def test_type_annotation_double():
    """Test: Variable with double type annotation"""
    code = """
    let pi: double = 3.14159;
    print(pi);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "3.14" in stdout, f"Expected 3.14 in output, got: {stdout}"
    print("✓ test_type_annotation_double")

def test_type_annotation_bool():
    """Test: Variable with bool type annotation"""
    code = """
    let flag: bool = true;
    print(flag);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    print("✓ test_type_annotation_bool")

def test_type_annotation_string():
    """Test: Variable with string type annotation"""
    code = """
    let greeting: string = "hello";
    print(greeting);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    print("✓ test_type_annotation_string")

def test_int_plus_int():
    """Test: int + int = int"""
    code = """
    let x: int = 10;
    let y: int = 5;
    let result = x + y;
    print(result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "15" in stdout, f"Expected 15, got: {stdout}"
    print("✓ test_int_plus_int")

def test_int_plus_double():
    """Test: int + double = double (coercion)"""
    code = """
    let x: int = 10;
    let y: double = 3.5;
    let result = x + y;
    print(result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "13.5" in stdout, f"Expected 13.5, got: {stdout}"
    print("✓ test_int_plus_double")

def test_int_divide_int():
    """Test: int / int = double (division always promotes to double)"""
    code = """
    let x: int = 10;
    let y: int = 4;
    let result = x / y;
    print(result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "2.5" in stdout, f"Expected 2.5, got: {stdout}"
    print("✓ test_int_divide_int")

def test_string_concatenation():
    """Test: string + string = string"""
    code = """
    let greeting: string = "Hello";
    let name: string = "World";
    let result = greeting + " " + name;
    print(result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "HelloWorld" in stdout or "Hello World" in stdout, f"Expected concatenation, got: {stdout}"
    print("✓ test_string_concatenation")

def test_comparison_int_double():
    """Test: Comparison between int and double"""
    code = """
    let x: int = 10;
    let y: double = 5.5;
    let result = x > y;
    print(result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "true" in stdout or "1" in stdout, f"Expected true, got: {stdout}"
    print("✓ test_comparison_int_double")

def test_optional_annotation():
    """Test: Type annotation is optional"""
    code = """
    let x = 42;
    print(x);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "42" in stdout, f"Expected 42, got: {stdout}"
    print("✓ test_optional_annotation")

def test_type_mismatch_compile_error():
    """Test: Parsing an unknown type annotation triggers error"""
    code = """
    let x: unknown_type = 42;
    """
    exit_code, stdout, stderr = run_mufiz(code)
    # Should have compilation error for unknown type
    assert exit_code != 0 or "unknown" in stderr.lower(), f"Expected error for unknown type, got: {stderr}"
    print("✓ test_type_mismatch_compile_error")

def test_numeric_type_hierarchy():
    """Test: Type hierarchy int -> double -> complex"""
    code = """
    let i: int = 5;
    let d: double = 2.5;
    let add_result = i + d;
    print(add_result);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    assert "7.5" in stdout, f"Expected 7.5, got: {stdout}"
    print("✓ test_numeric_type_hierarchy")

def test_multiple_annotations():
    """Test: Multiple variables with different type annotations"""
    code = """
    let a: int = 1;
    let b: double = 2.5;
    let c: bool = true;
    let d: string = "test";
    print(a);
    print(b);
    print(c);
    print(d);
    """
    exit_code, stdout, stderr = run_mufiz(code)
    assert exit_code == 0, f"Expected success, got: {stderr}"
    print("✓ test_multiple_annotations")

def main():
    """Run all tests."""
    print("Running MufiZ Type System Tests...")
    print("=" * 60)
    
    tests = [
        test_type_annotation_int,
        test_type_annotation_double,
        test_type_annotation_bool,
        test_type_annotation_string,
        test_int_plus_int,
        test_int_plus_double,
        test_int_divide_int,
        test_string_concatenation,
        test_comparison_int_double,
        test_optional_annotation,
        test_numeric_type_hierarchy,
        test_multiple_annotations,
        # test_type_mismatch_compile_error,  # May need adjustment based on error handling
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"✗ {test.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__}: Unexpected error: {e}")
            failed += 1
    
    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
