#!/bin/bash

set -e

BUILD_LINUX=0
BUILD_SNAP=0
BUILD_MAC=0
BUILD_IOS=0

CLANG_VER=18

if [ "$1" = "--linux" ]; then
    BUILD_LINUX=1
fi

if [ "$1" = "--linux-snap" ]; then
    echo "Building for Snap environment"
    BUILD_SNAP=1
fi

if [ "$1" = "--macos" ]; then
    echo "Building for macOS"
    BUILD_MAC=1
fi

if [ "$1" = "--ios" ]; then
    echo "Building for iOS/iPadOS"
    BUILD_IOS=1
fi

# Preparations
if [ ! -d tmp ]; then
    mkdir tmp
fi

if [ "$BUILD_IOS" = "1" ]; then
    IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
    SIM_SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
fi
OLD_PWD=$(pwd)


if [ "$BUILD_MAC" == "1" ] || [ "$BUILD_IOS" == "1" ]; then
    CLANG_BINS=$OLD_PWD/llvm/build_osx/bin
    CLANG_LIBS=$OLD_PWD/llvm/build_osx/lib
    LLVM_BUILD=build-iphoneos
elif [ "$BUILD_SNAP" == "1" ]; then
    CLANG_BINS=$CRAFT_STAGE/usr/bin
    CLANG_LIBS=$CRAFT_STAGE/usr/lib
    LLVM_BUILD=""
else
    CLANG_BINS=$OLD_PWD/llvm/build-linux/bin
    CLANG_LIBS=$OLD_PWD/llvm/build-linux/lib
    LLVM_BUILD=build-linux
fi

function cmake_ios_build {
    echo "Custom args: $@"

    if [ -d build-ios ]; then
        rm -rf build-ios
    fi
    mkdir build-ios
    cd build-ios
    cmake \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT=iphoneos \
        -DCMAKE_C_COMPILER=$(xcrun --sdk iphoneos -f clang) \
        -DCMAKE_CXX_COMPILER=$(xcrun --sdk iphoneos -f clang++) \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=14.0 \
        $@ ..
    ninja

    cd ..
}
function cmake_mac_build {
    echo "Custom args: $1"

    if [ -d build-mac ]; then
        rm -rf build-mac
    fi
    mkdir build-mac
    cd build-mac
    cmake \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        $1 ..
    ninja

    cd ..
}

function cmake_wasi_build {
    if [ "$BUILD_LINUX" = "1" ]; then
        OLD_PATH="$PATH"
        export PATH="/usr/bin:/bin:$PATH"
    elif [ "$BUILD_SNAP" = "1" ]; then
        OLD_PATH="$PATH"
        export PATH="$CRAFT_STAGE/usr/bin:/usr/bin:/bin:$PATH"
    fi

    if [ -d build ]; then
        rm -rf build
    fi
    mkdir build
    cd build
    cmake \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=WASI \
        -DCMAKE_SYSTEM_VERSION=1 \
        -DCMAKE_SYSTEM_PROCESSOR=wasm32 \
        -DCMAKE_C_COMPILER=$CLANG_BINS/clang \
        -DCMAKE_CXX_COMPILER=$CLANG_BINS/clang++ \
        -DCMAKE_ASM_COMPILER=$CLANG_BINS/clang \
        -DCMAKE_AR=$CLANG_BINS/llvm-ar \
        -DCMAKE_RANLIB=$CLANG_BINS/llvm-ranlib \
        -DCMAKE_C_COMPILER_TARGET=$1 \
        -DCMAKE_CXX_COMPILER_TARGET=$1 \
        -DCMAKE_ASM_COMPILER_TARGET=$1 \
        -DCMAKE_SYSROOT=$OLD_PWD/tmp/wasi-sysroot \
        -DCMAKE_C_FLAGS="-Wl,--allow-undefined -Wno-error=unused-command-line-argument -Wno-error=unknown-warning-option $2" \
        -DCMAKE_CXX_FLAGS="-Wl,--allow-undefined -Wno-error=unused-command-line-argument -Wno-error=unknown-warning-option $2" \
        "$3" ..
    ninja
    cd ..

    if [ ! -z "$OLD_PATH" ]; then
        export PATH="$OLD_PATH"
    fi
}

# LLVM
cd llvm
if [ "$BUILD_IOS" = "1" ] || [ "$BUILD_MAC" = "1" ]; then
    ./bootstrap.sh
elif [ "$BUILD_LINUX" = "1" ]; then
    ./bootstrap-linux.sh
fi
cd $OLD_PWD

