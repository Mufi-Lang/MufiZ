"""
This script is responsible for creating zip files, as well as generating the appropriate
Debian and RPM packages.

- The `zipper` method will read the `targets.json` file and create zip files for each target, with
the following naming convention: `mufiz_{version}_{target}.zip`.

- The `build_package` method will create the Debian and RPM packages using the
`fpm` tool for given target.

Note: This script requires the necessary dependencies and tools installed on the system
for creating Debian and RPM packages.

- To create the Debian package, you need to have the `dpkg` tool installed.
- To create the RPM package, you need to have the `rpm` tool installed.

Author: Mustafif Khan
"""

import subprocess
import os
import json
import shutil
import zipfile
import re

out_path = "zig-out/"
pkg_path = "pkg/"

def extract_version():
    # Regular expression to find the version
    version_pattern = r'\.version\s*=\s*"([\d.]+)"'
    data = ""
    with open("build.zig.zon", "r") as file:
        data = file.read()

    # Search for the version in the data
    match = re.search(version_pattern, data)

    if match:
        return match.group(1)
    else:
        return None


version = extract_version()

arch_map_deb = {
    "x86_64-linux": "amd64",
    "x86-linux": "i386",
    "aarch64-linux": "arm64",
    "arm-linux": "arm",
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
    "x86-linux": "i386",
    "aarch64-linux": "aarch64",
    "arm-linux": "arm",
    "mips64-linux-musl": "mips64",
    "mips64el-linux-musl": "mips64el",
    "mipsel-linux-musl": "mipsel",
    "mips-linux-musl": "mips",
    "powerpc64-linux": "ppc64",
    "powerpc64le-linux": "ppc64le",
    "powerpc-linux": "ppc",
    "riscv64-linux": "riscv64",
}


def load_targets():
    with open("targets.json", "r") as file:
        return json.load(file)["targets"]


def command_str(arch, target, pkg):
    return f"fpm -v {version} -a {arch} -t {pkg} ./pkg/mufiz_{version}_{target}.zip "


def zipper():
    targets = load_targets()
    for target in targets:
        zip_file = f"mufiz_{version}_{target}.zip"
        with zipfile.ZipFile(pkg_path + zip_file, "w", zipfile.ZIP_DEFLATED) as z:
            target_path = out_path + target
            for root, _, files in os.walk(target_path):
                for file in files:
                    z.write(
                        os.path.join(root, file),
                        os.path.relpath(os.path.join(root, file), target_path),
                    )
        print(f"Zipped successfully {zip_file}")


def build_package(arch, target, pkg):
    command = command_str(arch, target, pkg)
    subprocess.run(command, shell=True, text=True)
    if pkg == "deb":
        shutil.move(
            f"mufiz_{version}_{arch}.{pkg}",
            f"{pkg_path}mufiz_{version}_{arch}.{pkg}",
        )
    elif pkg == "rpm":
        shutil.move(
            f"mufiz-{version}-1.{arch}.{pkg}",
            f"{pkg_path}mufiz-{version}-1.{arch}.{pkg}",
        )
    elif pkg == "pacman":
        shutil.move(
            f"mufiz-{version}-1-{arch}.pkg.tar.zst",
            f"{pkg_path}mufiz-{version}-1.{arch}.{pkg}",
        )
    print(f"Built {pkg} package for {target}")


if __name__ == "__main__":
    if not os.path.exists(pkg_path):
        os.makedirs(pkg_path)
    zipper()
    for target in load_targets():
        if target in tuple(arch_map_deb.keys()):
            arch_deb = arch_map_deb[target]
            build_package(arch_deb, target, "deb")
            arch_rpm = arch_map_rpm[target]
            build_package(arch_rpm, target, "rpm")
            build_package(arch_rpm, target, "pacman")
