cmake_minimum_required(VERSION 3.20)
add_definitions(-D__wasi__)
include(${CMAKE_CURRENT_SOURCE_DIR}/../../3rdparty/wamr/core/iwasm/libraries/lib-socket/lib_socket_wasi.cmake)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../../3rdparty/wamr/core/iwasm/libraries/lib-socket/inc)
