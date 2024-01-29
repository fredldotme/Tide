cmake_minimum_required(VERSION 3.20)

if(IOS OR APPLE)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide-ide)
    include(GNUInstallDirs)
endif()

project(${PROJECT_NAME} VERSION 1.9.2 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

# Build against mixed Host + Cross environments (ie 6.5.2 macOS Qt with 6.5.3 iOS Qt)
set(QT_NO_PACKAGE_VERSION_CHECK ON)

if(CMAKE_BUILD_TYPE MATCHES "")
    set(CMAKE_BUILD_TYPE "Release")
endif()
message("Tide build type: ${CMAKE_BUILD_TYPE}")

# Artifacts from LLVM build
if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
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
elseif(APPLE)
    set(LLVM_BUILD_DIR "build_osx")
    set(LLVM_MODE "Release-macos")
    set(OS "osx")
    set(CMAKE_MACOSX_BUNDLE ON)
    set(QT6_IS_SHARED_LIBS_BUILD ON)
    set(LLVM_TOOLS ${LLVM_DIR}/${LLVM_BUILD_DIR}/bin)
    message("LLVM tools in: ${LLVM_TOOLS}")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(LLVM_BUILD_DIR "build-linux")
    set(LLVM_MODE "Release-linux")
    set(OS "osx")
    if(SNAP)
        set(LLVM_TOOLS ${SNAP_STAGE}/usr/bin)
    else()
        set(LLVM_TOOLS ${LLVM_DIR}/${LLVM_BUILD_DIR}/bin)
    endif()
    message("LLVM tools in: ${LLVM_TOOLS}")
endif()

function(resource VAR SOURCE_PATH DESTINATION PATTERN)
    file(GLOB_RECURSE _LIST CONFIGURE_DEPENDS ${SOURCE_PATH}/${PATTERN})
    message("${SOURCE_PATH}/${PATTERN}")
    foreach (RESOURCE ${_LIST})
        message("Setting up resource: ${RESOURCE}")
        get_filename_component(_PARENT ${RESOURCE} DIRECTORY)
        if (${_PARENT} STREQUAL ${SOURCE_PATH})
            set(_DESTINATION ${DESTINATION})
        else ()
            file(RELATIVE_PATH _DESTINATION ${SOURCE_PATH} ${_PARENT})
            set(_DESTINATION ${DESTINATION}/${_DESTINATION})
        endif ()
        set_property(SOURCE ${RESOURCE} PROPERTY MACOSX_PACKAGE_LOCATION ${_DESTINATION})
    endforeach (RESOURCE)
    set(${VAR} ${_LIST} PARENT_SCOPE)
endfunction()

# Sysroot files
set(WASI_LIBS ${WASI_DIR}/lib)
set(WASI_HEADERS ${WASI_DIR}/include)
set(LLVM_HEADERS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib/clang/17/include)
set(CLANGRT ${CLANGRT_DIR}/lib/wasi)
set(TIDE_SRC_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

if(IOS)
    resource(CLANG_PARTS ${CLANGRT_DIR} Resources clang.tar)
    resource(THE_SYSROOT ${CLANGRT_DIR} Resources sysroot.tar)
    resource(BOOST_TAR ${CLANGRT_DIR} Resources boost.tar)
    resource(CMAKE_MODULES ${CLANGRT_DIR} Resources cmake.tar)
    resource(PYTHON_WASM ${CLANGRT_DIR} Resources python.tar)
    resource(COMMANDSYAML ${CMAKE_CURRENT_SOURCE_DIR} Resources commands.yaml)
endif()

if(APPLE)
    resource(CLANG_PARTS ${CLANGRT_DIR} Resources clang.tar)
    resource(THE_SYSROOT ${CLANGRT_DIR} Resources sysroot.tar)
    resource(BOOST_TAR ${CLANGRT_DIR} Resources boost.tar)
    resource(CMAKE_MODULES ${CLANGRT_DIR} Resources cmake.tar)
    resource(PYTHON_WASM ${CLANGRT_DIR} Resources python.tar)
endif()

# WebAssembly-based plugin support

if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
    set (WAMR_BUILD_PLATFORM "darwin")
    set (WAMR_BUILD_TARGET "AARCH64")
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 0)
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
    set (WAMR_BUILD_REF_TYPES 1)
    set (WAMR_BUILD_MULTI_MODULE 1)
    set (WAMR_BUILD_EXCE_HANDLING 0)
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
    set (WAMR_BUILD_REF_TYPES 1)
    set (WAMR_BUILD_MULTI_MODULE 1)
    set (WAMR_BUILD_EXCE_HANDLING 0)
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
    set (WAMR_BUILD_DEBUG_INTERP 1)
    set (WAMR_BUILD_REF_TYPES 1)
    set (WAMR_BUILD_MULTI_MODULE 1)
    set (WAMR_BUILD_EXCE_HANDLING 0)
    set (WAMR_BUILD_WAMR_COMPILER 0)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1)