if [ "$BUILD_IOS" = "1" ]; then
    # libclang
    LIBNAME=libclang
    cd tmp
    rm -rf libclang.framework || true
    mkdir -p $LIBNAME.framework
    cd $LIBNAME.framework
    cp -a $OLD_PWD/aux/libclang/Info.plist ./
    cp -a $OLD_PWD/llvm/build-iphoneos/lib/libclang.dylib ./$LIBNAME
    install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/libLLVM.framework/libLLVM" ./$LIBNAME
    install_name_tool -id "@rpath/libclang.framework/libclang" ./$LIBNAME
    plutil -convert binary1 Info.plist
    cd $OLD_PWD

    # Unixy tools
    cd unixy
    cmake_ios_build -DBUILD_TESTING=0 -DCMake_ENABLE_DEBUGGER=0 -DKWSYS_USE_DynamicLoader=0 -DKWSYS_SUPPORTS_SHARED_LIBS=0 -DNO_SYSTEM_FRAMEWORK=$OLD_PWD/llvm/no_system/build-iphoneos/Debug-iphoneos
    cd $OLD_PWD

    # Ninja
    cd ninja
    cmake_ios_build -DBUILD_TESTING=0 -DNINJA_BUILD_FRAMEWORK=1 -DNINJA_BUILD_BINARY=0 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/llvm/no_system/build-iphoneos/Debug-iphoneos -DCMAKE_SYSTEM_NAME=iOS
    cp ios/Info.plist build-ios/ninjaexe.framework/Info.plist
    cd $OLD_PWD

    # CMake
    cd CMake
    cmake_ios_build -DBUILD_TESTING=0 -DCMake_ENABLE_DEBUGGER=0 -DKWSYS_USE_DynamicLoader=0 -DKWSYS_SUPPORTS_SHARED_LIBS=0 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/llvm/no_system/build-iphoneos/Debug-iphoneos
    cp ios/Info.plist build-ios/Source/cmake.framework/Info.plist
    tar cvf $OLD_PWD/tmp/cmake.tar Modules Templates
    cd $OLD_PWD

    # mbedtls
    cd mbedtls
    cmake_ios_build -DBUILD_STATIC_LIBS=ON
    cd $OLD_PWD

    # libssh2
    cd libssh2
    cmake_ios_build -DCRYPTO_BACKEND=mbedTLS -DMBEDTLS_INCLUDE_DIR=$OLD_PWD/mbedtls/build-ios/include -DMBEDTLS_LIBRARY=$OLD_PWD/mbedtls/build-ios/library/libmbedtls.a -DMBEDCRYPTO_LIBRARY=$OLD_PWD/mbedtls/build-ios/library/libmbedcrypto.a -DMBEDX509_LIBRARY=$OLD_PWD/mbedtls/build-ios/library/libmbedx509.a -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=$OLD_PWD/libssh2/build-ios-install
    cd build-ios
    ninja install
    cd $OLD_PWD

    # libgit2
    cd libgit2
    export PKG_CONFIG_PATH=$OLD_PWD/libssh2/build-ios-install/lib/pkgconfig
    cmake_ios_build -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=ON
    unset PKG_CONFIG_PATH
    cd $OLD_PWD
fi

if [ "$BUILD_MAC" = "1" ]; then
    # Ninja
    cd ninja
    cmake_mac_build "-DBUILD_TESTING=0 -DNINJA_BUILD_FRAMEWORK=0 -DNINJA_BUILD_BINARY=1"
    cd $OLD_PWD

    # CMake
    cd CMake
    cmake_mac_build "-DBUILD_TESTING=0 -DCMake_ENABLE_DEBUGGER=0 -DKWSYS_USE_DynamicLoader=0 -DKWSYS_SUPPORTS_SHARED_LIBS=0"
    tar cvf $OLD_PWD/tmp/cmake.tar Modules Templates
    cd $OLD_PWD
fi

# Dummy files for Linux
if [ "$BUILD_LINUX" = "1" ] || [ "$BUILD_SNAP" = "1" ]; then
    cd tmp
    if [ ! -d cmake-dummy ]; then
        mkdir cmake-dummy
    fi
    touch cmake-dummy/.dummy
    tar cvf cmake.tar -C cmake-dummy .
    cd $OLD_PWD
fi

# wasi-libc
cd wasi-libc
make CC=$CLANG_BINS/clang \
     AR=$CLANG_BINS/llvm-ar \
     NM=$CLANG_BINS/llvm-nm \
     SYSROOT=$(pwd)/sysroot-threads \
     THREAD_MODEL=posix
