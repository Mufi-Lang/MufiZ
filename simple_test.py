#!/usr/bin/env python3
import subprocess
import os
import sys

def test_simple_execution():
    """Test the most basic MufiZ execution"""

    # Create a very simple test file
    test_content = 'print("Hello World");'
    test_file = "temp_test.mufi"

    try:
        # Write test file
        with open(test_file, "w") as f:
            f.write(test_content)

        print("Testing MufiZ with simple print statement...")
        print(f"Test file content: {test_content}")

        # Try to run the test
        result = subprocess.run(
            ["./zig-out/bin/mufiz", "-r", test_file],
            capture_output=True,
            text=True,
            timeout=10
        )

        print(f"Return code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")

        if result.returncode == 0:
            print("✅ SUCCESS: Basic execution works!")
            return True
        else:
            print("❌ FAILED: Basic execution failed")
            return False

    except subprocess.TimeoutExpired:
        print("❌ TIMEOUT: Process hung")
        return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False
    finally:
        # Clean up
        if os.path.exists(test_file):
            os.remove(test_file)

def test_version():
    """Test if the binary responds to version flag"""
    try:
        result = subprocess.run(
            ["./zig-out/bin/mufiz", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        print(f"Version test - Return code: {result.returncode}")
        print(f"Version output: {result.stdout}")
        return result.returncode == 0
    except Exception as e:
        print(f"Version test failed: {e}")
        return False

def main():
    print("=== Simple MufiZ Test Script ===")
    print()

    # Check if binary exists
    if not os.path.exists("./zig-out/bin/mufiz"):
        print("❌ ERROR: mufiz binary not found at ./zig-out/bin/mufiz")
        print("Please run 'zig build' first")
        sys.exit(1)

    print("✅ Found mufiz binary")

    # Test version first (simplest test)
    print("\n--- Testing Version ---")
    version_ok = test_version()

    # Test simple execution
    print("\n--- Testing Simple Execution ---")
    execution_ok = test_simple_execution()

    print("\n=== Results ===")
    print(f"Version test: {'✅ PASS' if version_ok else '❌ FAIL'}")
    print(f"Execution test: {'✅ PASS' if execution_ok else '❌ FAIL'}")

    if execution_ok:
        print("\n🎉 Basic functionality is working!")
        print("You can now run the full test suite with: python3 test_suite.py")
    else:
        print("\n🚨 Basic execution is failing - need to debug the interpreter")

if __name__ == "__main__":
    main()
