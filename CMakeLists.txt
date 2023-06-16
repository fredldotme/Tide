cmake_minimum_required(VERSION 3.16)

project(Tide VERSION 0.1 LANGUAGES CXX)

set(LLVM_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/llvm)
set(WASI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tmp/wasi-sysroot)
set(CLANGRT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tmp)
set(WAMR_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/wamr)
set(QMAKEPARSER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/libqmakeparser)
set(CMAKE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/CMake)

add_subdirectory(${CMAKE_DIR})
add_subdirectory(src)
