# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_whisper_ggml")
project(${PROJECT_NAME} LANGUAGES CXX)

# Other Flutter plugins may declare CXX-only projects. GGML contains C targets,
# so explicitly restore C language detection before adding whisper.cpp.
enable_language(C)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_whisper_ggml_plugin")

# The pinned whisper.cpp source ships with the plugin. Set
# FLUTTER_WHISPER_CPP_DIR only to override it for upstream development.
set(FLUTTER_WHISPER_CPP_DIR "" CACHE PATH "Path to a whisper.cpp checkout")
if(NOT FLUTTER_WHISPER_CPP_DIR AND DEFINED ENV{FLUTTER_WHISPER_CPP_DIR})
  file(TO_CMAKE_PATH "$ENV{FLUTTER_WHISPER_CPP_DIR}" FLUTTER_WHISPER_CPP_DIR)
endif()
if(NOT FLUTTER_WHISPER_CPP_DIR)
  file(REAL_PATH "${CMAKE_CURRENT_SOURCE_DIR}" FLUTTER_WHISPER_PLUGIN_WINDOWS_DIR)
  get_filename_component(
    FLUTTER_WHISPER_CPP_DIR
    "${FLUTTER_WHISPER_PLUGIN_WINDOWS_DIR}/../whisper/v1.9.2"
    ABSOLUTE)
endif()
if(NOT EXISTS "${FLUTTER_WHISPER_CPP_DIR}/include/whisper.h")
  message(FATAL_ERROR
    "Bundled whisper.cpp v1.9.2 was not found at ${FLUTTER_WHISPER_CPP_DIR}. "
    "Restore whisper/v1.9.2 or set FLUTTER_WHISPER_CPP_DIR explicitly.")
endif()
message(STATUS "flutter_whisper whisper.cpp source: ${FLUTTER_WHISPER_CPP_DIR}")

set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(FLUTTER_WHISPER_GPU_BACKEND "AUTO" CACHE STRING
  "GPU backend to compile: AUTO, CPU, CUDA, or VULKAN")
if(DEFINED ENV{FLUTTER_WHISPER_GPU_BACKEND})
  string(TOUPPER "$ENV{FLUTTER_WHISPER_GPU_BACKEND}" _FW_GPU_BACKEND_ENV)
  set(FLUTTER_WHISPER_GPU_BACKEND "${_FW_GPU_BACKEND_ENV}" CACHE STRING
    "GPU backend to compile: CPU, CUDA, or VULKAN" FORCE)
endif()
set_property(CACHE FLUTTER_WHISPER_GPU_BACKEND PROPERTY STRINGS AUTO CPU CUDA VULKAN)
if(FLUTTER_WHISPER_GPU_BACKEND STREQUAL "AUTO")
  if(WIN32 AND NOT DEFINED ENV{VULKAN_SDK})
    file(GLOB _FW_VULKAN_SDKS LIST_DIRECTORIES TRUE "C:/VulkanSDK/*")
    if(_FW_VULKAN_SDKS)
      list(SORT _FW_VULKAN_SDKS COMPARE NATURAL ORDER DESCENDING)
      list(GET _FW_VULKAN_SDKS 0 _FW_VULKAN_SDK)
      set(ENV{VULKAN_SDK} "${_FW_VULKAN_SDK}")
      list(PREPEND CMAKE_PREFIX_PATH "${_FW_VULKAN_SDK}")
    endif()
  endif()
  if(DEFINED ENV{VULKAN_SDK})
    set(FLUTTER_WHISPER_GPU_BACKEND "VULKAN")
  else()
    set(FLUTTER_WHISPER_GPU_BACKEND "CPU")
  endif()
endif()
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

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_whisper_ggml_bundled_libraries
  "$<TARGET_FILE:whisper>"
  "$<TARGET_FILE:ggml>"
  "$<TARGET_FILE:ggml-base>"
  "$<TARGET_FILE:ggml-cpu>"
)
if(TARGET ggml-cuda)
  list(APPEND flutter_whisper_ggml_bundled_libraries "$<TARGET_FILE:ggml-cuda>")
endif()
if(TARGET ggml-vulkan)
  list(APPEND flutter_whisper_ggml_bundled_libraries "$<TARGET_FILE:ggml-vulkan>")
endif()
set(flutter_whisper_ggml_bundled_libraries
  ${flutter_whisper_ggml_bundled_libraries} PARENT_SCOPE)

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
