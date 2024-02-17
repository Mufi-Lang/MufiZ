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
amd64_rpm = f"mufiz_{version}_amd64.rpm"
arm64_rpm = f"mufiz_{version}_arm64.rpm"

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
    
def build_rpm_x86_64(target): 
    command = f"fpm -v {version} -a amd64 -s zip -t rpm --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(amd64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    
def build_rpm_arm(target):
    command = f"fpm -v {version} -a arm64 -s zip -t rpm --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    


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
    elif("wasm32-wasi" in target):
        zipper = f"mufiz_{version}_{target}.zip"
        with zipfile.ZipFile(out_path+zipper, 'w') as z:
            z.write(wasm_bin, os.path.basename(wasm_bin))
        os.remove(wasm_bin)
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
        build_deb_x86_64(target)
        build_rpm_x86_64(target)
    elif ("aarch64-linux" in target):
        build_deb_arm(target)
        build_rpm_arm(target)
        
deb = glob.glob("*.deb")
for d in deb: 
    shutil.move(d, out_path+d)
    print(f"Moved {d} to {out_path}")

rpm = glob.glob("*.rpm")
for r in rpm: 
    shutil.move(r, out_path+r)
    print(f"Moved {r} to {out_path}")
