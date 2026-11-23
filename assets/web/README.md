# WebAssembly assets

The pub.dev package includes the Emscripten loader and compiled WebAssembly
runtime. The JavaScript worker loads both assets at runtime.

The CI builds the loader and WASM binary using `tool/build_web_wasm.sh`.
Maintainers can also regenerate them locally using `tool/build_web_wasm.ps1`.

GGML model files are application assets or remote URLs.
