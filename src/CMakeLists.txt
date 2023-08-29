cmake_minimum_required(VERSION 3.20)

if(IOS)
    set(PROJECT_NAME Tide)
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(PROJECT_NAME tide)
endif()

project(${PROJECT_NAME} VERSION 0.9 LANGUAGES C CXX)

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

    # IWASM
    ${WAMR_DIR}/product-mini/platforms/darwin/main.c

    # Enable once WAMR issues are sorted out
    #${WAMR_DIR}/wamr-compiler/main.c

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
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfloat-abi=hard")
    set (WAMR_BUILD_PLATFORM "darwin")
    if(CMAKE_OSX_SYSROOT MATCHES iphonesimulator)
        set (WAMR_BUILD_TARGET "X86_64")
    else()
        set (WAMR_BUILD_TARGET "AARCH64")
    endif()
    set (WAMR_BUILD_INTERP 1)
    set (WAMR_BUILD_AOT 0)
    set (WAMR_BUILD_LIBC_BUILTIN 0)
    set (WAMR_BUILD_LIBC_WASI 1)
    set (WAMR_BUILD_LIB_WASI_THREADS 1)
    set (WAMR_BUILD_SHARED_MEMORY 1)
    set (WAMR_BUILD_TAIL_CALL 1)
    set (WAMR_BUILD_LIBC_UVWASI 0)
    set (WAMR_BUILD_SIMD 0)
    set (WAMR_DISABLE_HW_BOUND_CHECK 1)
    set (WAMR_BUILD_DEBUG_AOT 0)
    set (WASM_ENABLE_THREAD_MGR 1)
    set (WAMR_BUILD_MINI_LOADER 0)
    set (WAMR_BUILD_DEBUG_INTERP 1)
    set (WAMR_ROOT_DIR ${WAMR_DIR})
    add_definitions(-DWASM_UINT32_IS_ATOMIC -DIWASM_AS_LIBRARY)

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

    find_library(COMPRESSION compression)
    find_library(XML2 xml2)
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(UIKIT_LIBRARY UIKit)

    # libclang for C++ ASTs
    find_library(LIBCLANG_CPP REQUIRED NAMES libclang PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

    # CMake and Ninja
    find_library(CMAKEFW REQUIRED NAMES cmake PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)
    #find_library(NINJAFW REQUIRED NAMES ninja PATHS ${CLANGRT_DIR} CMAKE_FIND_ROOT_PATH_BOTH)

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

    # ANGLE for consumption by WebAssembly apps
    set(ANGLE_A "${CLANGRT_DIR}/angle-metal/arm64/libangle.a")
    set(ANGLE_HEADERS "${CLANGRT_DIR}/angle-metal/include")

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

    # LLDB built-in
    set(LIBLLDB "${LLVM_LIBS}/liblldb.a")
    set(LIBLLDBBREAKPOINT "${LLVM_LIBS}/liblldbBreakpoint.a")
    set(LIBLLDBCOMMANDS "${LLVM_LIBS}/liblldbCommands.a")
    set(LIBLLDBCORE "${LLVM_LIBS}/liblldbCore.a")
    set(LIBLLDBDATAFORMATTERS "${LLVM_LIBS}/liblldbDataFormatters.a")
    set(LIBLLDBEXPRESSION "${LLVM_LIBS}/liblldbExpression.a")
    set(LIBLLDBHOST "${LLVM_LIBS}/liblldbHost.a")
    set(LIBLLDBHOSTMACOSXOBJCXX "${LLVM_LIBS}/liblldbHostMacOSXObjCXX.a")
    set(LIBLLDBINITIALIZATION "${LLVM_LIBS}/liblldbInitialization.a")
    set(LIBLLDBINTERPRETER "${LLVM_LIBS}/liblldbInterpreter.a")
    set(LIBLLDBPLUGINAPPLEOBJCRUNTIME "${LLVM_LIBS}/liblldbPluginAppleObjCRuntime.a")
    set(LIBLLDBPLUGINARCHITECTUREAARCH64 "${LLVM_LIBS}/liblldbPluginArchitectureAArch64.a")
    set(LIBLLDBPLUGINARCHITECTUREARM "${LLVM_LIBS}/liblldbPluginArchitectureArm.a")
    set(LIBLLDBPLUGINARCHITECTUREMIPS "${LLVM_LIBS}/liblldbPluginArchitectureMips.a")
    set(LIBLLDBPLUGINARCHITECTUREPPC64 "${LLVM_LIBS}/liblldbPluginArchitecturePPC64.a")
    set(LIBLLDBPLUGINCPPRUNTIME "${LLVM_LIBS}/liblldbPluginCPPRuntime.a")
    set(LIBLLDBPLUGINCPLUSPLUSLANGUAGE "${LLVM_LIBS}/liblldbPluginCPlusPlusLanguage.a")
    set(LIBLLDBPLUGINCXXITANIUMABI "${LLVM_LIBS}/liblldbPluginCXXItaniumABI.a")
    set(LIBLLDBPLUGINCLANGCOMMON "${LLVM_LIBS}/liblldbPluginClangCommon.a")
    set(LIBLLDBPLUGINCLANGREPL "${LLVM_LIBS}/liblldbPluginClangREPL.a")
    set(LIBLLDBPLUGINDISASSEMBLERLLVMC "${LLVM_LIBS}/liblldbPluginDisassemblerLLVMC.a")
    set(LIBLLDBPLUGINDYNAMICLOADERDARWINKERNEL "${LLVM_LIBS}/liblldbPluginDynamicLoaderDarwinKernel.a")
    set(LIBLLDBPLUGINDYNAMICLOADERHEXAGONDYLD "${LLVM_LIBS}/liblldbPluginDynamicLoaderHexagonDYLD.a")
    set(LIBLLDBPLUGINDYNAMICLOADERMACOSXDYLD "${LLVM_LIBS}/liblldbPluginDynamicLoaderMacOSXDYLD.a")
    set(LIBLLDBPLUGINDYNAMICLOADERPOSIXDYLD "${LLVM_LIBS}/liblldbPluginDynamicLoaderPosixDYLD.a")
    set(LIBLLDBPLUGINDYNAMICLOADERSTATIC "${LLVM_LIBS}/liblldbPluginDynamicLoaderStatic.a")
    set(LIBLLDBPLUGINDYNAMICLOADERWASMDYLD "${LLVM_LIBS}/liblldbPluginDynamicLoaderWasmDYLD.a")
    set(LIBLLDBPLUGINDYNAMICLOADERWINDOWSDYLD "${LLVM_LIBS}/liblldbPluginDynamicLoaderWindowsDYLD.a")
    set(LIBLLDBPLUGINEXPRESSIONPARSERCLANG "${LLVM_LIBS}/liblldbPluginExpressionParserClang.a")
    set(LIBLLDBPLUGININSTRUCTIONARM "${LLVM_LIBS}/liblldbPluginInstructionARM.a")
    set(LIBLLDBPLUGININSTRUCTIONARM64 "${LLVM_LIBS}/liblldbPluginInstructionARM64.a")
    set(LIBLLDBPLUGININSTRUCTIONMIPS "${LLVM_LIBS}/liblldbPluginInstructionMIPS.a")
    set(LIBLLDBPLUGININSTRUCTIONMIPS64 "${LLVM_LIBS}/liblldbPluginInstructionMIPS64.a")
    set(LIBLLDBPLUGININSTRUCTIONPPC64 "${LLVM_LIBS}/liblldbPluginInstructionPPC64.a")
    set(LIBLLDBPLUGININSTRUMENTATIONRUNTIMEASAN "${LLVM_LIBS}/liblldbPluginInstrumentationRuntimeASan.a")
    set(LIBLLDBPLUGININSTRUMENTATIONRUNTIMEMAINTHREADCHECKER "${LLVM_LIBS}/liblldbPluginInstrumentationRuntimeMainThreadChecker.a")
    set(LIBLLDBPLUGININSTRUMENTATIONRUNTIMETSAN "${LLVM_LIBS}/liblldbPluginInstrumentationRuntimeTSan.a")
    set(LIBLLDBPLUGININSTRUMENTATIONRUNTIMEUBSAN "${LLVM_LIBS}/liblldbPluginInstrumentationRuntimeUBSan.a")
    set(LIBLLDBPLUGINJITLOADERGDB "${LLVM_LIBS}/liblldbPluginJITLoaderGDB.a")
    set(LIBLLDBPLUGINMEMORYHISTORYASAN "${LLVM_LIBS}/liblldbPluginMemoryHistoryASan.a")
    set(LIBLLDBPLUGINOBJCLANGUAGE "${LLVM_LIBS}/liblldbPluginObjCLanguage.a")
    set(LIBLLDBPLUGINOBJCPLUSPLUSLANGUAGE "${LLVM_LIBS}/liblldbPluginObjCPlusPlusLanguage.a")
    set(LIBLLDBPLUGINOBJCRUNTIME "${LLVM_LIBS}/liblldbPluginObjCRuntime.a")
    set(LIBLLDBPLUGINOBJECTCONTAINERBSDARCHIVE "${LLVM_LIBS}/liblldbPluginObjectContainerBSDArchive.a")
    set(LIBLLDBPLUGINOBJECTCONTAINERMACHOARCHIVE "${LLVM_LIBS}/liblldbPluginObjectContainerMachOArchive.a")
    set(LIBLLDBPLUGINOBJECTFILEBREAKPAD "${LLVM_LIBS}/liblldbPluginObjectFileBreakpad.a")
    set(LIBLLDBPLUGINOBJECTFILEELF "${LLVM_LIBS}/liblldbPluginObjectFileELF.a")
    set(LIBLLDBPLUGINOBJECTFILEJIT "${LLVM_LIBS}/liblldbPluginObjectFileJIT.a")
    set(LIBLLDBPLUGINOBJECTFILEMACHO "${LLVM_LIBS}/liblldbPluginObjectFileMachO.a")
    set(LIBLLDBPLUGINOBJECTFILEMINIDUMP "${LLVM_LIBS}/liblldbPluginObjectFileMinidump.a")
    set(LIBLLDBPLUGINOBJECTFILEPDB "${LLVM_LIBS}/liblldbPluginObjectFilePDB.a")
    set(LIBLLDBPLUGINOBJECTFILEPECOFF "${LLVM_LIBS}/liblldbPluginObjectFilePECOFF.a")
    set(LIBLLDBPLUGINOBJECTFILEWASM "${LLVM_LIBS}/liblldbPluginObjectFileWasm.a")
    set(LIBLLDBPLUGINPLATFORMANDROID "${LLVM_LIBS}/liblldbPluginPlatformAndroid.a")
    set(LIBLLDBPLUGINPLATFORMFREEBSD "${LLVM_LIBS}/liblldbPluginPlatformFreeBSD.a")
    set(LIBLLDBPLUGINPLATFORMGDB "${LLVM_LIBS}/liblldbPluginPlatformGDB.a")
    set(LIBLLDBPLUGINPLATFORMLINUX "${LLVM_LIBS}/liblldbPluginPlatformLinux.a")
    set(LIBLLDBPLUGINPLATFORMMACOSX "${LLVM_LIBS}/liblldbPluginPlatformMacOSX.a")
    set(LIBLLDBPLUGINPLATFORMMACOSXOBJCXX "${LLVM_LIBS}/liblldbPluginPlatformMacOSXObjCXX.a")
    set(LIBLLDBPLUGINPLATFORMNETBSD "${LLVM_LIBS}/liblldbPluginPlatformNetBSD.a")
    set(LIBLLDBPLUGINPLATFORMOPENBSD "${LLVM_LIBS}/liblldbPluginPlatformOpenBSD.a")
    set(LIBLLDBPLUGINPLATFORMPOSIX "${LLVM_LIBS}/liblldbPluginPlatformPOSIX.a")
    set(LIBLLDBPLUGINPLATFORMQEMUUSER "${LLVM_LIBS}/liblldbPluginPlatformQemuUser.a")
    set(LIBLLDBPLUGINPLATFORMWASM "${LLVM_LIBS}/liblldbPluginPlatformWasm.a")
    set(LIBLLDBPLUGINPLATFORMWINDOWS "${LLVM_LIBS}/liblldbPluginPlatformWindows.a")
    set(LIBLLDBPLUGINPROCESSELFCORE "${LLVM_LIBS}/liblldbPluginProcessElfCore.a")
    set(LIBLLDBPLUGINPROCESSGDBREMOTE "${LLVM_LIBS}/liblldbPluginProcessGDBRemote.a")
    set(LIBLLDBPLUGINPROCESSMACHCORE "${LLVM_LIBS}/liblldbPluginProcessMachCore.a")
    set(LIBLLDBPLUGINPROCESSMINIDUMP "${LLVM_LIBS}/liblldbPluginProcessMinidump.a")
    set(LIBLLDBPLUGINPROCESSUTILITY "${LLVM_LIBS}/liblldbPluginProcessUtility.a")
    set(LIBLLDBPLUGINPROCESSWASM "${LLVM_LIBS}/liblldbPluginProcessWasm.a")
    set(LIBLLDBPLUGINRENDERSCRIPTRUNTIME "${LLVM_LIBS}/liblldbPluginRenderScriptRuntime.a")
    set(LIBLLDBPLUGINSCRIPTINTERPRETERNONE "${LLVM_LIBS}/liblldbPluginScriptInterpreterNone.a")
    set(LIBLLDBPLUGINSCRIPTEDPROCESS "${LLVM_LIBS}/liblldbPluginScriptedProcess.a")
    set(LIBLLDBPLUGINSTRUCTUREDDATADARWINLOG "${LLVM_LIBS}/liblldbPluginStructuredDataDarwinLog.a")
    set(LIBLLDBPLUGINSYMBOLFILEBREAKPAD "${LLVM_LIBS}/liblldbPluginSymbolFileBreakpad.a")
    set(LIBLLDBPLUGINSYMBOLFILEDWARF "${LLVM_LIBS}/liblldbPluginSymbolFileDWARF.a")
    set(LIBLLDBPLUGINSYMBOLFILENATIVEPDB "${LLVM_LIBS}/liblldbPluginSymbolFileNativePDB.a")
    set(LIBLLDBPLUGINSYMBOLFILEPDB "${LLVM_LIBS}/liblldbPluginSymbolFilePDB.a")
    set(LIBLLDBPLUGINSYMBOLFILESYMTAB "${LLVM_LIBS}/liblldbPluginSymbolFileSymtab.a")
    set(LIBLLDBPLUGINSYMBOLVENDORELF "${LLVM_LIBS}/liblldbPluginSymbolVendorELF.a")
    set(LIBLLDBPLUGINSYMBOLVENDORMACOSX "${LLVM_LIBS}/liblldbPluginSymbolVendorMacOSX.a")
    set(LIBLLDBPLUGINSYMBOLVENDORWASM "${LLVM_LIBS}/liblldbPluginSymbolVendorWasm.a")
    set(LIBLLDBPLUGINSYSTEMRUNTIMEMACOSX "${LLVM_LIBS}/liblldbPluginSystemRuntimeMacOSX.a")
    set(LIBLLDBPLUGINTRACECOMMON "${LLVM_LIBS}/liblldbPluginTraceCommon.a")
    set(LIBLLDBPLUGINTRACEEXPORTERCTF "${LLVM_LIBS}/liblldbPluginTraceExporterCTF.a")
    set(LIBLLDBPLUGINTRACEEXPORTERCOMMON "${LLVM_LIBS}/liblldbPluginTraceExporterCommon.a")
    set(LIBLLDBPLUGINTYPESYSTEMCLANG "${LLVM_LIBS}/liblldbPluginTypeSystemClang.a")
    set(LIBLLDBPLUGINUNWINDASSEMBLYINSTEMULATION "${LLVM_LIBS}/liblldbPluginUnwindAssemblyInstEmulation.a")
    set(LIBLLDBPLUGINUNWINDASSEMBLYX86 "${LLVM_LIBS}/liblldbPluginUnwindAssemblyX86.a")
    set(LIBLLDBPLUGINWASMDWARFEVALUATORFACTORY "${LLVM_LIBS}/liblldbPluginWasmDWARFEvaluatorFactory.a")
    set(LIBLLDBSYMBOL "${LLVM_LIBS}/liblldbSymbol.a")
    set(LIBLLDBTARGET "${LLVM_LIBS}/liblldbTarget.a")
    set(LIBLLDBUTILITY "${LLVM_LIBS}/liblldbUtility.a")
    set(LIBLLDBVERSION "${LLVM_LIBS}/liblldbVersion.a")
    set(LIBLLDB_TOOL "${LLVM_LIBS}/liblldb_tool.a")

    set(LLDB_AS
        "${LIBLLDB}"
        "${LIBLLDBBREAKPOINT}"
        "${LIBLLDBCOMMANDS}"
        "${LIBLLDBCORE}"
        "${LIBLLDBDATAFORMATTERS}"
        "${LIBLLDBEXPRESSION}"
        "${LIBLLDBHOST}"
        "${LIBLLDBHOSTMACOSXOBJCXX}"
        "${LIBLLDBINITIALIZATION}"
        "${LIBLLDBINTERPRETER}"
        "${LIBLLDBPLUGINAPPLEOBJCRUNTIME}"
        "${LIBLLDBPLUGINARCHITECTUREAARCH64}"
        "${LIBLLDBPLUGINARCHITECTUREARM}"
        "${LIBLLDBPLUGINARCHITECTUREMIPS}"
        "${LIBLLDBPLUGINARCHITECTUREPPC64}"
        "${LIBLLDBPLUGINCPPRUNTIME}"
        "${LIBLLDBPLUGINCPLUSPLUSLANGUAGE}"
        "${LIBLLDBPLUGINCXXITANIUMABI}"
        "${LIBLLDBPLUGINCLANGCOMMON}"
        "${LIBLLDBPLUGINCLANGREPL}"
        "${LIBLLDBPLUGINDISASSEMBLERLLVMC}"
        "${LIBLLDBPLUGINDYNAMICLOADERDARWINKERNEL}"
        "${LIBLLDBPLUGINDYNAMICLOADERHEXAGONDYLD}"
        "${LIBLLDBPLUGINDYNAMICLOADERMACOSXDYLD}"
        "${LIBLLDBPLUGINDYNAMICLOADERPOSIXDYLD}"
        "${LIBLLDBPLUGINDYNAMICLOADERSTATIC}"
        "${LIBLLDBPLUGINDYNAMICLOADERWASMDYLD}"
        "${LIBLLDBPLUGINDYNAMICLOADERWINDOWSDYLD}"
        "${LIBLLDBPLUGINEXPRESSIONPARSERCLANG}"
        "${LIBLLDBPLUGININSTRUCTIONARM}"
        "${LIBLLDBPLUGININSTRUCTIONARM64}"
        "${LIBLLDBPLUGININSTRUCTIONMIPS}"
        "${LIBLLDBPLUGININSTRUCTIONMIPS64}"
        "${LIBLLDBPLUGININSTRUCTIONPPC64}"
        "${LIBLLDBPLUGININSTRUMENTATIONRUNTIMEASAN}"
        "${LIBLLDBPLUGININSTRUMENTATIONRUNTIMEMAINTHREADCHECKER}"
        "${LIBLLDBPLUGININSTRUMENTATIONRUNTIMETSAN}"
        "${LIBLLDBPLUGININSTRUMENTATIONRUNTIMEUBSAN}"
        "${LIBLLDBPLUGINJITLOADERGDB}"
        "${LIBLLDBPLUGINMEMORYHISTORYASAN}"
        "${LIBLLDBPLUGINOBJCLANGUAGE}"
        "${LIBLLDBPLUGINOBJCPLUSPLUSLANGUAGE}"
        "${LIBLLDBPLUGINOBJCRUNTIME}"
        "${LIBLLDBPLUGINOBJECTCONTAINERBSDARCHIVE}"
        "${LIBLLDBPLUGINOBJECTCONTAINERMACHOARCHIVE}"
        "${LIBLLDBPLUGINOBJECTFILEBREAKPAD}"
        "${LIBLLDBPLUGINOBJECTFILEELF}"
        "${LIBLLDBPLUGINOBJECTFILEJIT}"
        "${LIBLLDBPLUGINOBJECTFILEMACHO}"
        "${LIBLLDBPLUGINOBJECTFILEMINIDUMP}"
        "${LIBLLDBPLUGINOBJECTFILEPDB}"
        "${LIBLLDBPLUGINOBJECTFILEPECOFF}"
        "${LIBLLDBPLUGINOBJECTFILEWASM}"
        "${LIBLLDBPLUGINPLATFORMANDROID}"
        "${LIBLLDBPLUGINPLATFORMFREEBSD}"
        "${LIBLLDBPLUGINPLATFORMGDB}"
        "${LIBLLDBPLUGINPLATFORMLINUX}"
        "${LIBLLDBPLUGINPLATFORMMACOSX}"
        "${LIBLLDBPLUGINPLATFORMMACOSXOBJCXX}"
        "${LIBLLDBPLUGINPLATFORMNETBSD}"
        "${LIBLLDBPLUGINPLATFORMOPENBSD}"
        "${LIBLLDBPLUGINPLATFORMPOSIX}"
        "${LIBLLDBPLUGINPLATFORMQEMUUSER}"
        "${LIBLLDBPLUGINPLATFORMWASM}"
        "${LIBLLDBPLUGINPLATFORMWINDOWS}"
        "${LIBLLDBPLUGINPROCESSELFCORE}"
        "${LIBLLDBPLUGINPROCESSGDBREMOTE}"
        "${LIBLLDBPLUGINPROCESSMACHCORE}"
        "${LIBLLDBPLUGINPROCESSMINIDUMP}"
        "${LIBLLDBPLUGINPROCESSUTILITY}"
        "${LIBLLDBPLUGINPROCESSWASM}"
        "${LIBLLDBPLUGINRENDERSCRIPTRUNTIME}"
        "${LIBLLDBPLUGINSCRIPTINTERPRETERNONE}"
        "${LIBLLDBPLUGINSCRIPTEDPROCESS}"
        "${LIBLLDBPLUGINSTRUCTUREDDATADARWINLOG}"
        "${LIBLLDBPLUGINSYMBOLFILEBREAKPAD}"
        "${LIBLLDBPLUGINSYMBOLFILEDWARF}"
        "${LIBLLDBPLUGINSYMBOLFILENATIVEPDB}"
        "${LIBLLDBPLUGINSYMBOLFILEPDB}"
        "${LIBLLDBPLUGINSYMBOLFILESYMTAB}"
        "${LIBLLDBPLUGINSYMBOLVENDORELF}"
        "${LIBLLDBPLUGINSYMBOLVENDORMACOSX}"
        "${LIBLLDBPLUGINSYMBOLVENDORWASM}"
        "${LIBLLDBPLUGINSYSTEMRUNTIMEMACOSX}"
        "${LIBLLDBPLUGINTRACECOMMON}"
        "${LIBLLDBPLUGINTRACEEXPORTERCTF}"
        "${LIBLLDBPLUGINTRACEEXPORTERCOMMON}"
        "${LIBLLDBPLUGINTYPESYSTEMCLANG}"
        "${LIBLLDBPLUGINUNWINDASSEMBLYINSTEMULATION}"
        "${LIBLLDBPLUGINUNWINDASSEMBLYX86}"
        "${LIBLLDBPLUGINWASMDWARFEVALUATORFACTORY}"
        "${LIBLLDBSYMBOL}"
        "${LIBLLDBTARGET}"
        "${LIBLLDBUTILITY}"
        "${LIBLLDBVERSION}"
        "${LIBLLDB_TOOL}"
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
    set (WAMR_BUILD_FAST_INTERP 0)
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
    set (WAMR_BUILD_DEBUG_INTERP 1)
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

# WAMR + AOT
include(${WAMR_DIR}/core/shared/utils/shared_utils.cmake)
include(${WAMR_DIR}/core/shared/utils/uncommon/shared_uncommon.cmake)
include(${WAMR_DIR}/core/shared/platform/${WAMR_BUILD_PLATFORM}/shared_platform.cmake)
#include(${WAMR_DIR}/core/iwasm/aot/iwasm_aot.cmake)
#include(${WAMR_DIR}/core/iwasm/compilation/iwasm_compl.cmake)
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
    ${LIBCLANG_CPP}
    ${CLANG_AS}
    ${LLD_AS}
    ${LLDB_AS}
    ${COMPRESSION}
    ${XML2}
    ${FOUNDATION_LIBRARY}
    ${UIKITLIBRARY}
    ${ANGLE_A}
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
