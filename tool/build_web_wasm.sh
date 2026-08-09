#!/usr/bin/env bash

set -euo pipefail

configuration="${1:-Release}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/.." && pwd)"
whisper_cpp_dir="${FLUTTER_WHISPER_CPP_DIR:-${plugin_root}/whisper/v1.9.2}"
configuration_dir="$(printf '%s' "${configuration}" | tr '[:upper:]' '[:lower:]')"
build_dir="${plugin_root}/build/web-wasm-emscripten/${configuration_dir}"
asset_dir="${plugin_root}/assets/web"

if [[ ! -f "${whisper_cpp_dir}/include/whisper.h" ]]; then
  echo "whisper.cpp was not found at '${whisper_cpp_dir}'." >&2
  exit 1
fi

for command_name in emcmake cmake ninja; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command '${command_name}' is not available." >&2
    exit 1
  fi
done

echo "Using bundled whisper.cpp source: ${whisper_cpp_dir}"
emcmake cmake \
  -G Ninja \
  -S "${plugin_root}/web" \
  -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE="${configuration}" \
  -DFLUTTER_WHISPER_CPP_DIR="${whisper_cpp_dir}" \
  -DWHISPER_WASM_SINGLE_FILE=OFF

cmake --build "${build_dir}" --config "${configuration}" --parallel

install -m 0644 "${build_dir}/flutter_whisper.js" "${asset_dir}/flutter_whisper.js"
install -m 0644 "${build_dir}/flutter_whisper.wasm" "${asset_dir}/flutter_whisper.wasm"

echo "WebAssembly artifacts copied to ${asset_dir}"
