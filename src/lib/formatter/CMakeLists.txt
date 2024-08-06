cmake_minimum_required(VERSION 3.20)

if(IOS OR APPLE)
    set(PROJECT_NAME Tide-Formatter)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide-Formatter)
endif()

project(${PROJECT_NAME} VERSION 0.7 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.7 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-cxa-atexit")

include_directories(${PROJECT_NAME}
    # libclang
    ${LLVM_DIR}/clang/include
)

add_library(${PROJECT_NAME}
    SHARED

    formatter.cpp
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
    message("LLVM at: ${LLVM}")

    set_target_properties(${PROJECT_NAME} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.tideformatter
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
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.tideformatter
        MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        XCODE_ATTRIBUTE_SKIP_INSTALL "Yes"
    )
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    if (SNAP)
        set(LLVM_LIBS ${SNAP_STAGE}/usr/lib)
    else()
        set(LLVM_BUILD_DIR "build-linux")
        set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)
    endif()

    find_library(LLVM REQUIRED NAMES libLLVM-18.so PATHS ${LLVM_LIBS})
endif()

# Clang's formatting lib and dependencies
set(LIBCLANGBASIC "${LLVM_LIBS}/libclangBasic.a")
set(LIBCLANGLEX "${LLVM_LIBS}/libclangLex.a")
set(LIBCLANGTOOLINGCORE "${LLVM_LIBS}/libclangToolingCore.a")
set(LIBCLANGTOOLINGINCLUSIONS "${LLVM_LIBS}/libclangToolingInclusions.a")
set(LIBCLANGREWRITE "${LLVM_LIBS}/libclangRewrite.a")
set(LIBCLANGFORMAT "${LLVM_LIBS}/libclangFormat.a")

message(${LLVM_DIR}/${LLVM_MODE}/include)

include_directories(${PROJECT_NAME}
    ${LLVM_DIR}/llvm/include
    ${LLVM_DIR}/${LLVM_BUILD_DIR}/include
    ${LLVM_INCLUDES}
    ${LLVM_FRAMEWORKS}/clang/lib/Format
    ${LLVM_CLANG_INCLUDES}
    ${SNAP_STAGE}/usr/include
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    ${LLVM}
    ${LIBCLANGBASIC}
    ${LIBCLANGLEX}
    ${LIBCLANGTOOLINGCORE}
    ${LIBCLANGTOOLINGINCLUSIONS}
    ${LIBCLANGREWRITE}
    ${LIBCLANGFORMAT}
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    install(TARGETS ${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)
endif()
