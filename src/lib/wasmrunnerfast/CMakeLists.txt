cmake_minimum_required(VERSION 3.20)

if(IOS OR APPLE)
    set(PROJECT_NAME Tide-Wasmrunnerfast)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide-Wasmrunnerfast)
endif()

project(${PROJECT_NAME} VERSION 0.1 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.1 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-cxa-atexit -O3")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")

if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
    set (WAMR_BUILD_PLATFORM "darwin")
    set (WAMR_BUILD_TARGET "AARCH64")
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 1)
    set (WAMR_BUILD_AOT 0)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 1)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_AOT 0)
    set (WAMR_BUILD_THREAD_MGR 1)
    set (WAMR_BUILD_MINI_LOADER 0)
    set (WAMR_BUILD_DEBUG_INTERP 0)
    set (WAMR_BUILD_REF_TYPES 0)
    set (WAMR_BUILD_MULTI_MODULE 0)
    set (WAMR_BUILD_EXCE_HANDLING 0)
    set (WAMR_BUILD_WAMR_COMPILER 0)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1)
endif()

if(APPLE AND NOT IOS)
    set (WAMR_BUILD_PLATFORM "darwin")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES arm64)
        set (WAMR_BUILD_TARGET "AARCH64")
    else()
        set (WAMR_BUILD_TARGET "X86_64")
    endif()
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 1)
    set (WAMR_BUILD_AOT 0)
    set (WAMR_BUILD_JIT 0)
    set (WAMR_BUILD_LAZY_JIT 0)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 1)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_AOT 0)
    set (WAMR_BUILD_THREAD_MGR 1)
    set (WAMR_BUILD_MINI_LOADER 0)
    set (WAMR_BUILD_DEBUG_INTERP 0)
    set (WAMR_BUILD_REF_TYPES 0)
    set (WAMR_BUILD_MULTI_MODULE 0)
    set (WAMR_BUILD_EXCE_HANDLING 0)
    set (WAMR_BUILD_WAMR_COMPILER 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set (WAMR_BUILD_PLATFORM "linux")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES aarch64)
        set (WAMR_BUILD_TARGET "AARCH64")
    else()
        set (WAMR_BUILD_TARGET "X86_64")
    endif()
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 1)
    set (WAMR_BUILD_AOT 0)
    set (WAMR_BUILD_JIT 0)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 1)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_AOT 0)
    set (WAMR_BUILD_THREAD_MGR 1)
    set (WAMR_BUILD_MINI_LOADER 0)
    set (WAMR_BUILD_DEBUG_INTERP 0)
    set (WAMR_BUILD_REF_TYPES 0)
    set (WAMR_BUILD_MULTI_MODULE 0)
    set (WAMR_BUILD_EXCE_HANDLING 0)
    set (WAMR_BUILD_WAMR_COMPILER 0)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1)
endif()

list(APPEND CMAKE_PREFIX_PATH "${LLVM_DIR}/${LLVM_BUILD_DIR}")

# WAMR + AOT
if(APPLE OR IOS)
    include(${WAMR_DIR}/core/shared/utils/shared_utils.cmake)
    include(${WAMR_DIR}/core/shared/utils/uncommon/shared_uncommon.cmake)
    include(${WAMR_DIR}/core/shared/platform/${WAMR_BUILD_PLATFORM}/shared_platform.cmake)
    include(${WAMR_DIR}/build-scripts/runtime_lib.cmake)
    include(${WAMR_DIR}/core/shared/platform/common/libc-util/platform_common_libc_util.cmake)
endif()

if (APPLE OR IOS)
    add_library(vmlibfast
        STATIC

        ${WAMR_COMPILER}

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

    target_include_directories(vmlibfast PUBLIC
        ${WAMR_DIR}/core/shared/platform/common/libc-util
    )
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    include(${WAMR_DIR}/core/shared/utils/uncommon/shared_uncommon.cmake)
    include(${WAMR_DIR}/build-scripts/runtime_lib.cmake)
    add_library(vmlibfast STATIC ${WAMR_RUNTIME_LIB_SOURCE} ${UNCOMMON_SHARED_SOURCE})
endif()

target_link_libraries(vmlibfast
    PRIVATE
    ${LLVM}
    ${NOSYSTEM}
)

qt_add_library(${PROJECT_NAME}
    SHARED

    wasmrunnerfast.cpp

    # AOT compiler
    ${WAMR_COMPILER}
    ${IWAMR}
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

if(IOS OR CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
    if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
        set(LLVM_BUILD_DIR "build-iphonesimulator")
        set(LLVM_MODE "Release-iphonesimulator")
        set(OS "iphonesimulator")
    else()
        set(LLVM_BUILD_DIR "build-iphoneos")
        set(LLVM_MODE "Release-iphoneos")
        set(OS "iphoneos")
    endif()

    set(LLVM_TOOLS ${LLVM_DIR}/ios/${LLVM_BUILD_DIR}/Debug-${OS})
    set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)

    find_library(LLVM REQUIRED NAMES libLLVM PATHS ${LLVM_TOOLS} CMAKE_FIND_ROOT_PATH_BOTH)

    set_target_properties(${PROJECT_NAME} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.wasmrunnerfast
        MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        XCODE_ATTRIBUTE_SKIP_INSTALL "Yes"
    )
endif()

if(APPLE AND NOT IOS)
    set(LLVM_BUILD_DIR "build_osx")
    set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)

    find_library(LLVM REQUIRED NAMES LLVM PATHS ${LLVM_LIBS} CMAKE_FIND_ROOT_PATH_BOTH)

    set_target_properties(${PROJECT_NAME} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.wasmrunnerfast
        MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        XCODE_ATTRIBUTE_SKIP_INSTALL "Yes"
    )
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(LLVM_LIBS /usr/lib/llvm-15/lib)
    set(LLVM_SYSTEM_DEFAULT_HEADERS "/usr/include/llvm-15")

    find_library(LLVM REQUIRED NAMES libLLVM-15.so PATHS ${LLVM_FRAMEWORKS})
endif()

message(${LLVM_DIR}/${LLVM_MODE}/include)

include_directories(${PROJECT_NAME}
    ${LLVM_SYSTEM_DEFAULT_HEADERS}
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
    vmlibfast
)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${TIDE_SRC_ROOT}
    ${UNCOMMON_SHARED_DIR}
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    install(TARGETS ${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
endif()
