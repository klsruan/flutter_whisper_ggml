# Flutter Linux FFI plugin entry point.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flutter_whisper_ggml")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(_fw_backend CPU)
if(DEFINED ENV{FLUTTER_WHISPER_GPU_BACKEND})
  string(TOUPPER "$ENV{FLUTTER_WHISPER_GPU_BACKEND}" _fw_backend)
endif()
if(NOT _fw_backend MATCHES "^(CPU|VULKAN)$")
  message(FATAL_ERROR "Set FLUTTER_WHISPER_GPU_BACKEND to CPU or VULKAN.")
endif()
set(_fw_prebuilt "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/${CMAKE_SYSTEM_PROCESSOR}/${_fw_backend}/libflutter_whisper_plugin.so")
if(EXISTS "${_fw_prebuilt}")
  set(flutter_whisper_ggml_bundled_libraries "${_fw_prebuilt}" PARENT_SCOPE)
  return()
endif()

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../src/CMakeLists.txt")
  message(FATAL_ERROR "No packaged Whisper runtime for ${CMAKE_SYSTEM_PROCESSOR}/${_fw_backend}.")
endif()

add_subdirectory(
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
  "${CMAKE_CURRENT_BINARY_DIR}/native")

set(flutter_whisper_ggml_bundled_libraries
  $<TARGET_FILE:flutter_whisper_plugin>
  PARENT_SCOPE)
