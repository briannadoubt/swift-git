#!/bin/zsh

set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly WORK_ROOT="${WORK_ROOT:-$ROOT_DIR/.build/libgit2-apple}"
readonly SOURCE_DIR="${SOURCE_DIR:-$WORK_ROOT/libgit2-src}"
readonly HEADERS_DIR="$WORK_ROOT/headers"
readonly OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/Vendor/Clibgit2Binary.xcframework}"
readonly LIBGIT2_VERSION="${LIBGIT2_VERSION:-1.9.2}"
readonly LIBGIT2_REF="${LIBGIT2_REF:-v$LIBGIT2_VERSION}"
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
    local output_dir="$build_dir/build/libgit2.build/Release-$sysroot"

    cmake \
        -S "$SOURCE_DIR" \
        -B "$build_dir" \
        -G Xcode \
        -DCMAKE_SYSTEM_NAME="$system_name" \
        -DCMAKE_SYSTEM_VERSION="$system_version" \
        -DCMAKE_OSX_SYSROOT="$sysroot" \
        -DCMAKE_OSX_ARCHITECTURES="$architectures" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_FUZZERS=OFF \
        -DUSE_GSSAPI=OFF \
        -DUSE_SSH=OFF \
        -DUSE_BUNDLED_ZLIB=ON \
        -DUSE_HTTPS=SecureTransport >&2

    cmake --build "$build_dir" --config Release --target libgit2 >&2
    echo "$output_dir/liblibgit2.a"
}

readonly IOS_DEVICE_LIBRARY="$(build_slice ios-device iOS "$IOS_DEPLOYMENT_TARGET" iphoneos arm64)"
readonly IOS_SIMULATOR_LIBRARY="$(build_slice ios-simulator iOS "$IOS_DEPLOYMENT_TARGET" iphonesimulator arm64)"
readonly VISIONOS_DEVICE_LIBRARY="$(build_slice visionos-device Darwin "$VISIONOS_DEPLOYMENT_TARGET" xros arm64)"
readonly VISIONOS_SIMULATOR_LIBRARY="$(build_slice visionos-simulator Darwin "$VISIONOS_DEPLOYMENT_TARGET" xrsimulator arm64)"

xcodebuild -create-xcframework \
    -library "$IOS_DEVICE_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$IOS_SIMULATOR_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$VISIONOS_DEVICE_LIBRARY" -headers "$HEADERS_DIR" \
    -library "$VISIONOS_SIMULATOR_LIBRARY" -headers "$HEADERS_DIR" \
    -output "$OUTPUT_PATH"

echo "Created $OUTPUT_PATH"
