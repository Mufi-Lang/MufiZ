import subprocess
import os
import zipfile
import json
import shutil
import glob
import time
from multiprocessing.pool import ThreadPool

version = "0.6.0"
out_path = "zig-out/bin/"
windows = f"{out_path}mufiz.exe"
bin = "zig-out/bin/mufiz"
wasm_bin = "zig-out/bin/mufiz.wasm"


class PackageBuilder:
    def __init__(self, version, out_path):
        self.version = version
        self.out_path = out_path
        self.data = self.load_targets()

    def load_targets(self):
        with open("targets.json", "r") as file:
            return json.load(file)["targets"]

    def command_str(self, arch, target, pkg):
        return f"fpm -v {self.version} -a {arch} -s zip -t {pkg} --prefix /usr/bin -m 'Mustafif0929@gmail.com' --description 'The Mufi Programming Language' -n mufiz ./zig-out/bin/mufiz_{self.version}_{target}.zip "

    def build_package(self, arch, target, pkg):
        command = self.command_str(arch, target, pkg)
        subprocess.run(command, shell=True, text=True)
        if pkg == "deb":
            shutil.move(
                f"mufiz_{self.version}_{arch}.{pkg}",
                f"mufiz_{self.version}_{target}.{pkg}",
            )
        elif pkg == "rpm":
            shutil.move(
                f"mufiz-{self.version}-1.{arch}.{pkg}",
                f"mufiz_{self.version}_{target}.{pkg}",
            )
        print(f"Built {pkg} package for {target}")

    def build_target(self, target):
        command = ""
        if target != "wasm32-wasi":
            command = f"zig build -Doptimize=ReleaseSafe -Dtarget={target}"
        else:
            command = f"zig build -Doptimize=ReleaseSmall -Dtarget={target} -Denable_net=false -Denable_fs=false -Dsandbox=true"
        subprocess.run(command, shell=True, text=True)
        if "windows" in target:
            windows_zip = f"mufiz_{self.version}_{target}.zip"
            with zipfile.ZipFile(self.out_path + windows_zip, "w") as wz:
                wz.write(windows, os.path.basename(windows))
            if os.path.exists(windows):
                os.remove(windows)
            print(f"Zipped successfully {windows_zip}")
        elif "wasm32-wasi" in target:
            zipper = f"mufiz_{self.version}_{target}.zip"
            with zipfile.ZipFile(self.out_path + zipper, "w") as z:
                z.write(wasm_bin, os.path.basename(wasm_bin))
            os.remove(wasm_bin)
        else:
            zipper = f"mufiz_{self.version}_{target}.zip"
            with zipfile.ZipFile(self.out_path + zipper, "w") as z:
                z.write(bin, os.path.basename(bin))
            os.remove(bin)
            print(f"Zipped successfully {zipper}")
        time.sleep(5)

    def build_linux_pkg(self, target):
        arch_map_deb = {
            "x86_64-linux": "amd64",
            "aarch64-linux": "arm64",
            # "arm-linux": "arm",
            "mips64-linux-musl": "mips64",
            "mips64el-linux-musl": "mips64el",
            "mipsel-linux-musl": "mipsel",
            "mips-linux-musl": "mips",
            "powerpc64-linux": "powerpc64",
            "powerpc64le-linux": "powerpc64le",
            "powerpc-linux": "powerpc",
            "riscv64-linux": "riscv64",
        }

        arch_map_rpm = {
            "x86_64-linux": "x86_64",
            "aarch64-linux": "aarch64",
            # "arm-linux": "arm",
            "mips64-linux-musl": "mips64",
            "mips64el-linux-musl": "mips64el",
            "mipsel-linux-musl": "mipsel",
            "mips-linux-musl": "mips",
            "powerpc64-linux": "ppc64",
            "powerpc64le-linux": "ppc64le",
            "powerpc-linux": "ppc",
            "riscv64-linux": "riscv64",
        }

        if target in (tuple(arch_map_deb.keys())):
            deb_arch = arch_map_deb[target]
            rpm_arch = arch_map_rpm[target]
            self.build_package(deb_arch, target, "deb")
            self.build_package(rpm_arch, target, "rpm")

    def build_packages(self):
        # Create a thread pool with a maximum of 2 threads
        pool = ThreadPool(2)

        # Use the thread pool to concurrently build two targets at a time
        pool.map(self.build_target, self.data)

        # Close the thread pool and wait for all threads to complete
        pool.close()
        pool.join()

        if os.path.exists(self.out_path + "mufiz.pdb"):
            os.remove(self.out_path + "mufiz.pdb")

        for target in self.data:
            self.build_linux_pkg(target)

        deb = glob.glob("*.deb")
        for d in deb:
            shutil.move(d, self.out_path + d)
            print(f"Moved {d} to {self.out_path}")

        rpm = glob.glob("*.rpm")
        for r in rpm:
            shutil.move(r, self.out_path + r)
            print(f"Moved {r} to {self.out_path}")


if __name__ == "__main__":
    builder = PackageBuilder(version, out_path)
    builder.build_packages()
