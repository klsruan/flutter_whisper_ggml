#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build/apple-native"
name=flutter_whisper_ggml_native
library="lib$name.a"

build_slice() {
  local sdk="$1" system="$2" minimum="$3" architecture="$4"
  local directory="$build/$sdk-$architecture"
  cmake -S "$root/src" -B "$directory" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME="$system" \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$minimum" \
    -DCMAKE_OSX_ARCHITECTURES="$architecture"
  cmake --build "$directory" --target flutter_whisper_plugin --parallel
  (
    cd "$directory"
    find . -name '*.a' ! -name "$library" -print > archives.txt
    xcrun libtool -static -o "$library" -filelist archives.txt
  )
}

make_universal() {
  local sdk="$1"
  mkdir -p "$build/$sdk"
  xcrun lipo -create "$build/$sdk-arm64/$library" "$build/$sdk-x86_64/$library" \
    -output "$build/$sdk/$library"
}

build_slice iphoneos iOS 13.0 arm64
build_slice iphonesimulator iOS 13.0 arm64
build_slice iphonesimulator iOS 13.0 x86_64
build_slice macosx Darwin 10.15 arm64
build_slice macosx Darwin 10.15 x86_64
make_universal iphonesimulator
make_universal macosx

# Build in a temporary directory so an existing XCFramework stays available
# if either xcodebuild command fails.
output="$(mktemp -d "$build/output.XXXXXX")"
mkdir -p "$output"/{ios,macos}
xcodebuild -create-xcframework \
  -library "$build/iphoneos-arm64/$library" \
  -library "$build/iphonesimulator/$library" \
  -output "$output/ios/$name.xcframework"
xcodebuild -create-xcframework \
  -library "$build/macosx/$library" \
  -output "$output/macos/$name.xcframework"
for platform in ios macos; do
  if [[ -e "$root/$platform/$name.xcframework" ]]; then
    mv "$root/$platform/$name.xcframework" "$output/previous-$platform.xcframework"
  fi
  mv "$output/$platform/$name.xcframework" "$root/$platform/"
done
