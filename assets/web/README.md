# WebAssembly assets

The pub.dev package includes the Emscripten loader and compiled WebAssembly
runtime. The JavaScript worker loads both assets at runtime.

The CI builds the loader and WASM binary using `tool/build_web_wasm.sh`.
Maintainers can also regenerate them locally using `tool/build_web_wasm.ps1`.

The worker and compiled assets use a shared cancellation flag and a pthread
pool. Serve them from a cross-origin-isolated page. Keep the worker, loader,
and binary from the same build together when deploying a new runtime.

The Dart model manager verifies and caches catalog models before handing a
temporary object URL to the worker. Application assets and arbitrary model
URLs can also be loaded directly.
