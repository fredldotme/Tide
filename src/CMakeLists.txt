cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide)
endif()

project(${PROJECT_NAME} VERSION 0.7 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

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
endif()

# Qt6
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick Sql QuickControls2)

include_directories(${PROJECT_NAME}
    # QMake parser
    ${QMAKEPARSER_DIR}/lib/include

    # tar implementation
    ${MICROTAR_DIR}/src

    # libclang
    ${LLVM_DIR}/clang/include
)

qt_add_executable(${PROJECT_NAME}
    # Code
    main.cpp
    common/directorylisting.cpp
    common/clangwrapper.cpp
    common/clangcompiler.cpp
    common/clang_main.cpp
    common/lld_main.cpp
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
    set (WAMR_BUILD_DEBUG_INTERP 0)
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
        # system() replacement through no_system
        ${NOSYSTEM}
        ${LLVM_DIR}

        # Clang & LLVM libraries
        ${LLVM_DIR}/llvm/include
        ${LLVM_DIR}/clang/include
        ${LLVM_DIR}/lld/include
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
        WIN32_EXECUTABLE TRUE
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks @loader_path/Frameworks"
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/Tide.entitlements"
        XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
        XCODE_ATTRIBUTE_SKIP_INSTALL "No"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "Yes"
        XCODE_ATTRIBUTE_COPY_PHASE_STRIP "No"
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

    # Clang as a library
    find_library(CLANG REQUIRED NAMES clang PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLD REQUIRED NAMES lld PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    #find_library(LLDB REQUIRED NAMES lldb PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(AR REQUIRED NAMES ar PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(DIS REQUIRED NAMES dis PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLD REQUIRED NAMES lld PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LLI REQUIRED NAMES lli PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(LINK REQUIRED NAMES link PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(NM REQUIRED NAMES nm PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)
    find_library(OPT REQUIRED NAMES opt PATHS ${LLVM_FRAMEWORKS} CMAKE_FIND_ROOT_PATH_BOTH)

    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(UIKIT_LIBRARY UIKit)

    # libclang for C++ ASTs
    find_library(LIBCLANG_CPP REQUIRED NAMES libclang PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # CMake and Ninja
    #find_library(CMAKEFW REQUIRED NAMES cmake PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)
    #find_library(NINJAFW REQUIRED NAMES ninja PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # Because CMake doesn't find the Header by itself currently
    include_directories(${PROJECT_NAME}
        ${LLVM_FRAMEWORKS}/no_system.framework/Headers
    )

    # Debugger's lldb requires some trickery
    #set_source_files_properties(${LLDB}
    #    PROPERTIES
    #    MACOSX_PACKAGE_LOCATION Frameworks
    #    XCODE_FILE_ATTRIBUTES "CodeSignOnCopy"
    #)

    # Set a few properties for file sharing & UI tweaks
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace UIFileSharingEnabled -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace LSSupportsOpeningDocumentsInPlace -bool true "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace LSApplicationCategoryType -string public.app-category.developer-tools "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )

    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND plutil -replace NSLocalNetworkUsageDescription -string "WebAssembly Micro Runtime support for sockets" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/Info.plist"
    )
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    if(${CMAKE_SYSTEM_PROCESSOR} STREQUAL "x86_64")
        set (WAMR_BUILD_TARGET "X86_64")
    else()
        set (WAMR_BUILD_TARGET "AARCH64")
    endif()

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
    set (WAMR_BUILD_SIMD 1)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_INTERP 0)
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

