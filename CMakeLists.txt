cmake_minimum_required(VERSION 3.16)

project(Tide VERSION 0.1 LANGUAGES CXX C)
set (CMAKE_CXX_STANDARD 17)

set(LLVM_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/llvm)
set(WASI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tmp/wasi-sysroot)
set(CLANGRT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tmp)
set(WAMR_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/wamr)
set(QMAKEPARSER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libqmakeparser)
set(MICROTAR_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/microtar)
# set(SDL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/SDL)

# CMake & Ninja
set(CMAKE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/CMake/build/Source)
set(CMAKE_UTIL_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/CMake/build/Utilities)
set(NINJA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/ninja/build)

# When it's time: add_subdirectory(${SDL_DIR})
add_subdirectory(src)
