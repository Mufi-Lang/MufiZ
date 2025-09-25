#!/usr/bin/env python3
import os
import subprocess
import logging


# ANSI escape codes for colors
class colors:
    SUCCESS = "\033[92m"  # Green
    ERROR = "\033[91m"  # Red
    INFO = "\033[94m"  # Blue
    SKIP = "\033[93m"  # Yellow
    END = "\033[0m"  # Reset


# Define a custom logging format
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def run_test(num, test_file_path):
    try:
        # Check if the test file is empty
        if os.path.getsize(test_file_path) == 0:
            logger.info(f"Test [{num}]: {test_file_path} is empty. Skipping...")
            return True, True

        # Run the test file with timeout to prevent hangs
        result = subprocess.run(
            ["./zig-out/bin/mufiz", "-r", test_file_path],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            logger.info(f"Test [{num}]: {test_file_path} executed successfully")
            if result.stdout.strip():
                logger.info(f"STDOUT: {result.stdout.strip()}")
            return True, False
        else:
            # Handle different types of errors
            if result.returncode == -11:  # SIGSEGV
                logger.error(f"Test [{num}]: {test_file_path} crashed with segmentation fault (memory corruption)")
            elif result.returncode == -6:  # SIGABRT
                logger.error(f"Test [{num}]: {test_file_path} aborted (assertion failure or panic)")
            else:
                logger.error(f"Test [{num}]: {test_file_path} failed with exit code {result.returncode}")

            if result.stderr.strip():
                logger.error(f"STDERR: {result.stderr.strip()}")
            if result.stdout.strip():
                logger.error(f"STDOUT: {result.stdout.strip()}")
            return False, False

    except subprocess.TimeoutExpired:
        logger.error(f"Test [{num}]: {test_file_path} timed out after 30 seconds")
        return False, False
    except Exception as e:
        logger.error(f"Test [{num}]: {test_file_path} failed with exception: {e}")
        return False, False


def flatten_directory(directory):
    flattened_files = []
    for item in os.listdir(directory):
        item_path = os.path.join(directory, item)
        if os.path.isdir(item_path):
            flattened_files.extend(flatten_directory(item_path))
        elif item.endswith(".mufi"):
            flattened_files.append(item_path)
    return flattened_files


def run_tests_in_directory(directory, skipped_tests):
    successful_tests = []
    failed_tests = []
    flattened_files = flatten_directory(directory)
    for index, test_file_path in enumerate(flattened_files):
        success, skipped = run_test(index + 1, test_file_path)
        if success:
            if skipped:
                skipped_tests.append(test_file_path)
            else:
                successful_tests.append(test_file_path)
        else:
            failed_tests.append(test_file_path)
    return successful_tests, failed_tests


def main():
    test_suite_directory = "test_suite"
    if not os.path.exists(test_suite_directory) or not os.path.isdir(
        test_suite_directory
    ):
        logger.error("Test suite directory not found.")
        return

    # Check if mufiz binary exists
    if not os.path.exists("./zig-out/bin/mufiz"):
        logger.error("MufiZ binary not found. Building...")
        build_result = subprocess.run(["zig", "build", "-Doptimize=ReleaseSafe", "-Dstress_gc=false"],
                                    capture_output=True, text=True)
        if build_result.returncode != 0:
            logger.error("Build failed:")
            logger.error(f"STDERR: {build_result.stderr}")
            return
        logger.info("Build completed successfully")
    else:
        logger.info("Found existing MufiZ binary")

    # Test basic functionality first
    logger.info("Testing basic MufiZ functionality...")
    basic_test_file = "basic_test_temp.mufi"
    try:
        with open(basic_test_file, "w") as f:
            f.write('print("Basic test");')

        basic_result = subprocess.run(
            ["./zig-out/bin/mufiz", "-r", basic_test_file],
            capture_output=True, text=True, timeout=10
        )

        if basic_result.returncode == 0:
            logger.info("✅ Basic functionality test passed")
        else:
            logger.error(f"❌ Basic functionality test failed with code {basic_result.returncode}")
            logger.error("The MufiZ interpreter has fundamental issues. All tests will likely fail.")
            logger.error(f"Error output: {basic_result.stderr}")

    except Exception as e:
        logger.error(f"Basic test setup failed: {e}")
    finally:
        if os.path.exists(basic_test_file):
            os.remove(basic_test_file)

    skipped_tests = []
    successful_tests, failed_tests = run_tests_in_directory(
        test_suite_directory, skipped_tests
    )

    num_st = len(successful_tests)
    num_ft = len(failed_tests)
    num_skipped = len(skipped_tests)
    total_num = num_ft + num_st + num_skipped

    print("\n=== Test Results ===")
    print(f"{colors.INFO}Successful tests: [{num_st}/{total_num}]{colors.END}")
    for test in successful_tests:
        print(f"{colors.SUCCESS}✔{colors.END} {test}")
    print(f"\n{colors.INFO}Failed tests: [{num_ft}/{total_num}]{colors.END}")
    for test in failed_tests:
        print(f"{colors.ERROR}✘{colors.END} {test}")
    print(f"\n{colors.INFO}Skipped tests: [{num_skipped}/{total_num}]{colors.END}")
    for test in skipped_tests:
        print(f"{colors.SKIP}SKIPPED: {test}{colors.END}")

    # Provide helpful debugging information
    if num_ft > 0:
        print(f"\n{colors.INFO}=== Debugging Information ==={colors.END}")
        if num_ft == total_num - num_skipped:
            print(f"{colors.ERROR}All tests failed - this suggests a fundamental issue with the MufiZ interpreter{colors.END}")
            print("Common causes:")
            print("- Memory corruption in the VM or garbage collector")
            print("- String handling bugs")
            print("- Zig version compatibility issues")
            print("- Build configuration problems")
            print("\nTry:")
            print("1. zig build -Doptimize=Debug -Dstress_gc=false")
            print("2. Run individual tests with gdb to get stack traces")
            print("3. Check for memory leaks with valgrind")
        else:
            print(f"{colors.INFO}Some tests passed - the issue may be with specific language features{colors.END}")
            print("Try examining the differences between passing and failing tests")


if __name__ == "__main__":
    main()
