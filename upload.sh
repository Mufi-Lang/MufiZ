#!/bin/bash

# Exit on error
set -e

# Supported OS distributions
debOS=("ubuntu/noble" "ubuntu/jammy" "debian/forky" "debian/trixie" "debian/bookworm")
rpmOS=( "fedora/41" "fedora/40" "fedora/39" "fedora/38" "opensuse/42.3")

# Constants
DOWNLOADS_DIR="./pkg"
PACKAGE_CLOUD_REPO="Mustafif/MufiZ"

# Print script usage information
print_usage() {
    echo "Usage: $0 -u <version>"
    echo "  -u <version>       Upload the specified MufiZ version"
    echo "  -h                 Print this usage information"
    exit 1
}

# Check if package_cloud is installed
check_dependencies() {
    if ! command -v package_cloud &> /dev/null; then
        echo "Error: package_cloud is not installed"
        echo "Please install it using: gem install package_cloud"
        exit 1
    fi
}

# Check if downloads directory exists and contains files
check_downloads() {
    local version=$1

    if [ ! -d "$DOWNLOADS_DIR" ]; then
        echo "Error: $DOWNLOADS_DIR directory does not exist"
        exit 1
    fi

    # Check for DEB files
    if ! compgen -G "$DOWNLOADS_DIR/mufiz_$version_*.deb" >/dev/null; then
        echo "Warning: No .deb files found for version $version"
    fi

    # Check for RPM files
    if ! compgen -G "$DOWNLOADS_DIR/mufiz-$version-*.rpm" >/dev/null; then
        echo "Warning: No .rpm files found for version $version"
    fi

    # # If neither file type exists, exit
    # if ! compgen -G "$DOWNLOADS_DIR/*$version*.{deb,rpm}" >/dev/null; then
    #     echo "Error: No .deb or .rpm files found for version $version in $DOWNLOADS_DIR"
    #     exit 1
    # fi
}

# Upload packages to PackageCloud
upload() {
    local version=$1
    local failed_uploads=()

    echo "Starting upload for version $version..."

    # Upload DEB packages
    for os in "${debOS[@]}"; do
        echo "Uploading .deb packages to $os..."
        for pkg in "$DOWNLOADS_DIR"/*"$version"*.deb; do
            # Check if glob expanded successfully
            if [ -f "$pkg" ]; then
                echo "Uploading $pkg to $os..."
                if ! package_cloud push "$PACKAGE_CLOUD_REPO/$os" "$pkg"; then
                    failed_uploads+=("$pkg -> $os")
                fi
            fi
        done
    done

    # Upload RPM packages
    for os in "${rpmOS[@]}"; do
        echo "Uploading .rpm packages to $os..."
        for pkg in "$DOWNLOADS_DIR"/*"$version"*.rpm; do
            # Check if glob expanded successfully
            if [ -f "$pkg" ]; then
                echo "Uploading $pkg to $os..."
                if ! package_cloud push "$PACKAGE_CLOUD_REPO/$os" "$pkg"; then
                    failed_uploads+=("$pkg -> $os")
                fi
            fi
        done
    done

    # Report results
    if [ ${#failed_uploads[@]} -eq 0 ]; then
        echo "Successfully uploaded all packages!"
    else
        echo "The following uploads failed:"
        printf '%s\n' "${failed_uploads[@]}"
        exit 1
    fi
}

main() {
    # Check dependencies first
    check_dependencies

    # Parse command line options
    while getopts ":hu:" opt; do
        case ${opt} in
            u )
                version=$OPTARG
                check_downloads "$version"
                upload "$version"
                ;;
            h )
                print_usage
                ;;
            \? )
                echo "Error: Invalid option: -$OPTARG" 1>&2
                print_usage
                ;;
            : )
                echo "Error: Option -$OPTARG requires an argument" 1>&2
                print_usage
                ;;
        esac
    done

    # Check if any options were provided
    if [ $OPTIND -eq 1 ]; then
        echo "Error: No options were passed"
        print_usage
    fi
}

# Run the script
main "$@"
