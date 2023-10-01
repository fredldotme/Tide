cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide)
endif()

project(${PROJECT_NAME} VERSION 1.4.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

# Build against mixed Host + Cross environments (ie 6.5.2 macOS Qt with 6.5.3 iOS Qt)
set(QT_NO_PACKAGE_VERSION_CHECK ON)

if(CMAKE_BUILD_TYPE MATCHES "")
    set(CMAKE_BUILD_TYPE "Release")
endif()
message("Build type: ${CMAKE_BUILD_TYPE}")

# Artifacts from LLVM build
if(IOS OR CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
    if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
        set(LLVM_BUILD_DIR "build-iphonesimulator")
        set(LLVM_MODE "Release-iphonesimulator")
    else()
        set(LLVM_BUILD_DIR "build-iphoneos")
        set(LLVM_MODE "Release-iphoneos")
    endif()
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
set(LLVM_HEADERS ${LLVM_DIR}/${LLVM_BUILD_DIR}/lib/clang/14.0.0/include)
set(CLANGRT ${CLANGRT_DIR}/lib/wasi)

if(IOS)
    resource(THE_SYSROOT ${CLANGRT_DIR} Resources the-sysroot.tar)
    resource(BOOST_TAR ${CLANGRT_DIR} Resources boost.tar)
    set (WAMR_COMPILER ${WAMR_DIR}/wamr-compiler/main.c)
    set (IWAMR ${WAMR_DIR}/product-mini/platforms/darwin/main.c)
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
    utility/wasmrunner.cpp
    utility/linuxruntimemanager.cpp
    utility/searchandreplace.cpp
    utility/debugger.cpp
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

    # IWASM
    ${IWAMR}

    # AOT compiler
    ${WAMR_COMPILER}

    # tar implementation
    ${MICROTAR_DIR}/src/microtar.c

    # Ship the sysroot
    ${THE_SYSROOT}
    ${BOOST_TAR}

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

    qt_add_library(${PROJECT_NAME}-platform
        STATIC

        # Code
        platform/ios/iosprojectlist.mm
        platform/ios/iosintegrationdelegate.mm
        platform/ios/externalprojectpicker.mm
        platform/ios/iossystemglue.mm
        platform/ios/imeventfixer.mm
        platform/ios/imfixerinstaller.mm
        platform/ios/clangcompiler.cpp
    )

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

    find_library(COMPRESSION compression)
    find_library(XML2 xml2)
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(UIKIT_LIBRARY UIKit)

    # libclang for C++ ASTs
    find_library(LIBCLANG_CPP REQUIRED NAMES libclang PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # CMake and Ninja
    #find_library(CMAKEFW REQUIRED NAMES cmake PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)
    #find_library(NINJAFW REQUIRED NAMES ninja PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

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

    # Clang built-in
    file(GLOB CLANG_AS ${LLVM_LIBS}/libclang*.a)
    list(FILTER CLANG_AS EXCLUDE REGEX ".*libclang_rt.*.a$")

    # lld & lldb built-in
    file(GLOB LLD_LLDB_AS ${LLVM_LIBS}/liblld*.a)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    if(${CMAKE_SYSTEM_PROCESSOR} STREQUAL "x86_64")
        set (WAMR_BUILD_TARGET "X86_64")
    else()
        set (WAMR_BUILD_TARGET "AARCH64")
    endif()

    set (WAMR_BUILD_PLATFORM "linux")
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_FAST_INTERP 0)
    set (WAMR_BUILD_AOT 1)
    set (WAMR_BUILD_JIT 0)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 1)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_INTERP 1)
    set (WAMR_BUILD_MULTI_MODULE 1)
    set (WAMR_BUILD_EXCE_HANDLING 1)
    set (WAMR_BUILD_REF_TYPES 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC=1 -DWASM_ENABLE_WAMR_COMPILER=1)

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
    ${NOSYSTEM}
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
    ${LLVM_AS}
    ${NOSYSTEM}
    ${LIBCLANG_CPP}
    ${CLANG_AS}
    ${LLD_LLDB_AS}
    ${COMPRESSION}
    ${XML2}
    ${FOUNDATION_LIBRARY}
    ${UIKITLIBRARY}
    ${ANGLE_A}
    ${PROJECT_NAME}-platform
    vmlib
    #SDL2-static
)

# Deployment on iOS
if(IOS)
    set_property(TARGET ${PROJECT_NAME}
        PROPERTY XCODE_EMBED_FRAMEWORKS
        ${NOSYSTEM}
        ${LLVM}
        ${LIBCLANG_CPP}
        #${CMAKEFW}
        #${NINJAFW}
        ${PROJECT_NAME}-Formatter
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)
endif()

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
