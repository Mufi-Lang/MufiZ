import subprocess
import os
import zipfile
import shutil

codename = "voxl"
out_path = "zig-out/bin/"
windows = f"{out_path}mufiz.exe"
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
        windows_zip = f"mufiz_{codename}_{target}.zip"
        with zipfile.ZipFile(out_path+windows_zip, 'w') as wz: 
            wz.write(windows, os.path.basename(windows))
        os.remove(windows)
        print(f"Zipped successfully {windows_zip}")
    else: 
        zipper = f"mufiz_{codename}_{target}.zip"
        with zipfile.ZipFile(out_path+zipper, 'w') as z: 
            z.write(bin, os.path.basename(bin))
        os.remove(bin)
        print(f"Zipped successfully {zipper}")
os.remove(out_path+"mufiz.pdb")