import subprocess
import os
import zipfile
import json
import shutil
import glob

version = "0.4.0"
out_path = "zig-out/bin/"
windows = f"{out_path}mufiz.exe"
bin = "zig-out/bin/mufiz"

with open('targets.json', 'r') as file:
    data = json.load(file)

targets = data['targets']

for target in targets: 
    command = f"zig build -Doptimize=ReleaseSafe -Dtarget={target}"
    subprocess.run(command, shell=True, text=True)
    if("x86_64-windows" in target or "aarch64-windows" in target):
        windows_zip = f"mufiz_{version}_{target}.zip"
        with zipfile.ZipFile(out_path+windows_zip, 'w') as wz: 
            wz.write(windows, os.path.basename(windows))
        os.remove(windows)
        print(f"Zipped successfully {windows_zip}")
    else: 
        zipper = f"mufiz_{version}_{target}.zip"
        with zipfile.ZipFile(out_path+zipper, 'w') as z: 
            z.write(bin, os.path.basename(bin))
        os.remove(bin)
        print(f"Zipped successfully {zipper}")
os.remove(out_path+"mufiz.pdb")

# Build debian packages for Linux targets 
for target in targets: 
    if ("x86_64-linux" in target): 
        command = f"fpm -v {version} -a amd64 -s zip -t deb --prefix /usr/bin -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
        subprocess.run(command, shell=True, text=True)
        print(f"Built debian package for {target}")
    elif ("aarch64-linux" in target):
        command = f"fpm -v {version} -a arm64 -s zip -t deb --prefix /usr/bin -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
        subprocess.run(command, shell=True, text=True)
        print(f"Built debian package for {target}")

deb = glob.glob("*.deb")
for d in deb: 
    shutil.move(d, out_path+d)
    print(f"Moved {d} to {out_path}")