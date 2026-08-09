export 'platform_runtime_stub.dart'
    if (dart.library.io) 'platform_runtime_native.dart'
    if (dart.library.js_interop) 'platform_runtime_web.dart';
