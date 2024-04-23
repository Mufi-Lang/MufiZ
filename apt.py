import os
import shutil
import gzip


def generate_metadata(directory):
    packages_file_path = os.path.join(directory, "Packages")
    with open(packages_file_path, "w") as packages_file:
        for deb_file in os.listdir(directory):
            if deb_file.endswith(".deb"):
                deb_path = os.path.join(directory, deb_file)
                control_info = os.popen('dpkg -I "{}"'.format(deb_path)).read()
                packages_file.write(control_info)
                packages_file.write("\n")

    # Create Packages.gz
    with open(packages_file_path, "rb") as f_in:
        with gzip.open(os.path.join(directory, "Packages.gz"), "wb") as f_out:
            f_out.writelines(f_in)


def generate_release_file(directory):
    release_info = """Origin: MufiZ
Label: MufiZ
Suite: stable
Version: 0.6
Codename: stable
Architectures: amd64 arm64 mipsel mips64el mips64 mips powerpc powerpc64 powerpc64le riscv64
Components: main
Description: MufiZ Compiler
"""

    with open(os.path.join(directory, "Release"), "w") as release_file:
        release_file.write(release_info)


def main():
    repo_directory = "apt-repo"
    pkg_directory = os.path.join(repo_directory, "dists", "stable", "main")

    # Create necessary directories
    os.makedirs(pkg_directory, exist_ok=True)

    # Copy .deb files to the package directory
    for deb_file in os.listdir("pkg"):
        if deb_file.endswith(".deb"):
            os.rename(
                os.path.join("pkg", deb_file), os.path.join(pkg_directory, deb_file)
            )

    # Generate metadata files
    generate_metadata(pkg_directory)
    generate_release_file(repo_directory)


if __name__ == "__main__":
    main()
