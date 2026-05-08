#!/usr/bin/env bash
set -euo pipefail

LLAMA_VERSION="v0.9.0-dev.6"
BASE_URL="https://github.com/netdur/llama_cpp_dart/releases/download/${LLAMA_VERSION}"

fetch_android_aar() {
  local dest="android/app/libs/llama-cpp-dart.aar"
  if [ -f "$dest" ]; then
    echo "  android AAR already present, skipping"
    return
  fi
  mkdir -p android/app/libs
  echo "  downloading llama-cpp-dart.aar..."
  curl -fL -o "$dest" "${BASE_URL}/llama-cpp-dart.aar"
  echo "  done: $dest"
}

fetch_ios_xcframework() {
  local dest="ios/Frameworks/llama.xcframework"
  if [ -d "$dest" ]; then
    echo "  iOS xcframework already present, skipping"
    return
  fi
  mkdir -p ios/Frameworks
  echo "  downloading llama.xcframework..."
  curl -fL -o llama-xcframework.zip "${BASE_URL}/llama-xcframework.zip"
  unzip -q llama-xcframework.zip -d ios/Frameworks/
  rm llama-xcframework.zip
  test -d "$dest" || { echo "ERROR: xcframework not found after unzip"; exit 1; }
  echo "  done: $dest"
}

echo "==> Fetching native LLM binaries (${LLAMA_VERSION})"
fetch_android_aar
fetch_ios_xcframework
echo "==> Done. Run 'flutter pub get' then 'cd ios && pod install'."
