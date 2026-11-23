Pod::Spec.new do |s|
  s.name             = 'flutter_whisper_ggml'
  s.version          = '0.1.0'
  s.summary          = 'Offline speech recognition powered by whisper.cpp.'
  s.description      = <<-DESC
Flutter FFI bindings for the bundled whisper.cpp runtime.
                       DESC
  s.homepage         = 'https://github.com/klsruan/flutter_whisper_ggml'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ruan Dias' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.vendored_frameworks = 'flutter_whisper_ggml_native.xcframework'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.static_framework = true
  s.frameworks       = 'Accelerate'
  s.libraries        = 'c++'
  # Keep the bridge available to Dart's DynamicLibrary.process().
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-u,_fw_create -Wl,-export_dynamic'
  }
  s.resource_bundles = {
    'flutter_whisper_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end
