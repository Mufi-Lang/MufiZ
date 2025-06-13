#!/usr/bin/env python3
import os
import sys
import re

def normalize_file(file_path):
    """
    Normalizes a .mufi file to prevent multi-line string scanning issues
    by removing any unintentional triple quote sequences.
    """
    try:
        with open(file_path, 'rb') as f:
            content = f.read()

        # Check for unusual byte sequences or potential encoding issues
        try:
            decoded = content.decode('utf-8')
        except UnicodeDecodeError:
            print(f"Warning: {file_path} has encoding issues, trying Latin-1")
            decoded = content.decode('latin-1')

        # Detect and fix potential triple-quote sequences
        # We're looking for sequences that aren't valid multi-line strings

        # Replace any instances where two double quotes might be followed by another
        # but aren't part of an intentional multi-line string
        fixed_content = re.sub(r'(?<!\\)""{1}(?!")', r'"\"', decoded)

        # Handle any remaining issues with quotes
        fixed_content = fixed_content.replace('"""', '\\"\\"\\"')

        # Normalize line endings to unix style
        fixed_content = fixed_content.replace('\r\n', '\n')

        # Ensure file ends with newline
        if not fixed_content.endswith('\n'):
            fixed_content += '\n'

        # Write normalized content back to file
        with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(fixed_content)

        return True
    except Exception as e:
        print(f"Error processing {file_path}: {str(e)}")
        return False

def process_directory(directory):
    """
    Recursively process all .mufi files in a directory.
    """
    normalized_count = 0
    failed_count = 0

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.mufi'):
                file_path = os.path.join(root, file)
                print(f"Normalizing {file_path}...", end='')
                if normalize_file(file_path):
                    print(" OK")
                    normalized_count += 1
                else:
                    print(" FAILED")
                    failed_count += 1

    return normalized_count, failed_count

def main():
    if len(sys.argv) < 2:
        print("Usage: python normalize_files.py <directory_or_file>")
        return 1

    path = sys.argv[1]

    if os.path.isdir(path):
        print(f"Processing directory: {path}")
        normalized, failed = process_directory(path)
        print(f"Normalized {normalized} files, {failed} failures")
    elif os.path.isfile(path) and path.endswith('.mufi'):
        print(f"Processing file: {path}")
        if normalize_file(path):
            print("Normalization successful")
        else:
            print("Normalization failed")
            return 1
    else:
        print("Invalid path or not a .mufi file")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