rm -rf $OLD_PWD/tmp/wasi-sysroot
cp -a sysroot-threads $OLD_PWD/tmp/wasi-sysroot
cp -a sysroot-threads/lib/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce
cp -a sysroot-threads/include $OLD_PWD/tmp/wasi-sysroot/
cp -a $OLD_PWD/tmp/wasi-sysroot/include/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/include/wasm32-wasi-threads-exce
cp -a sysroot-threads/share $OLD_PWD/tmp/wasi-sysroot/
cp -a $OLD_PWD/tmp/wasi-sysroot/share/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/share/wasm32-wasi-threads-exce
cd $OLD_PWD

# wasi-sdk
cd wasi-sdk
mkdir -p $OLD_PWD/tmp/wasi-sysroot/lib

# Threads, no exceptions
rm -rf build
NINJA_FLAGS=-v LLVM_PROJ_DIR=$OLD_PWD/llvm SYSROOT=$OLD_PWD/tmp/wasi-sysroot TARGET=wasm32-wasi-threads THREADING=ON EXCEPTIONS=OFF EXCEPTIONS_FLAGS="" DESTDIR=$(pwd)/build/wasi make -f Makefile.tide build/libcxx-threads-tide.BUILT
cp -a $OLD_PWD/wasi-sdk/build/wasi/usr/local/lib/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/lib/

# Threads and exceptions
rm -rf build
NINJA_FLAGS=-v LLVM_PROJ_DIR=$OLD_PWD/llvm SYSROOT=$OLD_PWD/tmp/wasi-sysroot TARGET=wasm32-wasi-threads-exce THREADING=ON EXCEPTIONS=ON EXCEPTIONS_FLAGS="-fwasm-exceptions" DESTDIR=$(pwd)/build/wasi make -f Makefile.tide build/libcxx-threads-exce-tide.BUILT
cp -a $OLD_PWD/wasi-sdk/build/wasi/usr/local/lib/wasm32-wasi-threads-exce $OLD_PWD/tmp/wasi-sysroot/lib/