endif()

# WAMR + AOT
list(APPEND CMAKE_PREFIX_PATH "${LLVM_DIR}/${LLVM_BUILD_DIR}")

# Qt6
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Widgets Qml Quick Sql QuickControls2 VirtualKeyboard)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include

    # tar implementation
    ${MICROTAR_DIR}/src

    # LLVM 15 on GNU/Linux
    ${LLVM_INCLUDE}

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
    utility/linuxruntimemanager.cpp
    utility/searchandreplace.cpp
    utility/debugger.cpp
    utility/runners/pyrunner.cpp
    utility/runners/wasmrunner.cpp
    utility/gitclient.cpp
    projects/bookmarkdb.cpp
    projects/projectbuilder.cpp
    projects/projectcreator.cpp
    projects/cmakebuilder.cpp
    projects/qmakebuilder.cpp
    projects/snapcraftbuilder.cpp
    projects/builderbackend.h
    plugins/tidepluginmanager.cpp
    plugins/tideplugin.cpp
    plugins/wasmloadable.cpp
    plugins/plugininterface.cpp

    # Header-only code
    common/stdiospec.h
    common/searchresult.h

    # API Bindings with QObjects in them
    # api-bindings/qmlwindow.h

    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include/qmakeblock.h
    ${QMAKEPARSER_DIR}/lib/include/qmakecursor.h
    ${QMAKEPARSER_DIR}/lib/include/qmakeparser.h
    ${QMAKEPARSER_DIR}/lib/include/qmakereader.h
    ${QMAKEPARSER_DIR}/lib/src/qmakeblock.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakecursor.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakeparser.cpp
    ${QMAKEPARSER_DIR}/lib/src/qmakereader.cpp

    # tar implementation
    ${MICROTAR_DIR}/src/microtar.c

    # Ship the sysroot & misc parts
    ${THE_SYSROOT}
    ${CLANG_PARTS}
    ${BOOST_TAR}
    ${CMAKE_MODULES}
    ${PYTHON_WASM}
    ${COMMANDSYAML}

    # Assets
    assets.qrc
)

qt_add_qml_module(${PROJECT_NAME}
    URI Tide
    VERSION 1.0
    RESOURCE_PREFIX /Tide
    NO_RESOURCE_TARGET_PATH

    QML_FILES
    qml/Main.qml
    qml/CodeEditor.qml
    qml/TideButton.qml
    qml/TideToolButton.qml
    qml/SettingsDialog.qml
    qml/ConsoleView.qml
    qml/ContextView.qml
    qml/ContextViewButton.qml
    qml/FileListingButton.qml
    qml/OpenFileListingButton.qml
    qml/TideMenu.qml
    qml/TideDialog.qml
    qml/TideInteractiveDialog.qml
    qml/HelpPage.qml
    qml/DebuggerListEntry.qml
    qml/TidePrefixedButton.qml
    qml/SettingsCategoryButton.qml
    qml/TideComboBox.qml
    qml/TideHeaderButton.qml
    qml/AutocompletorFrame.qml
    qml/GitDialog.qml
    qml/GitLogEntry.qml
    qml/PlatformProperties.qml
    qml/TideScrollBar.qml
    qml/VirtualKeyboard.qml

    NO_LINT
)

# Build toolchain itself
set(LLVM_FRAMEWORKS ${LLVM_DIR}/${LLVM_BUILD_DIR}/build/${LLVM_MODE})
set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)
set(LLVM_INCLUDES ${LLVM_DIR}/${LLVM_BUILD_DIR}/include)
set(LLVM_CLANG_INCLUDES ${LLVM_DIR}/${LLVM_BUILD_DIR}/tools/clang/include)
set(NOSYSTEM_FRAMEWORK ${LLVM_DIR}/no_system/${LLVM_BUILD_DIR}/Debug-iphoneos)
set(UNIXY_FRAMEWORK ${UNIXY_DIR}/build-iphoneos/Debug-iphoneos)
message("NOSYSTEM_FRAMEWORK: ${NOSYSTEM_FRAMEWORK}")

