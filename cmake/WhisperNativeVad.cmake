# whisper.cpp 1.9.5 has no public API to clear VAD mappings between calls.
# Compile the upstream translation unit with a small adapter in the build tree.
get_target_property(_fw_whisper_sources whisper SOURCES)
if(NOT "whisper.cpp" IN_LIST _fw_whisper_sources)
  message(FATAL_ERROR "The whisper target no longer lists whisper.cpp. Review the native VAD adapter.")
endif()
list(REMOVE_ITEM _fw_whisper_sources "whisper.cpp")
set(_fw_whisper_adapter "${CMAKE_CURRENT_BINARY_DIR}/whisper_native_vad.cpp")
configure_file("${CMAKE_CURRENT_LIST_DIR}/whisper_native_vad.cpp.in"
  "${_fw_whisper_adapter}" @ONLY)
set_property(TARGET whisper PROPERTY SOURCES "${_fw_whisper_sources};${_fw_whisper_adapter}")
