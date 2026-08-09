cmake_minimum_required(VERSION 3.20)
project(flutter_whisper_web LANGUAGES C CXX)

if(NOT EMSCRIPTEN)
  message(FATAL_ERROR "Configure this target with emcmake.")
endif()

set(FLUTTER_WHISPER_CPP_DIR "" CACHE PATH "Path to whisper.cpp")
if(NOT FLUTTER_WHISPER_CPP_DIR AND DEFINED ENV{FLUTTER_WHISPER_CPP_DIR})
  file(TO_CMAKE_PATH "$ENV{FLUTTER_WHISPER_CPP_DIR}" FLUTTER_WHISPER_CPP_DIR)
endif()
if(NOT FLUTTER_WHISPER_CPP_DIR)
  get_filename_component(
    FLUTTER_WHISPER_CPP_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../whisper/v1.9.2"
    ABSOLUTE)
endif()
if(NOT EXISTS "${FLUTTER_WHISPER_CPP_DIR}/include/whisper.h")
  message(FATAL_ERROR
    "Bundled whisper.cpp v1.9.2 was not found at ${FLUTTER_WHISPER_CPP_DIR}. "
    "Restore whisper/v1.9.2 or set FLUTTER_WHISPER_CPP_DIR explicitly.")
endif()
message(STATUS "flutter_whisper whisper.cpp source: ${FLUTTER_WHISPER_CPP_DIR}")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_WEBGPU OFF CACHE BOOL "" FORCE)
add_subdirectory("${FLUTTER_WHISPER_CPP_DIR}" whisper_cpp EXCLUDE_FROM_ALL)

add_executable(flutter_whisper flutter_whisper_web_bridge.cpp)
target_include_directories(flutter_whisper PRIVATE "${FLUTTER_WHISPER_CPP_DIR}/include")
target_link_libraries(flutter_whisper PRIVATE whisper)
target_compile_options(flutter_whisper PRIVATE "-pthread" "-msimd128")
target_link_options(flutter_whisper PRIVATE
  "-sMODULARIZE=1"
  "-sEXPORT_NAME=createFlutterWhisperModule"
  "-sENVIRONMENT=worker"
  "-sALLOW_MEMORY_GROWTH=1"
  "-sMAXIMUM_MEMORY=4294967296"
  "-sFILESYSTEM=1"
  "-sEXPORTED_FUNCTIONS=['_malloc','_free','_fw_web_create','_fw_web_destroy','_fw_web_transcribe','_fw_web_cancel']"
  "-sEXPORTED_RUNTIME_METHODS=['FS','cwrap','ccall','HEAPF32']"
  "-msimd128"
  "-pthread"
)
set_target_properties(flutter_whisper PROPERTIES OUTPUT_NAME "flutter_whisper" SUFFIX ".js")
