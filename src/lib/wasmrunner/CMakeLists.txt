cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide-Wasmrunner)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide-Wasmrunner)
endif()

project(${PROJECT_NAME} VERSION 0.1 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.1 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-cxa-atexit")

if(IOS)
    set (WAMR_BUILD_PLATFORM "darwin")
    if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
        set (WAMR_BUILD_TARGET "X86_64")
    else()
        set (WAMR_BUILD_TARGET "AARCH64")
    endif()
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_AOT 1)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 0)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_AOT 0)
    set (WAMR_BUILD_THREAD_MGR 1)
    set (WAMR_BUILD_MINI_LOADER 0)
    set (WAMR_BUILD_DEBUG_INTERP 1)
    set (WAMR_BUILD_REF_TYPES 1)
    set (WAMR_BUILD_MULTI_MODULE 1)
    set (WAMR_BUILD_EXCE_HANDLING 0)
    set (WAMR_BUILD_WAMR_COMPILER 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1 -DIWASM_AS_LIBRARY -DWASM_ENABLE_WAMR_COMPILER=1)
    set (WAMR_COMPILER ${WAMR_DIR}/wamr-compiler/main.c)
    set (IWAMR ${WAMR_DIR}/product-mini/platforms/darwin/main.c)
endif()

# WAMR + AOT
include(${WAMR_DIR}/core/shared/utils/shared_utils.cmake)
include(${WAMR_DIR}/core/shared/utils/uncommon/shared_uncommon.cmake)
include(${WAMR_DIR}/core/shared/platform/${WAMR_BUILD_PLATFORM}/shared_platform.cmake)
include(${WAMR_DIR}/core/iwasm/compilation/iwasm_compl.cmake)
include(${WAMR_DIR}/build-scripts/runtime_lib.cmake)

add_library(vmlib
    ${WAMR_RUNTIME_LIB_SOURCE}
    ${PLATFORM_SHARED_SOURCE}
    ${MEM_ALLOC_SHARED_SOURCE}
    ${UTILS_SHARED_SOURCE}
    ${UNCOMMON_SHARED_SOURCE}
    ${THREAD_MGR_SOURCE}
    ${LIBC_BUILTIN_SOURCE}
    ${LIBC_WASI_SOURCE}
    ${LIB_PTHREAD_SOURCE}
    ${LIB_WASI_THREADS_SOURCE}
    ${IWASM_COMMON_SOURCE}
    ${IWASM_INTERP_SOURCE}
    ${IWASM_AOT_SOURCE})

qt_add_library(${PROJECT_NAME}
    SHARED

    wasmrunner.cpp

    # AOT compiler
    ${WAMR_COMPILER}
    ${IWAMR}
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

if(IOS OR CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
    if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
        set(LLVM_BUILD_DIR "build-iphonesimulator")
        set(LLVM_MODE "Release-iphonesimulator")
    else()
        set(LLVM_BUILD_DIR "build-iphoneos")
        set(LLVM_MODE "Release-iphoneos")
    endif()

    set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)

    find_library(LLVM REQUIRED NAMES libLLVM PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)

    set_target_properties(${PROJECT_NAME} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.wasmrunner
        MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        XCODE_ATTRIBUTE_SKIP_INSTALL "Yes"
    )
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(LLVM_LIBS /usr/lib/llvm-15/lib)

    find_library(LLVM REQUIRED NAMES libLLVM-15.so PATHS ${LLVM_FRAMEWORKS})
endif()

message(${LLVM_DIR}/${LLVM_MODE}/include)

include_directories(${PROJECT_NAME}
    ${LLVM_DIR}/llvm/include
    ${LLVM_DIR}/${LLVM_BUILD_DIR}/include
    ${LLVM_INCLUDES}
    ${LLVM_FRAMEWORKS}/clang/lib/Format
    ${LLVM_CLANG_INCLUDES}
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    ${LLVM}
    ${NOSYSTEM}
    vmlib
)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${TIDE_SRC_ROOT}
    ${UNCOMMON_SHARED_DIR}
)
