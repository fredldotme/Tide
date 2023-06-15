cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide)
endif()

project(${PROJECT_NAME} VERSION 0.1 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.1 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

add_subdirectory(lib)

# Qt6
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick Sql QuickControls2)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include

    # libclang
    ${LLVM_DIR}/clang/include
)

qt_add_executable(${PROJECT_NAME}
    # Code
    main.cpp
    common/directorylisting.cpp
    common/clangwrapper.cpp
    editor/linenumbershelper.cpp
    editor/qsourcehighliter.cpp
    editor/languagedata.cpp
    editor/qsourcehighliterthemes.cpp
    editor/syntaxhighlighter.cpp
    editor/cppformatter.cpp
    autocomplete/autocompleter.cpp
    utility/fileio.cpp
    utility/console.cpp
    utility/openfilesmanager.cpp
    utility/sysrootmanager.cpp
    utility/wasmrunner.cpp
    utility/linuxruntimemanager.cpp
    utility/searchandreplace.cpp
    projects/bookmarkdb.cpp
    projects/projectbuilder.cpp
    projects/projectcreator.cpp

    # Header-only code
    common/stdiospec.h
    common/searchresult.h

    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include/qmakeblock.h
    ${QMAKEPARSER_DIR}/lib/include/qmakecursor.h
    ${QMAKEPARSER_DIR}/lib/include/qmakeparser.h
    ${QMAKEPARSER_DIR}/lib/include/qmakereader.h
    ${QMAKEPARSER_DIR}/lib/src/qmakeblock.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakecursor.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakeparser.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakereader.cpp

    # Assets
    assets.qrc
)

qt_add_qml_module(${PROJECT_NAME}
    URI Tide
    VERSION 1.0
    QML_FILES
    qml/Main.qml
    qml/CodeEditor.qml
    qml/TideButton.qml
    qml/TideToolButton.qml
    qml/SettingsDialog.qml
    qml/ConsoleView.qml
    qml/ContextView.qml
    qml/ContextViewButton.qml
)

# Build toolchain itself
set(LLVM_FRAMEWORKS ${LLVM_DIR}/build-iphoneos/build/Release-iphoneos)
set(LLVM_LIBS ${LLVM_DIR}/build-iphoneos/lib)
set(LLVM_INCLUDES ${LLVM_DIR}/build-iphoneos/include)
set(LLVM_CLANG_INCLUDES ${LLVM_DIR}/build-iphoneos/tools/clang/include)

# Sysroot files
set(WASI_LIBS ${WASI_DIR}/lib)
set(WASI_HEADERS ${WASI_DIR}/include)
set(LLVM_HEADERS ${LLVM_DIR}/build-iphoneos/lib/clang/14.0.0/include)
set(CLANGRT ${CLANGRT_DIR}/lib/wasi/libclang_rt.builtins-wasm32.a)

