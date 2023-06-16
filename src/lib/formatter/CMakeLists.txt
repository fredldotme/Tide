cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide-Formatter)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide-Formatter)
endif()

project(${PROJECT_NAME} VERSION 0.1 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.1 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(${PROJECT_NAME}
    # libclang
    ${LLVM_DIR}/clang/include
)

add_library(${PROJECT_NAME}
    SHARED

    formatter.cpp
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# Build toolchain itself
set(LLVM_FRAMEWORKS ${LLVM_DIR}/build-iphoneos/build/Release-iphoneos)
set(LLVM_LIBS ${LLVM_DIR}/build-iphoneos/lib)
set(LLVM_INCLUDES ${LLVM_DIR}/build-iphoneos/include)
set(LLVM_CLANG_INCLUDES ${LLVM_DIR}/build-iphoneos/tools/clang/include)

if(IOS)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER me.fredl.tideformatter
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        XCODE_ATTRIBUTE_SKIP_INSTALL "Yes"
    )

    # Clang's formatting lib and dependencies
    set(LIBCLANGBASIC "${LLVM_LIBS}/libclangBasic.a")
    set(LIBCLANGLEX "${LLVM_LIBS}/libclangLex.a")
    set(LIBCLANGTOOLINGCORE "${LLVM_LIBS}/libclangToolingCore.a")
    set(LIBCLANGTOOLINGINCLUSIONS "${LLVM_LIBS}/libclangToolingInclusions.a")
    set(LIBCLANGREWRITE "${LLVM_LIBS}/libclangRewrite.a")
    set(LIBCLANGFORMAT "${LLVM_LIBS}/libclangFormat.a")

    include_directories(${PROJECT_NAME}
        ${LLVM_DIR}/llvm/include
        ${LLVM_INCLUDES}
        ${LLVM_FRAMEWORKS}/clang/lib/Format
        ${LLVM_CLANG_INCLUDES}
    )
endif()

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

