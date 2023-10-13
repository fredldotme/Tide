cmake_minimum_required(VERSION 3.20)

if(IOS OR APPLE)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide)
endif()

project(${PROJECT_NAME} VERSION 1.6.0 LANGUAGES C CXX)

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
elseif(APPLE)
    set(LLVM_BUILD_DIR "build_osx")
    set(LLVM_MODE "Release-macos")
    set(OS "osx")
    set(CMAKE_MACOSX_BUNDLE ON)
    set(QT6_IS_SHARED_LIBS_BUILD ON)
    set(LLVM_TOOLS ${LLVM_DIR}/${LLVM_BUILD_DIR}/bin)
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
    resource(THE_SYSROOT ${CLANGRT_DIR} Resources the-sysroot.tar)
    resource(BOOST_TAR ${CLANGRT_DIR} Resources boost.tar)
    resource(CMAKE_MODULES ${CLANGRT_DIR} Resources cmake.tar)
    resource(PYTHON_WASM ${CLANGRT_DIR} Resources python.tar)
    resource(COMMANDSYAML ${CMAKE_CURRENT_SOURCE_DIR} Resources commands.yaml)
endif()

if(APPLE)
    resource(THE_SYSROOT ${CLANGRT_DIR} Resources the-sysroot.tar)
    resource(BOOST_TAR ${CLANGRT_DIR} Resources boost.tar)
    resource(CMAKE_MODULES ${CLANGRT_DIR} Resources cmake.tar)
    resource(PYTHON_WASM ${CLANGRT_DIR} Resources python.tar)
endif()

# Qt6
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Widgets Qml Quick Sql QuickControls2 QuickEffectsPrivate)

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
    projects/builderbackend.h

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

    # Ship the sysroot
    ${THE_SYSROOT}
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

    NO_LINT
)

# Build toolchain itself
set(LLVM_FRAMEWORKS ${LLVM_DIR}/${LLVM_BUILD_DIR}/build/${LLVM_MODE})
set(LLVM_LIBS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib)
set(LLVM_INCLUDES ${LLVM_DIR}/${LLVM_BUILD_DIR}/include)
set(LLVM_CLANG_INCLUDES ${LLVM_DIR}/${LLVM_BUILD_DIR}/tools/clang/include)
set(NOSYSTEM_FRAMEWORK ${LLVM_DIR}/no_system/${LLVM_BUILD_DIR}/Debug-iphoneos)

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

    # Platform abstraction
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/ios
)

if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator OR CMAKE_OSX_SYSROOT MATCHES iphoneos)
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
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
        WIN32_EXECUTABLE TRUE
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks @loader_path/Frameworks"
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
    find_library(CMAKELIB REQUIRED NAMES CMakeLib PATHS ${CMAKE_PATH} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMSYSFW REQUIRED NAMES cmsys PATHS ${CMAKE_PATH}/kwsys CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMLIBUV REQUIRED NAMES cmlibuv PATHS ${CMAKE_UTIL_PATH}/cmlibuv CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMEXPAT REQUIRED NAMES cmexpat PATHS ${CMAKE_UTIL_PATH}/cmexpat CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMZLIB REQUIRED NAMES cmzlib PATHS ${CMAKE_UTIL_PATH}/cmzlib CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMLIBLZMA REQUIRED NAMES cmliblzma PATHS ${CMAKE_UTIL_PATH}/cmliblzma CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMJSONCPP REQUIRED NAMES cmjsoncpp PATHS ${CMAKE_UTIL_PATH}/cmjsoncpp CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMSTD REQUIRED NAMES cmstd PATHS ${CMAKE_UTIL_PATH}/std CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMLIBRHASH REQUIRED NAMES cmlibrhash PATHS ${CMAKE_UTIL_PATH}/cmlibrhash CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMBZIP2 REQUIRED NAMES cmbzip2 PATHS ${CMAKE_UTIL_PATH}/cmbzip2 CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMCURL REQUIRED NAMES cmcurl PATHS ${CMAKE_UTIL_PATH}/cmcurl/lib CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMLIBARCHIVE REQUIRED NAMES cmlibarchive PATHS ${CMAKE_UTIL_PATH}/cmlibarchive/libarchive CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMNGHTTP2 REQUIRED NAMES cmnghttp2 PATHS ${CMAKE_UTIL_PATH}/cmnghttp2 CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(CMZSTD REQUIRED NAMES cmzstd PATHS ${CMAKE_UTIL_PATH}/cmzstd CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(NINJAFW REQUIRED NAMES ninjaexe PATHS ${NINJA_PATH} CMAKE_FIND_ROOT_PATH_BOTH)

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
        MACOSX_BUNDLE_GUI_IDENTIFIER me.fredl.tide
        PRODUCT_BUNDLE_IDENTIFIER me.fredl.tide
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
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

    find_library(COMPRESSION compression)
    find_library(XML2 xml2)
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(UIKIT_LIBRARY UIKit)

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
    find_library(LLVM REQUIRED NAMES libLLVM-15.so PATHS /usr/lib/llvm-15/lib)

    include_directories(${PROJECT_NAME}
        "/usr/include/llvm-15"
    )

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
    Qt6::GuiPrivate
    Qt6::Sql
    Qt6::Quick
    Qt6::Widgets
    ${NOSYSTEM}
    ${CMAKEFW}
    ${CMAKELIB}
    ${CMSYSFW}
    ${CMLIBUV}
    ${CMEXPAT}
    ${CMZLIB}
    ${CMLIBLZMA}
    ${CMJSONCPP}
    ${CMSTD}
    ${CMLIBRHASH}
    ${CMLIBARCHIVE}
    ${CMZSTD}
    ${CMBZIP2}
    ${CMNGHTTP2}
    ${CMCURL}
    ${NINJAFW}
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Widgets
    ${LLVM}
    ${NOSYSTEM}
    ${COMPRESSION}
    ${XML2}
    ${FOUNDATION_LIBRARY}
    ${UIKITLIBRARY}
    ${ANGLE_A}
    ${PROJECT_NAME}-platform

    # Fit for git
    libgit2
    util
    pcre
    xdiff
    ntlmclient
    http-parser
    iconv

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
        COMMAND install_name_tool -change "@rpath/libclang-cpp.dylib" "@rpath/../Frameworks/libclang-cpp.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/../Frameworks/libLLVM.dylib" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND install_name_tool -add_rpath "@loader_path/../Frameworks" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/lldb"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${MACDEPLOYQT_EXECUTABLE} "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../.." "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/qml"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND codesign --deep --force --verify --verbose --timestamp --sign "Apple Development" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../.."
    )
endif()
