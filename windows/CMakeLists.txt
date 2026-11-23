# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_whisper_ggml")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
if(POLICY CMP0194)
  cmake_policy(SET CMP0194 NEW)
  set(CMAKE_POLICY_DEFAULT_CMP0194 NEW)
endif()

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_whisper_ggml_plugin")

set(_fw_prebuilt "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/amd64")
if(EXISTS "${_fw_prebuilt}/flutter_whisper_plugin.dll")
  if(NOT EXISTS "${_fw_prebuilt}/flutter_whisper_plugin.lib")
    message(FATAL_ERROR "The packaged Whisper Windows import library is missing.")
  endif()
  if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8 OR CMAKE_GENERATOR_PLATFORM MATCHES "[Aa][Rr][Mm]")
    message(FATAL_ERROR "The packaged Whisper Windows runtime requires x64.")
  endif()
  add_library(${PLUGIN_NAME} SHARED IMPORTED GLOBAL)
  set_target_properties(${PLUGIN_NAME} PROPERTIES
    IMPORTED_LOCATION "${_fw_prebuilt}/flutter_whisper_plugin.dll"
    IMPORTED_IMPLIB "${_fw_prebuilt}/flutter_whisper_plugin.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/include")
  set(flutter_whisper_ggml_bundled_libraries "" PARENT_SCOPE)
  return()
endif()

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter_whisper_bridge.cpp")
  message(FATAL_ERROR "The packaged Whisper Windows runtime is missing.")
endif()

enable_language(C)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/WhisperSource.cmake")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_IS_DEV OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(FLUTTER_WHISPER_GPU_BACKEND "CPU" CACHE STRING
  "GPU backend to compile: CPU, CUDA, or VULKAN")
if(DEFINED ENV{FLUTTER_WHISPER_GPU_BACKEND})
  string(TOUPPER "$ENV{FLUTTER_WHISPER_GPU_BACKEND}" _FW_GPU_BACKEND_ENV)
  set(FLUTTER_WHISPER_GPU_BACKEND "${_FW_GPU_BACKEND_ENV}" CACHE STRING
    "GPU backend to compile: CPU, CUDA, or VULKAN" FORCE)
endif()
# Migrate build directories created by versions whose cached default was AUTO.
if(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "AUTO")
  set(FLUTTER_WHISPER_GPU_BACKEND "CPU" CACHE STRING
    "GPU backend to compile: CPU, CUDA, or VULKAN" FORCE)
endif()
set_property(CACHE FLUTTER_WHISPER_GPU_BACKEND PROPERTY STRINGS CPU CUDA VULKAN)
if(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "CUDA")
  set(GGML_CUDA ON CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
elseif(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "VULKAN")
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN ON CACHE BOOL "" FORCE)
elseif(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "CPU")
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
else()
  message(FATAL_ERROR
    "Invalid FLUTTER_WHISPER_GPU_BACKEND=${FLUTTER_WHISPER_GPU_BACKEND}. Use AUTO, CPU, CUDA, or VULKAN.")
endif()
message(STATUS "flutter_whisper GPU backend: ${FLUTTER_WHISPER_GPU_BACKEND}")
set(_FLUTTER_WHISPER_INSTALL_PREFIX_WAS_DEFAULT
  ${CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT})
add_subdirectory(
  "${FLUTTER_WHISPER_CPP_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/whisper_cpp"
  EXCLUDE_FROM_ALL)
include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/WhisperNativeVad.cmake")

# whisper.cpp and GGML are vendored third-party sources. Their conversion and
# deprecation warnings are not actionable by plugin consumers and can produce
# thousands of MSVC lines. Keep warnings enabled for the Flutter bridge itself.
if(MSVC)
  foreach(_FW_THIRD_PARTY_TARGET
      whisper ggml ggml-base ggml-cpu ggml-cuda ggml-vulkan)
    if(TARGET ${_FW_THIRD_PARTY_TARGET})
      target_compile_options(${_FW_THIRD_PARTY_TARGET} PRIVATE
        /W0 /wd4244 /wd4267)
    endif()
  endforeach()
endif()
if(_FLUTTER_WHISPER_INSTALL_PREFIX_WAS_DEFAULT)
  set(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT TRUE)
endif()

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_whisper_bridge.cpp"
  "flutter_whisper_plugin.cpp"
  "flutter_whisper_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_whisper/flutter_whisper_plugin_c_api.h"
  "flutter_whisper_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  OUTPUT_NAME "flutter_whisper_plugin"
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${FLUTTER_WHISPER_CPP_DIR}/include"
  "${FLUTTER_WHISPER_CPP_DIR}/ggml/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin whisper)

set(flutter_whisper_ggml_bundled_libraries "" PARENT_SCOPE)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/flutter_whisper_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(${TEST_RUNNER} PRIVATE
  "${FLUTTER_WHISPER_CPP_DIR}/include")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin whisper)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
