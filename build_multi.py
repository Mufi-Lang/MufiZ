import subprocess
import os
import zipfile
import json
import shutil
import glob

version = "0.5.0"
out_path = "zig-out/bin/"
windows = f"{out_path}mufiz.exe"
bin = "zig-out/bin/mufiz"
wasm_bin = "zig-out/bin/mufiz.wasm"

arm64_deb = f"mufiz_{version}_arm64.deb"
amd64_deb = f"mufiz_{version}_amd64.deb"
arm_deb = f"mufiz_{version}_arm.deb"
mips64_deb = f"mufiz_{version}_mips64.deb"
mips64el_deb = f"mufiz_{version}_mips64el.deb"
mipsel_deb = f"mufiz_{version}_mipsel.deb"
mips_deb = f"mufiz_{version}_mips.deb"
powerpc64_deb = f"mufiz_{version}_powerpc64.deb"
powerpc64le_deb = f"mufiz_{version}_powerpc64le.deb"
powerpc_deb = f"mufiz_{version}_powerpc.deb"
riscv64_deb = f"mufiz_{version}_riscv64.deb"

amd64_rpm = f"mufiz-{version}-1.x86_64.rpm"
arm64_rpm = f"mufiz-{version}-1.aarch64.rpm"
arm_rpm = f"mufiz-{version}-1.arm.rpm"
mips64_rpm = f"mufiz-{version}-1.mips64.rpm"
mips64el_rpm = f"mufiz-{version}-1.mips64el.rpm"
mipsel_rpm = f"mufiz-{version}-1.mipsel.rpm"
mips_rpm = f"mufiz-{version}-1.mips.rpm"
powerpc64_rpm = f"mufiz-{version}-1.powerpc64.rpm"
powerpc64le_rpm = f"mufiz-{version}-1.powerpc64le.rpm"
powerpc_rpm = f"mufiz-{version}-1.powerpc.rpm"
riscv64_rpm = f"mufiz-{version}-1.riscv64.rpm"

def command_str(arch, target, pkg): 
    return f"fpm -v {version} -a {arch} -s zip -t {pkg} --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{version}_{target}.zip "

def build_deb_x86_64(target): 
    command = command_str("amd64", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(amd64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_arm64(target): 
    command = command_str("arm64", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_arm(target):
    command = command_str("arm", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_mips64(target):
    command = command_str("mips64", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_deb_mips64el(target):
    command = command_str("mips64el", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips64el_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_deb_mipsel(target):
    command = command_str("mipsel", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mipsel_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_deb_mips(target):
    command = command_str("mips", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_powerpc64(target):
    command = command_str("powerpc64", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_deb_powerpc64le(target):
    command = command_str("powerpc64le", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc64le_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")
    
def build_deb_powerpc(target):
    command = command_str("powerpc", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_deb_riscv64(target):
    command = command_str("riscv64", target, "deb")
    subprocess.run(command, shell=True, text=True)
    shutil.move(riscv64_deb, f"mufiz_{version}_{target}.deb")
    print(f"Built debian package for {target}")

def build_rpm_powerpc64(target):
    command = command_str("powerpc64", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_powerpc64le(target):
    command = command_str("powerpc64le", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc64le_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_powerpc(target):
    command = command_str("powerpc", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(powerpc_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_riscv64(target):
    command = command_str("riscv64", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(riscv64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    
def build_rpm_arm(target):
    command = command_str("arm", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(arm_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_mips64(target):
    command = command_str("mips64", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_mips64el(target):
    command = command_str("mips64el", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips64el_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")

def build_rpm_mipsel(target):
    command = command_str("mipsel", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mipsel_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    
def build_rpm_mips(target):
    command = command_str("mips", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(mips_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    
def build_rpm_x86_64(target): 
    command = command_str("amd64", target, "rpm")
    subprocess.run(command, shell=True, text=True)
    shutil.move(amd64_rpm, f"mufiz_{version}_{target}.rpm")
    print(f"Built rpm package for {target}")
    
def build_rpm_arm64(target):
    command = command_str("arm64", target, "rpm")
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
        build_deb_arm64(target)
        build_rpm_arm64(target)
    elif ("arm-linux" in target):
        build_deb_arm(target)
        build_rpm_arm(target)
    elif ("mips64-linux" in target):
        build_deb_mips64(target)
        build_rpm_mips64(target)
    elif ("mips64el-linux" in target):
        build_deb_mips64el(target)
        build_rpm_mips64el(target)
    elif ("mipsel-linux" in target):
        build_deb_mipsel(target)
        build_rpm_mipsel(target)
    elif ("mips-linux" in target):
        build_deb_mips(target)
        build_rpm_mips(target)
    elif ("powerpc64-linux" in target):
        build_deb_powerpc64(target)
        build_rpm_powerpc64(target)
    elif ("powerpc64le-linux" in target):
        build_deb_powerpc64le(target)
        build_rpm_powerpc64le(target)
    elif ("powerpc-linux" in target):
        build_deb_powerpc(target)
        build_rpm_powerpc(target)
    elif ("riscv64-linux" in target):
        build_deb_riscv64(target)
        build_rpm_riscv64(target)

        
deb = glob.glob("*.deb")
for d in deb: 
    shutil.move(d, out_path+d)
    print(f"Moved {d} to {out_path}")

rpm = glob.glob("*.rpm")
for r in rpm: 
    shutil.move(r, out_path+r)
    print(f"Moved {r} to {out_path}")
