# Resolve the source only for maintainer builds. Distributed binaries bypass this file.
set(FLUTTER_WHISPER_CPP_DIR "" CACHE PATH "Path to a whisper.cpp checkout")
get_filename_component(_fw_root "${CMAKE_CURRENT_LIST_DIR}/.." REALPATH)

# Clear the old default in build directories configured before automatic fetching.
if(NOT EXISTS "${FLUTTER_WHISPER_CPP_DIR}"
    AND (FLUTTER_WHISPER_CPP_DIR STREQUAL "${_fw_root}/whisper/v1.9.5"
         OR FLUTTER_WHISPER_CPP_DIR STREQUAL "${_fw_root}/whisper/v1.9.2"))
  set(FLUTTER_WHISPER_CPP_DIR "" CACHE PATH "Path to a whisper.cpp checkout" FORCE)
endif()

if(NOT FLUTTER_WHISPER_CPP_DIR AND DEFINED ENV{FLUTTER_WHISPER_CPP_DIR})
  file(TO_CMAKE_PATH "$ENV{FLUTTER_WHISPER_CPP_DIR}" FLUTTER_WHISPER_CPP_DIR)
endif()

if(NOT FLUTTER_WHISPER_CPP_DIR)
  include(FetchContent)
  FetchContent_Declare(flutter_whisper_upstream
    GIT_REPOSITORY https://github.com/ggml-org/whisper.cpp.git
    GIT_TAG v1.9.5
    GIT_SHALLOW TRUE
    GIT_CONFIG core.longpaths=true
    UPDATE_DISCONNECTED TRUE)
  FetchContent_GetProperties(flutter_whisper_upstream)
  if(NOT flutter_whisper_upstream_POPULATED)
    # Keep upstream's targets excluded from the default build and installation.
    cmake_policy(PUSH)
    if(POLICY CMP0169)
      cmake_policy(SET CMP0169 OLD)
    endif()
    FetchContent_Populate(flutter_whisper_upstream)
    cmake_policy(POP)
  endif()
  set(FLUTTER_WHISPER_CPP_DIR "${flutter_whisper_upstream_SOURCE_DIR}")
endif()

if(NOT EXISTS "${FLUTTER_WHISPER_CPP_DIR}/include/whisper.h")
  message(FATAL_ERROR "Invalid whisper.cpp checkout: ${FLUTTER_WHISPER_CPP_DIR}")
endif()
message(STATUS "flutter_whisper whisper.cpp source: ${FLUTTER_WHISPER_CPP_DIR}")
