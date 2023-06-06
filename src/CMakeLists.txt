cmake_minimum_required(VERSION 3.20)

set(PROJECT_NAME Tide)

project(${PROJECT_NAME} VERSION 0.1 LANGUAGES CXX)
project(${PROJECT_NAME} VERSION 0.1 LANGUAGES C)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick Sql)

qt_standard_project_setup()

add_definitions(-Dd_m3HasWASI)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include

    # libclang
    ${LLVM_DIR}/clang/include
)

qt_add_executable(${PROJECT_NAME}
    # Code
    main.cpp
    externalprojectpicker.mm
    linenumbershelper.cpp
    qsourcehighliter.cpp
    languagedata.cpp
    qsourcehighliterthemes.cpp
    syntaxhighlighter.cpp
    iossystemglue.mm
    fileio.cpp
    bookmarkdb.cpp
    directorylisting.cpp
    console.cpp
    openfilesmanager.cpp
    sysrootmanager.cpp
    wasmrunner.cpp
    imeventfixer.cpp
    imfixerinstaller.cpp
    projectbuilder.cpp
    autocompleter.cpp
    clangwrapper.cpp
    projectcreator.cpp
    projectlist.mm
    iosintegrationdelegate.mm

    # Header-only code
    programspec.h

    # Wasm3
    ${WASM_DIR}/source/m3_api_libc.c
    ${WASM_DIR}/source/m3_api_meta_wasi.c
    ${WASM_DIR}/source/m3_api_tracer.c
    ${WASM_DIR}/source/m3_api_uvwasi.c
    ${WASM_DIR}/source/m3_api_wasi.c
    ${WASM_DIR}/source/m3_bind.c
    ${WASM_DIR}/source/m3_code.c
    ${WASM_DIR}/source/m3_compile.c
    ${WASM_DIR}/source/m3_core.c
    ${WASM_DIR}/source/m3_env.c
    ${WASM_DIR}/source/m3_exec.c
    ${WASM_DIR}/source/m3_function.c
    ${WASM_DIR}/source/m3_info.c
    ${WASM_DIR}/source/m3_module.c
    ${WASM_DIR}/source/m3_parse.c

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
    Main.qml
    CodeEditor.qml
    TideButton.qml
    TideToolButton.qml
)

# Build toolchain itself
set(LLVM_FRAMEWORKS ${LLVM_DIR}/build-iphoneos/build/Release-iphoneos)

# Sysroot files
set(WASI_LIBS ${WASI_DIR}/lib)
set(WASI_HEADERS ${WASI_DIR}/include)
set(LLVM_HEADERS ${LLVM_DIR}/build-iphoneos/lib/clang/14.0.0/include)
set(CLANGRT ${CLANGRT_DIR}/lib/wasi/libclang_rt.builtins-wasm32.a)

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER me.fredl.tide
    PRODUCT_BUNDLE_IDENTIFIER me.fredl.tide
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks"
)

if(IOS)
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
endif()

# Qt6
find_package(Qt6 REQUIRED COMPONENTS QuickControls2 Sql)

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

include_directories(${PROJECT_NAME}
    # system() replacement through ios_system (with ios_error.h)
    ${IOS_SYSTEM}
    ${LLVM_DIR}

    # Wasm3 runtime
    ${WASM_DIR}/source
    ${WASM_DIR}/platforms/cpp/wasm3_cpp/include
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
)

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
)

set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)

set(COMMANDDICTIONARY "${CMAKE_CURRENT_SOURCE_DIR}/commandDictionary.plist")
target_sources(${PROJECT_NAME} PUBLIC ${COMMANDDICTIONARY})
set_source_files_properties(${COMMANDDICTIONARY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

# Bundle sysroot
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${WASI_LIBS}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Sysroot/lib"
)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${WASI_HEADERS}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Sysroot/include"
)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy "${CLANGRT}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Sysroot/lib/wasi/libclang_rt.builtins-wasm32.a"
)

# Set a few properties for file sharing & UI tweaks
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND plutil -replace UIFileSharingEnabled -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND plutil -replace LSSupportsOpeningDocumentsInPlace -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
)

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
