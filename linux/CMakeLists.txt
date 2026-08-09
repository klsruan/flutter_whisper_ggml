# Flutter Linux FFI plugin entry point.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flutter_whisper_ggml")
project(${PROJECT_NAME} LANGUAGES C CXX)

add_subdirectory(
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
  "${CMAKE_CURRENT_BINARY_DIR}/native")

set(flutter_whisper_ggml_bundled_libraries
  $<TARGET_FILE:flutter_whisper_plugin>
  PARENT_SCOPE)
