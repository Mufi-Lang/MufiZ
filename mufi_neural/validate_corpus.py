import os
import random
import subprocess
import sys

from generate_type_aware import TypeAwareGenerator as CodeGenerator

COMPILER_PATH = "../zig-out/bin/mufiz"
CORPUS_FILE = "corpus/smart_corpus.txt"
TEMP_FILE = "temp_program.mufi"


def ensure_corpus_dir():
    if not os.path.exists("corpus"):
        os.makedirs("corpus")


def validate_program(code):
    with open(TEMP_FILE, "w") as f:
        f.write(code)

    try:
        # Run with full stdlib so all builtin functions are available.
        result = subprocess.run(
            [COMPILER_PATH, "--full-stdlib", "--run", TEMP_FILE],
            capture_output=True,
            text=True,
            timeout=5,
        )

        output = result.stdout + result.stderr
        # Treat non-zero exit, RuntimeError, or compile errors as failures.
        if result.returncode != 0:
            return False, output
        if "RuntimeError" in output or "CompileError" in output or "Compilation failed" in output:
            return False, output
        return True, ""
    except subprocess.TimeoutExpired:
        return False, "Timeout (likely infinite loop)"
    except Exception as e:
        print(f"Error running compiler: {e}")
        return False, str(e)


def generate_and_validate(count=100):
    ensure_corpus_dir()
    gen = CodeGenerator()
    valid_count = 0
    failures_printed = 0

    with open(CORPUS_FILE, "a") as corpus:
        for i in range(count):
            # Reduce complexity to avoid "Too many constants" error
            code = gen.generate_program(num_statements=random.randint(3, 6))
            is_valid, error_msg = validate_program(code)

            if is_valid:
                corpus.write(code + "\n\n# ---\n\n")
                valid_count += 1
                print(f"\rValid: {valid_count}/{i + 1}", end="")
            else:
                if failures_printed < 5:
                    print(f"\n--- FAILED PROGRAM {failures_printed + 1} ---")
                    print(code)
                    print("--- ERROR ---")
                    print(error_msg)
                    print("-----------------------------")
                    failures_printed += 1

    print(f"\nGenerated {valid_count} valid programs out of {count}.")
    if os.path.exists(TEMP_FILE):
        os.remove(TEMP_FILE)


if __name__ == "__main__":
    if not os.path.exists(COMPILER_PATH):
        print(f"Compiler not found at {COMPILER_PATH}. Please build it first.")
        sys.exit(1)

    generate_and_validate(1000)