if(IOS)
    set (WAMR_BUILD_PLATFORM "darwin")
    set (WAMR_BUILD_TARGET "AARCH64")
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
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        # Code
        platform/ios/iosprojectlist.mm
        platform/ios/iosintegrationdelegate.mm
        platform/ios/externalprojectpicker.mm
        platform/ios/iossystemglue.mm
        platform/ios/imeventfixer.cpp
        platform/ios/imfixerinstaller.cpp
    )

    include_directories(${PROJECT_NAME}
        # system() replacement through ios_system (with ios_error.h)
        ${IOS_SYSTEM}
        ${LLVM_DIR}

        # Platform abstraction
        ${CMAKE_CURRENT_SOURCE_DIR}/platform/ios
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER me.fredl.tide
        PRODUCT_BUNDLE_IDENTIFIER me.fredl.tide
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE TRUE
        WIN32_EXECUTABLE TRUE
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks"
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/Tide.entitlements"
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES
        QT_IOS_LAUNCH_SCREEN "${CMAKE_CURRENT_SOURCE_DIR}/assets/LaunchScreen.storyboard")
    target_sources(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/assets/Tide@2x.png)
    set_source_files_properties(
        ${CMAKE_CURRENT_SOURCE_DIR}/assets/Tide@2x.png
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

    # Asset catalog root
    target_sources(${PROJECT_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    # Asset catalog app icon set
    list(APPEND app_icon_set "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets/AppIcon.appiconset")
    list(APPEND app_icon_set "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets/AppIcon.appiconset/Contents.json")
    set_source_files_properties(${app_icon_set} PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources/Assets.xcassets
    )

    # Asset catalog icon files
    file(GLOB app_icon_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets/AppIcon.appiconset/*.png")
    list(APPEND app_icon_files "${CMAKE_CURRENT_SOURCE_DIR}/Assets.xcassets/AppIcon.appiconset/Contents.json")
    set_source_files_properties(${app_icon_set} PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources/Assets.xcassets/AppIcon.appiconset
    )

    set_property(TARGET ${PROJECT_NAME} PROPERTY XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon")

    # LLVM & Clang
    find_library(IOS_SYSTEM REQUIRED NAMES ios_system PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLVM REQUIRED NAMES libLLVM PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CLANG REQUIRED NAMES clang PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLD REQUIRED NAMES lld PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(AR REQUIRED NAMES ar PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(DIS REQUIRED NAMES dis PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLD REQUIRED NAMES lld PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLI REQUIRED NAMES lli PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LINK REQUIRED NAMES link PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(NM REQUIRED NAMES nm PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(OPT REQUIRED NAMES opt PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)

    # libclang for C++ ASTs
    find_library(LIBCLANG_CPP REQUIRED NAMES libclang PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # Because CMake doesn't find the Header itself currently
    include_directories(${PROJECT_NAME}
        ${LLVM_FRAMEWORKS}/ios_system.framework/Headers
    )
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set (WAMR_BUILD_PLATFORM "linux")
    set (WAMR_BUILD_TARGET "AARCH64")
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 1)
    set (WAMR_BUILD_AOT 0)
    set (WAMR_BUILD_JIT 0)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        platform/posix/posixsystemglue.cpp
        platform/posix/projectdirectorypicker.cpp
        platform/posix/posixintegrationdelegate.cpp
        platform/posix/nullinputmethodfixerinstaller.cpp
        platform/posix/posixprojectlist.cpp
    )
endif()

# WAMR
include(${WAMR_DIR}/build-scripts/runtime_lib.cmake)
add_library(vmlib ${WAMR_RUNTIME_LIB_SOURCE})

include_directories(${PROJECT_NAME}
    # Wasm3 runtime
    ${WAMR_DIR}/core/iwasm/include

    # App headers
    ${CMAKE_CURRENT_SOURCE_DIR}/common
    ${CMAKE_CURRENT_SOURCE_DIR}/autocomplete
    ${CMAKE_CURRENT_SOURCE_DIR}/editor
    ${CMAKE_CURRENT_SOURCE_DIR}/projects
    ${CMAKE_CURRENT_SOURCE_DIR}/utility
)

target_link_libraries(${PROJECT_NAME}-platform
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Sql
    Qt6::Quick
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    ${IOS_SYSTEM}
    #LSPClient
    ${PROJECT_NAME}-platform
    vmlib
)

# Deployment on iOS
if(IOS)
    set_property(TARGET ${PROJECT_NAME}
        PROPERTY XCODE_EMBED_FRAMEWORKS
        ${IOS_SYSTEM}
        ${LLVM}
        ${CLANG}
        ${LLD}
        ${LLI}
        ${AR}
        ${DIS}
        ${LLD}
        ${LINK}
        ${NM}
        ${OPT}
        ${LIBCLANG_CPP}
        ${PROJECT_NAME}-Formatter
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)

    set(COMMANDDICTIONARY "${CMAKE_CURRENT_SOURCE_DIR}/commandDictionary.plist")
    target_sources(${PROJECT_NAME} PUBLIC ${COMMANDDICTIONARY})
    set_source_files_properties(${COMMANDDICTIONARY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

    # Bundle sysroot parts
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${WASI_LIBS}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Sysroot/lib"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${WASI_HEADERS}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Sysroot/include"
    )

    # Also bundle Clang parts
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy "${CLANGRT}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Clang/lib/wasi/libclang_rt.builtins-wasm32.a"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${LLVM_HEADERS}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Clang/include"
    )

    # Set a few properties for file sharing & UI tweaks
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace UIFileSharingEnabled -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace LSSupportsOpeningDocumentsInPlace -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )
endif()

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
