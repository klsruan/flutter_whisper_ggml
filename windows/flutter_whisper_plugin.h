#ifndef FLUTTER_PLUGIN_FLUTTER_WHISPER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_WHISPER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_whisper {

class FlutterWhisperPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterWhisperPlugin();

  virtual ~FlutterWhisperPlugin();

  // Disallow copy and assign.
  FlutterWhisperPlugin(const FlutterWhisperPlugin&) = delete;
  FlutterWhisperPlugin& operator=(const FlutterWhisperPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_whisper

#endif  // FLUTTER_PLUGIN_FLUTTER_WHISPER_PLUGIN_H_
