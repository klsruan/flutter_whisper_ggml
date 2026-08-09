#include "include/flutter_whisper/flutter_whisper_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_whisper_plugin.h"

void FlutterWhisperPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_whisper::FlutterWhisperPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
