import subprocess
import os

codename = "iris"

def rename_file(old_name, new_name):
    try:
        os.rename(old_name, new_name)
        print(f"File '{old_name}' renamed to '{new_name}' successfully.")
    except FileNotFoundError:
        print(f"Error: File '{old_name}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

bin = "zig-out/bin/mufiz"
targets = [
    "aarch64-macos", 
    "x86_64-macos", 
    "aarch64-linux", 
    "x86_64-linux-gnu", 
    "x86_64-linux-musl", 
    "x86_64-windows"
]


for target in targets: 
    command = "zig build -Dtarget=" + target
    subprocess.run(command, shell=True, text=True)
    if(target == "x86_64-windows"):
        rename_file(bin+".exe", f'{bin}_{codename}_{target}'+".exe")
    else: 
        rename_file(bin, f'{bin}_{codename}_{target}')