# Common
cp -a $OLD_PWD/wasi-sdk/build/wasi/usr/local/include/* $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# libclang_rt
# ATTENTION: This meddles with the build result of the LLVM build on the macOS side
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
mkdir -p $CLANG_LIBS/clang/$CLANG_VER/lib/wasi
cp -a $OLD_PWD/tmp/lib/wasi/libclang_rt.builtins-wasm32.a $CLANG_LIBS/clang/$CLANG_VER/lib/wasi/libclang_rt.builtins-wasm32.a
cd $OLD_PWD

# OpenSSL
cd openssl-wasm
cp -a precompiled/include $OLD_PWD/tmp/wasi-sysroot/
cp -a precompiled/lib/* $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp -a precompiled/lib/* $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce/
cd $OLD_PWD

# Posix/Berkely socket support
cd aux/lib-socket
cmake_wasi_build wasm32-wasi-threads "-Wl,--shared-memory -pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cmake_wasi_build wasm32-wasi-threads-exce "-Wl,--shared-memory -pthread -ftls-model=local-exec -mbulk-memory -fwasm-exceptions"
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce/
cp $OLD_PWD/wamr/core/iwasm/libraries/lib-socket/inc/wasi_socket_ext.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# JSON library C
cd json-c
mkdir -p $OLD_PWD/tmp/wasi-sysroot/include/json-c
cmake_wasi_build wasm32-wasi-threads "-pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/json-c/build/libjson-c.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cmake_wasi_build wasm32-wasi-threads-exce "-pthread -ftls-model=local-exec -mbulk-memory -fwasm-exceptions"
cp $OLD_PWD/json-c/build/libjson-c.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce/
find $OLD_PWD/json-c -name "*.h" -exec cp {} $OLD_PWD/tmp/wasi-sysroot/include/json-c/ \;
cd $OLD_PWD

# YAML library C
cd libyaml
cmake_wasi_build wasm32-wasi-threads "-pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/libyaml/build/libyaml.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cmake_wasi_build wasm32-wasi-threads-exce "-pthread -ftls-model=local-exec -mbulk-memory -fwasm-exceptions"
cp $OLD_PWD/libyaml/build/libyaml.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce/
cp $OLD_PWD/libyaml/include/yaml.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# YAML library C++
#cd yaml-cpp
#cmake_wasi_build wasm32-wasi-threads-exce "-fwasm-exceptions -pthread -ftls-model=local-exec -mbulk-memory -fwasm-exceptions"
#cp $OLD_PWD/yaml-cpp/build/libyaml-cpp.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads-exce/
#cp -a 3rdparty/yaml-cpp/include/yaml-cpp $OLD_PWD/tmp/wasi-sysroot/include/
#cd $OLD_PWD

# Boost header-only libraries
cd tmp
if [ -f boost.tar.bz2 ]; then
    rm boost.tar.bz2
fi
curl -L https://sourceforge.net/projects/boost/files/boost/1.83.0/boost_1_83_0.tar.bz2/download --output boost.tar.bz2
if [ -d boost ]; then
    rm -rf boost
fi
mkdir boost
tar xvf boost.tar.bz2 -C ./boost
tar cvf boost.tar -C boost/boost_1_83_0/ boost
cd $OLD_PWD

# Python inside WebAssembly
cd tmp
if [ -f python.tar.gz ]; then
    rm python.tar.gz
fi
if [ -f python.tar ]; then
    rm python.tar
fi
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/python%2F3.11.4%2B20230714-11be424/python-3.11.4-wasi-sdk-20.0.tar.gz --output python.tar.gz
gunzip python.tar.gz
cd $OLD_PWD

# Libraries provided by VMWare Labs, stuffed into the sysroot
cd tmp
if [ -d libs ]; then
    rm -rf libs
fi
mkdir libs
if [ -d unpacked ]; then
    rm -rf unpacked
fi
mkdir unpacked
cd libs
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Flibpng%2F1.6.39%2B20230629-ccb4cb0/libpng-1.6.39-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Fzlib%2F1.2.13%2B20230623-2993864/libz-1.2.13-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Fsqlite%2F3.42.0%2B20230623-2993864/libsqlite-3.42.0-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Flibxml2%2F2.11.4%2B20230623-2993864/libxml2-2.11.4-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Flibuuid%2F1.0.3%2B20230623-2993864/libuuid-1.0.3-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Flibjpeg%2F2.1.5.1%2B20230623-2993864/libjpeg-2.1.5.1-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
curl -L https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/libs%2Fbzip2%2F1.0.8%2B20230623-2993864/libbzip2-1.0.8-wasi-sdk-20.0.tar.gz --output ${RANDOM}.tar.gz
for f in $(ls *.tar.gz); do
    tar xvf $f -C ../unpacked/
done
cd ..
cp -a unpacked/lib/wasm32-wasi unpacked/lib/wasm32-wasi-threads
cp -a unpacked/lib/wasm32-wasi unpacked/lib/wasm32-wasi-threads-exce
rm -rf unpacked/lib/wasm32-wasi
cp -a unpacked/* $OLD_PWD/tmp/wasi-sysroot/
cd $OLD_PWD

# Package up the sysroot
if [ -d tmp/the-sysroot ]; then
    rm -rf tmp/the-sysroot
fi
mkdir -p tmp/the-sysroot/Clang
mkdir -p tmp/the-sysroot/Sysroot
mkdir -p tmp/the-sysroot/Clang/lib/wasi/
cp -a $OLD_PWD/tmp/wasi-sysroot/* tmp/the-sysroot/Sysroot
if [ "$BUILD_SNAP" == "1" ]; then
    cp -a $CRAFT_STAGE/usr/lib/clang/$CLANG_VER/include tmp/the-sysroot/Clang/
else
    cp -a $OLD_PWD/llvm/$LLVM_BUILD/lib/clang/$CLANG_VER/include tmp/the-sysroot/Clang/
fi
cp -a $OLD_PWD/tmp/lib/wasi/* tmp/the-sysroot/Clang/lib/wasi/
tar cvf tmp/sysroot.tar -C tmp/the-sysroot Sysroot
tar cvf tmp/clang.tar -C tmp/the-sysroot Clang
cd $OLD_PWD

# Version check to skip already unpacked sysroots
echo "$RANDOM" > $OLD_PWD/tmp/delivery.version

# Rust
#cd 3rdparty/rust
#./bootstrap.sh
#cd $OLD_PWD

cd tmp
if [ ! -d angle-metal ]; then
    git clone https://github.com/fredldotme/angle-metal
fi
cd $OLD_PWD

if [ "$BUILD_SNAP" = "1" ]; then
    mkdir -p $CRAFT_PART_INSTALL/resources
    cp -a tmp/{delivery.version,boost.tar,clang.tar,sysroot.tar,python.tar,cmake.tar} $CRAFT_PART_INSTALL/resources
    mkdir -p $CRAFT_PART_INSTALL/resources/usr/lib/clang/$CLANG_VER/wasi/
    cp -a $CLANG_LIBS/clang/$CLANG_VER/lib/wasi/libclang_rt.builtins-wasm32.a $CRAFT_PART_INSTALL/resources/usr/lib/clang/$CLANG_VER/wasi/
fi

# Done!
exit 0
