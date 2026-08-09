# Shared native build used by Android and Linux.
cmake_minimum_required(VERSION 3.14)

project(flutter_whisper_plugin LANGUAGES C CXX)
cmake_policy(VERSION 3.14...3.25)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

get_filename_component(FLUTTER_WHISPER_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(FLUTTER_WHISPER_CPP_DIR
    "${FLUTTER_WHISPER_ROOT}/whisper/v1.9.2"
    CACHE PATH "Path to the bundled whisper.cpp source")

if(NOT EXISTS "${FLUTTER_WHISPER_CPP_DIR}/include/whisper.h")
  message(FATAL_ERROR
    "Bundled whisper.cpp v1.9.2 was not found at ${FLUTTER_WHISPER_CPP_DIR}")
endif()

# Link whisper.cpp and GGML statically into one plugin library. Consumers only
# need to load libflutter_whisper_plugin.so.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)

set(FLUTTER_WHISPER_GPU_BACKEND "CPU" CACHE STRING
    "Linux GPU backend: CPU or VULKAN")
if(NOT ANDROID AND DEFINED ENV{FLUTTER_WHISPER_GPU_BACKEND})
  string(TOUPPER "$ENV{FLUTTER_WHISPER_GPU_BACKEND}" _FW_GPU_BACKEND_ENV)
  set(FLUTTER_WHISPER_GPU_BACKEND "${_FW_GPU_BACKEND_ENV}" CACHE STRING
      "Linux GPU backend: CPU or VULKAN" FORCE)
endif()
set_property(CACHE FLUTTER_WHISPER_GPU_BACKEND PROPERTY STRINGS CPU VULKAN)

if(ANDROID)
  # CPU/NEON is the portable Android baseline. Vulkan can be added later with
  # host shader generation and device-specific validation.
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
elseif(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "VULKAN")
  set(GGML_VULKAN ON CACHE BOOL "" FORCE)
elseif(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "CPU")
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
else()
  message(FATAL_ERROR
    "Invalid FLUTTER_WHISPER_GPU_BACKEND=${FLUTTER_WHISPER_GPU_BACKEND}. Use CPU or VULKAN.")
endif()

message(STATUS "flutter_whisper source: ${FLUTTER_WHISPER_CPP_DIR}")
message(STATUS "flutter_whisper target: ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "flutter_whisper GPU backend: ${FLUTTER_WHISPER_GPU_BACKEND}")

add_subdirectory(
  "${FLUTTER_WHISPER_CPP_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/whisper_cpp"
  EXCLUDE_FROM_ALL)

add_library(flutter_whisper_plugin SHARED
  "${FLUTTER_WHISPER_ROOT}/windows/flutter_whisper_bridge.cpp")

target_include_directories(flutter_whisper_plugin PRIVATE
  "${FLUTTER_WHISPER_ROOT}/windows"
  "${FLUTTER_WHISPER_CPP_DIR}/include"
  "${FLUTTER_WHISPER_CPP_DIR}/ggml/include")
target_link_libraries(flutter_whisper_plugin PRIVATE whisper)
target_compile_definitions(flutter_whisper_plugin PUBLIC DART_SHARED_LIB)

set_target_properties(flutter_whisper_plugin PROPERTIES
  OUTPUT_NAME "flutter_whisper_plugin"
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES)

if(ANDROID)
  # Android 15+ devices may use 16 KiB memory pages.
  target_link_options(flutter_whisper_plugin PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,--exclude-libs,ALL")
elseif(UNIX)
  target_link_options(flutter_whisper_plugin PRIVATE "-Wl,--exclude-libs,ALL")
endif()
