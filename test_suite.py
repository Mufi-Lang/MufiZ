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

        # Run the test file
        subprocess.run(
            ["./zig-out/bin/mufiz", "-r", test_file_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        logger.info(f"Test [{num}]: {test_file_path} executed successfully")
        return True, False
    except subprocess.CalledProcessError as e:
        # Log the error along with stdout and stderr
        logger.error(f"Test [{num}]: {test_file_path} failed with error: {e}")
        logger.error(f"STDERR:\n{e.stderr.decode('utf-8')}")
        return False, False

    # Iterate through files in the directory


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

    skipped_tests = []
    subprocess.run(["zig", "build"])
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


if __name__ == "__main__":
    main()
