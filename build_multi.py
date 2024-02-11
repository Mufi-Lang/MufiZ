import subprocess
import os
import zipfile
import json

codename = "voxl"
out_path = "zig-out/bin/"
windows = f"{out_path}mufiz.exe"
bin = "zig-out/bin/mufiz"

with open('targets.json', 'r') as file:
    data = json.load(file)

targets = data['targets']

for target in targets: 
    command = "zig build -Doptimize=ReleaseSafe -Dtarget=" + target
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