# Include libs after defining a few crucial variables
add_subdirectory(lib)

include_directories(${PROJECT_NAME}
    # WAMR AOT compiler
    ${WAMR_DIR}/core/shared/utils/uncommon
    ${WAMR_DIR}/core/shared/platform/darwin

    # system() replacement through no_system
    ${NOSYSTEM}
    ${LLVM_DIR}

    # Clang & LLVM libraries
    ${LLVM_DIR}/llvm/include
    ${LLVM_DIR}/clang/include
    ${LLVM_DIR}/lld/include
    ${LLVM_DIR}/lldb/include
    ${LLVM_DIR}/${LLVM_BUILD_DIR}/include
    ${LLVM_DIR}/${LLVM_BUILD_DIR}/tools/clang/include
    ${SNAP_STAGE}/usr/include

    # Platform abstraction
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/ios
)

if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
    set (QT6GUIPRIVATE Qt6::GuiPrivate)
    set (ICONV iconv)

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        # Code
        platform/ios/iosintegrationdelegate.mm
        platform/ios/clangcompiler.cpp
        platform/ios/iossystemglue.mm
        platform/ios/externalprojectpicker.mm
        platform/ios/imeventfixer.mm
        platform/ios/imfixerinstaller.mm
        platform/darwin/iosprojectlist.mm
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER me.fredl.tide
        PRODUCT_BUNDLE_IDENTIFIER me.fredl.tide
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/platform/ios/Info.plist
        WIN32_EXECUTABLE TRUE
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks @loader_path/Frameworks"
        XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
        XCODE_ATTRIBUTE_SKIP_INSTALL "No"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "Yes"
        XCODE_ATTRIBUTE_COPY_PHASE_STRIP "No"
        XCODE_ATTRIBUTE_CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION "Yes"
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

    # LLVM & ios_system
    find_library(NOSYSTEM REQUIRED NAMES nosystem PATHS ${NOSYSTEM_FRAMEWORK} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLVM REQUIRED NAMES libLLVM PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)

    find_library(CLANGFW REQUIRED NAMES clang PATHS ${LLVM_TOOLS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLDFW REQUIRED NAMES lld PATHS ${LLVM_TOOLS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLDBFW REQUIRED NAMES lldb PATHS ${LLVM_TOOLS} CMAKE_FIND_ROOT_PATH_BOTH)

    find_library(COMPRESSION compression)
    find_library(XML2 xml2)
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(UIKIT_LIBRARY UIKit)

    # libclang for C++ ASTs
    find_library(LIBCLANG_C REQUIRED NAMES libclang PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # CMake and Ninja
    find_library(CMAKEFW REQUIRED NAMES cmake PATHS ${CMAKE_PATH} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(NINJAFW REQUIRED NAMES ninjaexe PATHS ${NINJA_PATH} CMAKE_FIND_ROOT_PATH_BOTH)

    # Unixy tools
    find_library(UNIXYFW REQUIRED NAMES unixy PATHS ${UNIXY_FRAMEWORK} CMAKE_FIND_ROOT_PATH_BOTH)

    # Debugger's lldb requires some trickery
    #set_source_files_properties(${LLDB}
    #    PROPERTIES
    #    MACOSX_PACKAGE_LOCATION Frameworks
    #    XCODE_FILE_ATTRIBUTES "CodeSignOnCopy"
    #)

    # Ship SDL headers generated as part of its build process
    #add_custom_command(TARGET ${PROJECT_NAME} PRE_BUILD
    #    COMMAND tar cvf "$<TARGET_FILE_DIR:${PROJECT_NAME}>/SDL.tar" -C "${CMAKE_CURRENT_BINARY_DIR}/../3rdparty/SDL/include" .  -C "${CMAKE_CURRENT_BINARY_DIR}/../3rdparty/SDL/include-config-debug" .
    #)

    # ANGLE for consumption by WebAssembly apps
    set(ANGLE_A "${CLANGRT_DIR}/angle-metal/arm64/libangle.a")
    set(ANGLE_HEADERS "${CLANGRT_DIR}/angle-metal/include")
endif()

if(APPLE AND NOT IOS)
    set (QT6GUIPRIVATE Qt6::GuiPrivate)
    set (ICONV iconv)

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        # Code
        platform/macos/integrationdelegate.mm
        platform/macos/macsystemglue.mm
        platform/macos/externalprojectpicker.mm
        platform/macos/imeventfixer.mm
        platform/macos/imfixerinstaller.mm
        platform/darwin/iosprojectlist.mm
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER me.fredl.tideformac
        PRODUCT_BUNDLE_IDENTIFIER me.fredl.tideformac
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/platform/macos/Info.plist
        WIN32_EXECUTABLE TRUE
        #XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks @loader_path/Frameworks"
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/Tide.entitlements"
        XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
        XCODE_ATTRIBUTE_SKIP_INSTALL "No"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "Yes"
        XCODE_ATTRIBUTE_COPY_PHASE_STRIP "No"
        XCODE_ATTRIBUTE_CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION "Yes"
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

    # LLVM
    find_library(LLVM REQUIRED NAMES LLVM PATHS ${LLVM_LIBS} CMAKE_FIND_ROOT_PATH_BOTH)

    find_library(COMPRESSION compression REQUIRED)
    find_library(XML2 xml2 REQUIRED)
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(SECURITY_LIBRARY Security REQUIRED)
    find_library(LIBZ z REQUIRED)

    # libclang for C++ ASTs
    message("LLVM_LIBS: ${LLVM_LIBS}")
    find_library(LIBCLANG_C REQUIRED NAMES clang PATHS ${LLVM_LIBS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LIBCLANG_CPP REQUIRED NAMES clang-cpp PATHS ${LLVM_LIBS} CMAKE_FIND_ROOT_PATH_BOTH)
    message(${LIBCLANG_CPP})

    # Debugger's lldb requires some trickery
    #set_source_files_properties(${LLDB}
    #    PROPERTIES
    #    MACOSX_PACKAGE_LOCATION Frameworks
    #    XCODE_FILE_ATTRIBUTES "CodeSignOnCopy"
    #)

    # Ship SDL headers generated as part of its build process
    #add_custom_command(TARGET ${PROJECT_NAME} PRE_BUILD
    #    COMMAND tar cvf "$<TARGET_FILE_DIR:${PROJECT_NAME}>/SDL.tar" -C "${CMAKE_CURRENT_BINARY_DIR}/../3rdparty/SDL/include" .  -C "${CMAKE_CURRENT_BINARY_DIR}/../3rdparty/SDL/include-config-debug" .
    #)

    # ANGLE for consumption by WebAssembly apps
    #set(ANGLE_A "${CLANGRT_DIR}/angle-metal/arm64/libangle.a")
    #set(ANGLE_HEADERS "${CLANGRT_DIR}/angle-metal/include")
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set (LIBZ z)
    set (OPENSSL crypto ssl)
    set (DL_LIBRARY dl)
    set (UDEV udev)

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        platform/posix/posixsystemglue.cpp
        platform/posix/projectdirectorypicker.cpp
        platform/posix/posixintegrationdelegate.cpp
        platform/posix/nullinputmethodfixerinstaller.cpp
        platform/posix/posixprojectlist.cpp
        platform/posix/clangcompiler.cpp
    )
endif()

include_directories(${PROJECT_NAME}
    # Wasm3 runtime
    ${WAMR_DIR}/core/iwasm/include
    ${UTILS_SHARED_DIR}

    # Angle headers
    ${ANGLE_HEADERS}

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
    ${QT6GUIPRIVATE}
    Qt6::Sql
    Qt6::Quick
    Qt6::Widgets
    ${NOSYSTEM}
    ${UDEV}
)

if(APPLE OR IOS)
    include (${WAMR_DIR}/build-scripts/runtime_lib.cmake)
    add_library(vmlibforplugins STATIC ${WAMR_RUNTIME_LIB_SOURCE})
    target_link_libraries (vmlibforplugins ${LLVM_AVAILABLE_LIBS})
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    include(${WAMR_DIR}/core/shared/utils/uncommon/shared_uncommon.cmake)
    include(${WAMR_DIR}/build-scripts/runtime_lib.cmake)
    add_library(vmlibforplugins STATIC ${WAMR_RUNTIME_LIB_SOURCE})
endif()

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Widgets
    Qt6::VirtualKeyboard
    ${LLVM}
    ${NOSYSTEM}
    ${COMPRESSION}
    ${XML2}
    ${FOUNDATION_LIBRARY}
    ${SECURITY_LIBRARY}
    ${UIKITLIBRARY}
    ${LIBZ}
    ${OPENSSL}

    # WAMR-based plugins
    vmlibforplugins

    # Wasm APIs and other enhancements
    ${ANGLE_A}

    # Platform abstraction
    ${PROJECT_NAME}-platform

    # Fit for git
    libgit2
    util
    pcre
    xdiff
    ntlmclient
    http-parser
    ${ICONV}

    ${DL_LIBRARY}

    #SDL2-static
)

# Deployment on iOS
if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
    set_property(TARGET ${PROJECT_NAME}
        PROPERTY XCODE_EMBED_FRAMEWORKS
        ${NOSYSTEM}
        ${LLVM}
        ${CLANGFW}
        ${LLDFW}
        ${LLDBFW}
        ${LIBCLANG_C}
        #${CMAKEFW}
        ${NINJAFW}
        ${UNIXYFW}
        ${PROJECT_NAME}-Formatter
        ${PROJECT_NAME}-Wasmrunner
        ${PROJECT_NAME}-Wasmrunnerfast
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)
endif()

# Deployment on macOS
if(APPLE AND NOT IOS)
    set_property(TARGET ${PROJECT_NAME}
        PROPERTY XCODE_EMBED_FRAMEWORKS
        ${LLVM}
        ${LIBCLANG_C}
        ${LIBCLANG_CPP}
        ${PROJECT_NAME}-Formatter
        ${PROJECT_NAME}-Wasmrunner
        ${PROJECT_NAME}-Wasmrunnerfast
        ${PROJECT_NAME}-Wasmrunnerjit
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)
endif()

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Non-resource bundling on macOS
if(APPLE AND NOT IOS)
    set(CMAKE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../3rdparty/CMake/build-mac/bin)
    set(NINJA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../3rdparty/ninja/build-mac)

    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND mkdir -p "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Frameworks"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LIBCLANG_CPP}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Frameworks/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Frameworks/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/clang-17" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/clang-17"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/clang-17"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/clang-17"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/clang" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/clang++" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/lld" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lld"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lld"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lld"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/wasm-ld" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/lldb" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/llvm-ar" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${LLVM_TOOLS}/llvm-ranlib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )

    # lldb
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )

    # llvm-ar
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ar"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ar"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ar"
    )

    # llvm-ranlib
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ranlib"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ranlib"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/llvm-ranlib"
    )

    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${CMAKE_PATH}/cmake" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND cp -a "${NINJA_PATH}/ninja" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${MACDEPLOYQT_EXECUTABLE} "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../.." "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/qml"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND codesign --deep --force --verify --verbose --timestamp --sign "Apple Development" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../.."
    )
