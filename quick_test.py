#!/usr/bin/env python3
import subprocess
import sys

def main():
    print("Running MufiZ test suite and collecting results...")

    try:
        result = subprocess.run(
            ["python3", "test_suite.py"],
            capture_output=True,
            text=True,
            timeout=60
        )

        output_lines = result.stdout.split('\n')

        # Count results
        successful = 0
        failed = 0

        for line in output_lines:
            if "executed successfully" in line:
                successful += 1
            elif "failed with exit code" in line or "crashed with" in line:
                failed += 1

        # Look for summary lines
        summary_found = False
        for line in output_lines:
            if "=== Test Results ===" in line:
                summary_found = True
            elif summary_found and ("Successful tests:" in line or "Failed tests:" in line):
                print(line)

        if not summary_found:
            print(f"\n=== Quick Summary ===")
            print(f"✅ Successful tests: {successful}")
            print(f"❌ Failed tests: {failed}")
            print(f"📊 Total tests: {successful + failed}")

            if successful > 0 and failed == 0:
                print("🎉 ALL TESTS PASSED!")
            elif successful > failed:
                print(f"🔧 Most tests passing ({successful}/{successful + failed})")
            else:
                print("🚨 Many tests failing - need investigation")

        # Show key error types
        const_errors = sum(1 for line in output_lines if "Cannot assign to constant variable" in line)
        runtime_errors = sum(1 for line in output_lines if "RuntimeError" in line)
        segfaults = sum(1 for line in output_lines if "segmentation fault" in line)

        print(f"\n=== Error Analysis ===")
        if segfaults > 0:
            print(f"💥 Segmentation faults: {segfaults} (CRITICAL - memory corruption)")
        if const_errors > 0:
            print(f"🔒 Const assignment errors: {const_errors} (language semantic issues)")
        if runtime_errors > 0:
            print(f"⚠️  Runtime errors: {runtime_errors} (feature not implemented)")

        if segfaults == 0:
            print("✅ No memory corruption detected!")

    except subprocess.TimeoutExpired:
        print("❌ Test suite timed out")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error running test suite: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
