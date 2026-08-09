Pod::Spec.new do |s|
  s.name             = 'flutter_whisper_ggml'
  s.version          = '0.0.1'
  s.summary          = 'Offline speech recognition powered by whisper.cpp.'
  s.description      = <<-DESC
Flutter FFI bindings for the bundled whisper.cpp runtime.
                       DESC
  s.homepage         = 'https://github.com/klsruan/flutter_whisper_ggml'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ruan Dias' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,c,cc,cpp,m,mm}'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'Accelerate'
  s.libraries        = 'c++'
  s.resource_bundles = {
    'flutter_whisper_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }

  source_root = '${PODS_TARGET_SRCROOT}/..'
  whisper_root = "#{source_root}/whisper/v1.9.2"
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_SHARED_LIB=1 GGML_USE_CPU=1 GGML_USE_ACCELERATE=1 ACCELERATE_NEW_LAPACK=1 ACCELERATE_LAPACK_ILP64=1 WHISPER_VERSION=\"1.9.2\" GGML_VERSION=\"0.18.1\" GGML_COMMIT=\"bundled\" GGML_SCHED_MAX_COPIES=4',
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{source_root}/windows\" \"#{whisper_root}/include\" \"#{whisper_root}/src\" \"#{whisper_root}/ggml/include\" \"#{whisper_root}/ggml/src\" \"#{whisper_root}/ggml/src/ggml-cpu\""
  }
end