endif()

# Resource & tool bundling on Linux
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    if(SNAP)
        set(LLVM_LIBRARIES "${SNAP_STAGE}/usr/lib")
    else()
        set(LLVM_LIBRARIES "${LLVM_DIR}/${LLVM_BUILD_DIR}/lib")
    endif()
    install(FILES "${CLANGRT_DIR}/sysroot.tar" DESTINATION ${CMAKE_INSTALL_PREFIX}/tide)
    install(FILES "${CLANGRT_DIR}/clang.tar" DESTINATION ${CMAKE_INSTALL_PREFIX}/tide)
    install(FILES "${CLANGRT_DIR}/boost.tar" DESTINATION ${CMAKE_INSTALL_PREFIX}/tide)
    install(FILES "${CLANGRT_DIR}/cmake.tar" DESTINATION ${CMAKE_INSTALL_PREFIX}/tide)
    install(FILES "${CLANGRT_DIR}/python.tar" DESTINATION ${CMAKE_INSTALL_PREFIX}/tide)

    install(FILES "${CLANGRT_DIR}/usr/lib/clang/17/wasi/libclang_rt.builtins-wasm32.a" DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/clang/17/lib/wasi)

    install(FILES "${LLVM_LIBRARIES}/libclang.so" DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(FILES "${LLVM_LIBRARIES}/libclang.so.17" DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(FILES "${LLVM_LIBRARIES}/libclang-cpp.so" DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(FILES "${LLVM_LIBRARIES}/libclang-cpp.so.17" DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(FILES "${LLVM_LIBRARIES}/libLLVM-17.so" DESTINATION ${CMAKE_INSTALL_LIBDIR})
endif()
