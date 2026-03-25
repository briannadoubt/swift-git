#!/bin/zsh

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly WORK_ROOT="${WORK_ROOT:-$ROOT_DIR/.build/libgit2-apple}"
readonly SOURCE_DIR="${SOURCE_DIR:-$WORK_ROOT/libgit2-src}"
readonly HEADERS_DIR="$WORK_ROOT/headers"
readonly OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/Vendor/Clibgit2Binary.xcframework}"
readonly LIBGIT2_VERSION="${LIBGIT2_VERSION:-1.9.2}"
readonly LIBGIT2_REF="${LIBGIT2_REF:-v$LIBGIT2_VERSION}"
readonly MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-15.0}"
readonly IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-18.0}"
readonly VISIONOS_DEPLOYMENT_TARGET="${VISIONOS_DEPLOYMENT_TARGET:-2.0}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_command git
require_command cmake
require_command xcodebuild
require_command rsync
require_command xcrun

mkdir -p "$WORK_ROOT"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    git clone --depth 1 --branch "$LIBGIT2_REF" https://github.com/libgit2/libgit2 "$SOURCE_DIR"
else
    git -C "$SOURCE_DIR" fetch --depth 1 origin "$LIBGIT2_REF"
    git -C "$SOURCE_DIR" checkout --detach "$LIBGIT2_REF"
fi

git -C "$SOURCE_DIR" submodule update --init --depth 1

mkdir -p "$HEADERS_DIR"
rsync -a --delete "$SOURCE_DIR/include/" "$HEADERS_DIR/"
cat > "$HEADERS_DIR/libgit2_shim.h" <<'EOF'
#include <git2.h>
EOF
cat > "$HEADERS_DIR/module.modulemap" <<'EOF'
module Clibgit2Binary [system] {
    header "libgit2_shim.h"
    export *
}
EOF

build_slice() {
    local name="$1"
    local system_name="$2"
    local system_version="$3"
    local sysroot="$4"
    local architectures="$5"
    local build_dir="$WORK_ROOT/build-$name"
    local config_dir="Release-$sysroot"
    local package_dir="$build_dir/build/libgit2package.build/$config_dir"
    local output_dir="$package_dir/liblibgit2.a"
    local -a extra_args=()

    if [[ "$sysroot" == "macosx" ]]; then
        config_dir="Release"
        package_dir="$build_dir/build/libgit2package.build/$config_dir"
        output_dir="$package_dir/liblibgit2.a"
        extra_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$system_version")
    fi

    cmake \
        -S "$SOURCE_DIR" \
        -B "$build_dir" \
        -G Xcode \
        -DCMAKE_SYSTEM_NAME="$system_name" \
        -DCMAKE_SYSTEM_VERSION="$system_version" \
        -DCMAKE_OSX_SYSROOT="$sysroot" \
        -DCMAKE_OSX_ARCHITECTURES="$architectures" \
        "${extra_args[@]}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_FUZZERS=OFF \
        -DUSE_GSSAPI=OFF \
        -DUSE_SSH=OFF \
        -DUSE_BUNDLED_ZLIB=ON \
        -DUSE_HTTPS=SecureTransport >&2

    cmake \
        --build "$build_dir" \
        --config Release \
        --target libgit2 util llhttp ntlmclient xdiff zlib >&2

    mkdir -p "$package_dir"

    # The Xcode generator does not emit libgit2package reliably, so build the
    # upstream package archive by merging libgit2 with its bundled object libs.
    xcrun libtool -static -o "$output_dir" \
        "$build_dir/build/libgit2.build/$config_dir/liblibgit2.a" \
        "$build_dir/build/util.build/$config_dir/libutil.a" \
        "$build_dir/build/llhttp.build/$config_dir/libllhttp.a" \
        "$build_dir/build/ntlmclient.build/$config_dir/libntlmclient.a" \
        "$build_dir/build/xdiff.build/$config_dir/libxdiff.a" \
        "$build_dir/build/zlib.build/$config_dir/libzlib.a" >&2

    echo "$output_dir"
}

readonly MACOS_LIBRARY="$(build_slice macos Darwin "$MACOS_DEPLOYMENT_TARGET" macosx "arm64;x86_64")"
readonly IOS_DEVICE_LIBRARY="$(build_slice ios-device iOS "$IOS_DEPLOYMENT_TARGET" iphoneos arm64)"
readonly IOS_SIMULATOR_LIBRARY="$(build_slice ios-simulator iOS "$IOS_DEPLOYMENT_TARGET" iphonesimulator arm64)"
readonly VISIONOS_DEVICE_LIBRARY="$(build_slice visionos-device Darwin "$VISIONOS_DEPLOYMENT_TARGET" xros arm64)"
readonly VISIONOS_SIMULATOR_LIBRARY="$(build_slice visionos-simulator Darwin "$VISIONOS_DEPLOYMENT_TARGET" xrsimulator arm64)"

rm -rf "$OUTPUT_PATH"

xcodebuild -create-xcframework \
    -library "$MACOS_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$IOS_DEVICE_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$IOS_SIMULATOR_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$VISIONOS_DEVICE_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$VISIONOS_SIMULATOR_LIBRARY" -headers "$HEADERS_DIR" \
    -output "$OUTPUT_PATH"

echo "Created $OUTPUT_PATH"
