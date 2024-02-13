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
wasm_bin = "zig-out/bin/mufiz.wasm"
arm64_deb = f"mufiz_{version}_arm64.deb"
amd64_deb = f"mufiz_{version}_amd64.deb"
amd64_snap = f"mufiz_{version}_amd64.snap"
arm64_snap = f"mufiz_{version}_arm64.snap"

def build_deb_x86_64(target): 
    command = f"fpm -v {version} -a amd64 -s zip -t deb --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(amd64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_arm(target): 
    command = f"fpm -v {version} -a arm64 -s zip -t deb --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_snap_x86_64(target):
    command = f"fpm -v {version} -a amd64 -s zip -t snap --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(amd64_snap, f"mufiz_{version}_{target}.snap")
    print(f"Built snap package for {target}")

def build_snap_arm(target):
    command = f"fpm -v {version} -a arm64 -s zip -t snap --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm64_snap, f"mufiz_{version}_{target}.snap")
    print(f"Built snap package for {target}")

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
            if target == "wasm32-wasi": 
                bin = wasm_bin
            z.write(bin, os.path.basename(bin))
        os.remove(bin)
        print(f"Zipped successfully {zipper}")
os.remove(out_path+"mufiz.pdb")

# Build debian and snap packages for Linux targets 
for target in targets: 
    if ("x86_64-linux" in target): 
        build_deb_x86_64(target)
        build_snap_x86_64(target)
    elif ("aarch64-linux" in target):
        build_deb_arm(target)
        build_snap_arm(target)
        
deb = glob.glob("*.deb")
for d in deb: 
    shutil.move(d, out_path+d)
    print(f"Moved {d} to {out_path}")
    
snap = glob.glob("*.snap")
for s in snap: 
    shutil.move(s, out_path+s)
    print(f"Moved {s} to {out_path}")