cmake_minimum_required(VERSION 3.20)

if(DEFINED ENV{ARCH})
    set(CLICK_ARCH "$ENV{ARCH}")
else()
    execute_process(
        COMMAND dpkg-architecture -qDEB_HOST_ARCH
        OUTPUT_VARIABLE CLICK_ARCH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()

if(DEFINED ENV{SDK_FRAMEWORK})
    set(CLICK_FRAMEWORK "$ENV{SDK_FRAMEWORK}")
else()
    set(CLICK_FRAMEWORK "ubuntu-sdk-20.04")
endif()

configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json DESTINATION ${CMAKE_INSTALL_PREFIX})
configure_file(tide.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/tide.desktop)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/tide.desktop DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES tide.apparmor DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES tide.contenthub DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES logo.png DESTINATION ${CMAKE_INSTALL_PREFIX})
