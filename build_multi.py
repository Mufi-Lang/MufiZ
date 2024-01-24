import subprocess
import os

codename = "zula"

def rename_file(old_name, new_name):
    try:
        os.rename(old_name, new_name)
        print(f"File '{old_name}' renamed to '{new_name}' successfully.")
    except FileNotFoundError:
        print(f"Error: File '{old_name}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")


bin = "zig-out/bin/MufiZ"
targets = [
    "aarch64-macos", 
    "aarch64-linux", 
    "x86_64-linux-gnu", 
    "x86_64-linux-musl", 
#    "x86_64-windows-msvc", 
]


for target in targets: 
    command = "zig build -Dtarget=" + target
    subprocess.run(command, shell=True, text=True)
    rename_file(bin, f'{bin}_{codename}_{target}')