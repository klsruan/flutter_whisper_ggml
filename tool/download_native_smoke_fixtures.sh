#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
directory=build/native-smoke-fixtures
mkdir -p "$directory"
cd "$directory"

download() {
  local url="$1" file="$2" hash="$3"
  curl -fsSL --retry 3 "$url" -o "$file"
  echo "$hash  $file" | sha256sum --check
}

models=https://huggingface.co/ggerganov/whisper.cpp/resolve/main
download "$models/ggml-tiny-q5_1.bin" ggml-tiny-q5_1.bin \
  818710568da3ca15689e31a743197b520007872ff9576237bda97bd1b469c3d7
download "$models/ggml-tiny.en-q5_1.bin" ggml-tiny.en-q5_1.bin \
  c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b
download https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin \
  ggml-silero-v6.2.0.bin 2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987
download https://raw.githubusercontent.com/ggml-org/whisper.cpp/v1.9.5/samples/jfk.wav \
  jfk.wav 59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e
