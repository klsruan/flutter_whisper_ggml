#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
fixtures=build/web-test-fixtures
mkdir -p "$fixtures"

curl -fsSL --retry 3 \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin \
  -o "$fixtures/ggml-tiny.en-q5_1.bin"
curl -fsSL --retry 3 \
  https://raw.githubusercontent.com/ggml-org/whisper.cpp/v1.9.5/samples/jfk.wav \
  -o "$fixtures/jfk.wav"
(
  cd "$fixtures"
  sha256sum --check <<'EOF'
c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b  ggml-tiny.en-q5_1.bin
59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e  jfk.wav
EOF
)

site="$PWD/build/web-smoke/site"
(
  cd example
  flutter build web --release --no-web-resources-cdn \
    --target ../tool/web_whisper_smoke.dart --output "$site"
)
node tool/web_whisper_smoke.mjs "$site" "$fixtures" \
  "$(mktemp -d "$PWD/build/web-smoke/chrome.XXXXXX")"