# Clang built-in
set(LIBCLANGAPINOTES "${LLVM_LIBS}/libclangAPINotes.a")
set(LIBCLANGARCMIGRATE "${LLVM_LIBS}/libclangARCMigrate.a")
set(LIBCLANGAST "${LLVM_LIBS}/libclangAST.a")
set(LIBCLANGASTMATCHERS "${LLVM_LIBS}/libclangASTMatchers.a")
set(LIBCLANGANALYSIS "${LLVM_LIBS}/libclangAnalysis.a")
set(LIBCLANGANALYSISFLOWSENSITIVE "${LLVM_LIBS}/libclangAnalysisFlowSensitive.a")
set(LIBCLANGBASIC "${LLVM_LIBS}/libclangBasic.a")
set(LIBCLANGCODEGEN "${LLVM_LIBS}/libclangCodeGen.a")
set(LIBCLANGCROSSTU "${LLVM_LIBS}/libclangCrossTU.a")
set(LIBCLANGDEPENDENCYSCANNING "${LLVM_LIBS}/libclangDependencyScanning.a")
set(LIBCLANGDRIVER "${LLVM_LIBS}/libclangDriver.a")
set(LIBCLANGDYNAMICASTMATCHERS "${LLVM_LIBS}/libclangDynamicASTMatchers.a")
set(LIBCLANGEDIT "${LLVM_LIBS}/libclangEdit.a")
set(LIBCLANGFORMAT "${LLVM_LIBS}/libclangFormat.a")
set(LIBCLANGFRONTEND "${LLVM_LIBS}/libclangFrontend.a")
set(LIBCLANGFRONTENDTOOL "${LLVM_LIBS}/libclangFrontendTool.a")
set(LIBCLANGHANDLECXX "${LLVM_LIBS}/libclangHandleCXX.a")
set(LIBCLANGHANDLELLVM "${LLVM_LIBS}/libclangHandleLLVM.a")
set(LIBCLANGINDEX "${LLVM_LIBS}/libclangIndex.a")
set(LIBCLANGINDEXSERIALIZATION "${LLVM_LIBS}/libclangIndexSerialization.a")
set(LIBCLANGINTERPRETER "${LLVM_LIBS}/libclangInterpreter.a")
set(LIBCLANGLEX "${LLVM_LIBS}/libclangLex.a")
set(LIBCLANGPARSE "${LLVM_LIBS}/libclangParse.a")
set(LIBCLANGREWRITE "${LLVM_LIBS}/libclangRewrite.a")
set(LIBCLANGREWRITEFRONTEND "${LLVM_LIBS}/libclangRewriteFrontend.a")
set(LIBCLANGSEMA "${LLVM_LIBS}/libclangSema.a")
set(LIBCLANGSERIALIZATION "${LLVM_LIBS}/libclangSerialization.a")
set(LIBCLANGSTATICANALYZERCHECKERS "${LLVM_LIBS}/libclangStaticAnalyzerCheckers.a")
set(LIBCLANGSTATICANALYZERCORE "${LLVM_LIBS}/libclangStaticAnalyzerCore.a")
set(LIBCLANGSTATICANALYZERFRONTEND "${LLVM_LIBS}/libclangStaticAnalyzerFrontend.a")
set(LIBCLANGTESTING "${LLVM_LIBS}/libclangTesting.a")
set(LIBCLANGTOOLING "${LLVM_LIBS}/libclangTooling.a")
set(LIBCLANGTOOLINGASTDIFF "${LLVM_LIBS}/libclangToolingASTDiff.a")
set(LIBCLANGTOOLINGCORE "${LLVM_LIBS}/libclangToolingCore.a")
set(LIBCLANGTOOLINGINCLUSIONS "${LLVM_LIBS}/libclangToolingInclusions.a")
set(LIBCLANGTOOLINGREFACTORING "${LLVM_LIBS}/libclangToolingRefactoring.a")
set(LIBCLANGTOOLINGSYNTAX "${LLVM_LIBS}/libclangToolingSyntax.a")
set(LIBCLANGTRANSFORMER "${LLVM_LIBS}/libclangTransformer.a")
set(LIBCLANGTOOL "${LLVM_LIBS}/libclang_tool.a")
set(CLANG_AS
    "${LIBCLANGAPINOTES}"
    "${LIBCLANGARCMIGRATE}"
    "${LIBCLANGAST}"
    "${LIBCLANGASTMATCHERS}"
    "${LIBCLANGANALYSIS}"
    "${LIBCLANGANALYSISFLOWSENSITIVE}"
    "${LIBCLANGBASIC}"
    "${LIBCLANGCODEGEN}"
    "${LIBCLANGCROSSTU}"
    "${LIBCLANGDEPENDENCYSCANNING}"
    "${LIBCLANGDRIVER}"
    "${LIBCLANGDYNAMICASTMATCHERS}"
    "${LIBCLANGEDIT}"
    "${LIBCLANGFORMAT}"
    "${LIBCLANGFRONTEND}"
    "${LIBCLANGFRONTENDTOOL}"
    "${LIBCLANGHANDLECXX}"
    "${LIBCLANGHANDLELLVM}"
    "${LIBCLANGINDEX}"
    "${LIBCLANGINDEXSERIALIZATION}"
    "${LIBCLANGINTERPRETER}"
    "${LIBCLANGLEX}"
    "${LIBCLANGPARSE}"
    "${LIBCLANGREWRITE}"
    "${LIBCLANGREWRITEFRONTEND}"
    "${LIBCLANGSEMA}"
    "${LIBCLANGSERIALIZATION}"
    "${LIBCLANGSTATICANALYZERCHECKERS}"
    "${LIBCLANGSTATICANALYZERCORE}"
    "${LIBCLANGSTATICANALYZERFRONTEND}"
    "${LIBCLANGTESTING}"
    "${LIBCLANGTOOLING}"
    "${LIBCLANGTOOLINGASTDIFF}"
    "${LIBCLANGTOOLINGCORE}"
    "${LIBCLANGTOOLINGINCLUSIONS}"
    "${LIBCLANGTOOLINGREFACTORING}"
    "${LIBCLANGTOOLINGSYNTAX}"
    "${LIBCLANGTRANSFORMER}"
    "${LIBCLANGTOOL}"
)

