import os
import subprocess

# ANSI escape codes for colors
class colors:
    SUCCESS = '\033[92m'  # Green
    ERROR = '\033[91m'    # Red
    END = '\033[0m'       # Reset

def run_test(num, test_file_path):
    try:
        # Run the test file
        subprocess.run(["zig", "build", "run", "--release=safe", "--", "-r", test_file_path], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"Test [{num}]:  {colors.SUCCESS}✔{colors.END} {test_file_path} {colors.SUCCESS}executed successfully{colors.END}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Test [{num}]:  {colors.ERROR}✘{colors.END} {test_file_path} {colors.ERROR}failed with error: {e}{colors.END}")
        return False

def run_tests_in_directory(directory):
    successful_tests = []
    failed_tests = []

    # Iterate through files in the directory
    for index, item in enumerate(os.listdir(directory)):
        item_path = os.path.join(directory, item)

        # If item is a directory, recursively run tests in it
        if os.path.isdir(item_path):
            subdir_successful_tests, subdir_failed_tests = run_tests_in_directory(item_path)
            successful_tests.extend(subdir_successful_tests)
            failed_tests.extend(subdir_failed_tests)
        # If item is a python file, treat it as a test file and run it
        elif item.endswith(".mufi"):
            test_file_path = os.path.relpath(item_path)
            if run_test(index+1, test_file_path):
                successful_tests.append(test_file_path)
            else:
                failed_tests.append(test_file_path)

    return successful_tests, failed_tests

def main():
    test_suite_directory = "test_suite"
    if not os.path.exists(test_suite_directory) or not os.path.isdir(test_suite_directory):
        print("Test suite directory not found.")
        return

    successful_tests, failed_tests = run_tests_in_directory(test_suite_directory)
    
    num_st = len(successful_tests)
    num_ft = len(failed_tests)
    total_num = num_ft + num_st

    print("\n=== Test Results ===")
    print(f"Successful tests: [{num_st}/{total_num}]")
    for test in successful_tests:
        print(f"=> {test}")
    print(f"\nFailed tests: [{num_ft}/{total_num}]")
    for test in failed_tests:
        print(f"=> {test}")

if __name__ == "__main__":
    main()
