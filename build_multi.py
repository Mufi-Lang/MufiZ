import subprocess
import os
import zipfile
import shutil

codename = "iris"
out_path = "zig-out/bin/"
def rename_file(old_name, new_name):
    try:
        shutil.move(old_name, new_name)
        print(f"File '{old_name}' renamed to '{new_name}' successfully.")
    except FileNotFoundError:
        print(f"Error: File '{old_name}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

bin = "zig-out/bin/mufiz"
targets = [
    "aarch64-macos", 
    "x86_64-macos", 
    "aarch64-linux-gnu",
    "aarch64-linux-musl",  
    # "riscv32-linux-musl",  
    # "riscv64-linux-gnu",
    # "riscv64-linux-musl", 
    "x86_64-linux-gnu", 
    "x86_64-linux-musl", 
    "x86_64-windows", 
    "aarch64-windows", 
]


for target in targets: 
    command = "zig build -Doptimize=ReleaseFast -Dtarget=" + target
    subprocess.run(command, shell=True, text=True)
    if(target == "x86_64-windows" or target == "aarch64-windows"):
        windows =  f'{bin}_{codename}_{target}'+".exe"
        rename_file(bin+".exe", windows)
        windows_zip = f"mufiz_{codename}_{target}.zip"
        with zipfile.ZipFile(out_path+windows_zip, 'w') as wz: 
            wz.write(windows, os.path.basename(windows))
        os.remove(windows)
        print(f"Zipped successfully {windows_zip}")
    else: 
        rename_file(bin, f'{bin}_{codename}_{target}')
os.remove(out_path+"mufiz.pdb")