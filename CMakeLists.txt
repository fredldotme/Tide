cmake_minimum_required(VERSION 3.16)

project(Tide VERSION 0.1 LANGUAGES C)
project(Tide VERSION 0.1 LANGUAGES CXX)
set (CMAKE_CXX_STANDARD 17)

option(BUILD_CLICK_METADATA "Build metadata for Ubuntu Touch Click packaging" OFF)
option(SNAP "Snap packaging support" OFF)

if (SNAP)
    set(LLVM_DIR ${SNAP_STAGE}/usr)
    set(WASI_DIR ${SNAP_STAGE}/resources/wasi-sysroot)
    set(CLANGRT_DIR ${SNAP_STAGE}/resources)
else()
    set(LLVM_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/llvm)
    set(WASI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/tmp/wasi-sysroot)
    set(CLANGRT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/tmp)
endif()

set(WAMR_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/wamr)
set(QMAKEPARSER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libqmakeparser)
set(MICROTAR_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/microtar)
set(GIT2_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libgit2)
set(UNIXY_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/unixy)
# set(SDL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/SDL)

# CMake & Ninja
set(CMAKE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/CMake/build/Source)
set(CMAKE_UTIL_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/CMake/build/Utilities)
set(NINJA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/ninja/build)

# When it's time: add_subdirectory(${SDL_DIR})
if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(USE_HTTPS "SecureTransport" CACHE STRING "" FORCE)
endif()
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)

# libgit2
add_subdirectory(${GIT2_DIR})

if(BUILD_CLICK_METADATA)
    add_subdirectory(click)
endif()

# Main Tide source
add_subdirectory(src)