# lld built-in
set(LIBLLDCOFF "${LLVM_LIBS}/liblldCOFF.a")
set(LIBLLDCOMMON "${LLVM_LIBS}/liblldCommon.a")
set(LIBLLDELF "${LLVM_LIBS}/liblldELF.a")
set(LIBLLDMACHO "${LLVM_LIBS}/liblldMachO.a")
set(LIBLLDMINGW "${LLVM_LIBS}/liblldMinGW.a")
set(LIBLLDWASM "${LLVM_LIBS}/liblldWasm.a")
set(LLD_AS
    "${LIBLLDCOFF}"
    "${LIBLLDCOMMON}"
    "${LIBLLDELF}"
    "${LIBLLDMACHO}"
    "${LIBLLDMINGW}"
    "${LIBLLDWASM}"
)

target_link_libraries(${PROJECT_NAME}-platform
    PRIVATE
    Qt6::Core
    Qt6::Gui
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
    ${LLVM}
    ${NOSYSTEM}
    ${CLANG_AS}
    ${LLD_AS}
    ${FOUNDATION_LIBRARY}
    ${UIKITLIBRARY}
    ${PROJECT_NAME}-platform
    vmlib
)

# Deployment on iOS
if(IOS)
    set_property(TARGET ${PROJECT_NAME}
        PROPERTY XCODE_EMBED_FRAMEWORKS
        ${NOSYSTEM}
        ${LLVM}
        ${LIBCLANG_CPP}
        #${CLANG}
        #${LLD}
        #${CMAKEFW}
        #${NINJAFW}
        ${PROJECT_NAME}-Formatter
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY OFF)
    set_target_properties(${PROJECT_NAME} PROPERTIES XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)

    set(COMMANDDICTIONARY "${CMAKE_CURRENT_SOURCE_DIR}/commandDictionary.plist")
    target_sources(${PROJECT_NAME} PUBLIC ${COMMANDDICTIONARY})
    set_source_files_properties(${COMMANDDICTIONARY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
endif()

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
