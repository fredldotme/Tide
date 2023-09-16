#!/bin/bash

set -e

# Preparations
if [ ! -d tmp ]; then
    mkdir tmp
fi

IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
OLD_PWD=$(pwd)

function cmake_iossystem_build {
    echo "Custom args: $1"
    LIBNAME="$2"

    if [ -d build ]; then
        rm -rf build
    fi
    mkdir build
    cd build
    cmake \
        -G Ninja \
        -DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
        -DCMAKE_C_COMPILER=$(xcrun --sdk iphoneos -f clang) \
        -DCMAKE_CXX_COMPILER=$(xcrun --sdk iphoneos -f clang++) \
        ..
    ninja

    cd ..
}

function cmake_wasi_build {
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
        -DCMAKE_C_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
        -DCMAKE_CXX_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang++ \
        -DCMAKE_ASM_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
        -DCMAKE_AR=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ar \
        -DCMAKE_RANLIB=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ranlib \
        -DCMAKE_C_COMPILER_TARGET=$1 \
        -DCMAKE_CXX_COMPILER_TARGET=$1 \
        -DCMAKE_ASM_COMPILER_TARGET=$1 \
        -DCMAKE_SYSROOT=$OLD_PWD/tmp/wasi-sysroot \
        -DCMAKE_C_FLAGS="-Wl,--allow-undefined -Wno-error=unused-command-line-argument $2" \
        -DCMAKE_CXX_FLAGS="-Wl,--allow-undefined -Wno-error=unused-command-line-argument $2" \
        "$3" ..
    ninja
    cd ..
}

# LLVM
cd 3rdparty/llvm/
# ./bootstrap.sh
cd $OLD_PWD
 
# libclang
LIBNAME=libclang
cd tmp
rm -rf libclang.framework || true
mkdir -p $LIBNAME.framework
cd $LIBNAME.framework
cp -a $OLD_PWD/aux/libclang/Info.plist ./
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/libclang.dylib ./$LIBNAME
install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/libLLVM.framework/libLLVM" ./$LIBNAME
install_name_tool -id "@rpath/libclang.framework/libclang" ./$LIBNAME
plutil -convert binary1 Info.plist
cd $OLD_PWD

# wasi-libc
cd 3rdparty/wasi-libc
make CC=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
     AR=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ar \
     NM=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-nm
make CC=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
     AR=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ar \
     NM=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-nm \
     SYSROOT=$(pwd)/sysroot-threads \
     THREAD_MODEL=posix
rm -rf $OLD_PWD/tmp/wasi-sysroot
cp -a sysroot $OLD_PWD/tmp/wasi-sysroot
cp -a sysroot-threads/lib/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/lib/
cp -a sysroot-threads/include $OLD_PWD/tmp/wasi-sysroot/
cp -a sysroot-threads/share $OLD_PWD/tmp/wasi-sysroot/
cd $OLD_PWD

# wasi-sdk
cd 3rdparty/wasi-sdk
mkdir -p $OLD_PWD/tmp/wasi-sysroot/lib
rm -rf build || true
NINJA_FLAGS=-v LLVM_PROJ_DIR=$OLD_PWD/3rdparty/llvm SYSROOT=$OLD_PWD/tmp/wasi-sysroot TARGET=wasm32-wasi TARGET_TRIPLE=wasm32-wasi THREADING=OFF DESTDIR=$(pwd)/build/wasi make -f Makefile.tide build/libcxx-tide.BUILT
cp -a $OLD_PWD/3rdparty/wasi-sdk/build/wasi/usr/local/lib/wasm32-wasi $OLD_PWD/tmp/wasi-sysroot/lib/
rm -rf build
NINJA_FLAGS=-v LLVM_PROJ_DIR=$OLD_PWD/3rdparty/llvm SYSROOT=$OLD_PWD/tmp/wasi-sysroot TARGET_TRIPLE=wasm32-wasi-threads DESTDIR=$(pwd)/build/wasi make -f Makefile.tide build/libcxx-threads-tide.BUILT
cp -a $OLD_PWD/3rdparty/wasi-sdk/build/wasi/usr/local/lib/wasm32-wasi-threads $OLD_PWD/tmp/wasi-sysroot/lib/
# cp -a $OLD_PWD/3rdparty/wasi-sdk/build/wasi/usr/local/lib/libunwind.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
# cp -a $OLD_PWD/3rdparty/wasi-sdk/build/wasi/usr/local/lib/libunwind.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp -a $OLD_PWD/3rdparty/wasi-sdk/build/wasi/usr/local/include/* $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# libclang_rt
# ATTENTION: This meddles with the build result of the LLVM build on the macOS side
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cp -a $OLD_PWD/tmp/lib/wasi $OLD_PWD/3rdparty/llvm/build_osx/lib/clang/17/lib/
cd $OLD_PWD

# OpenSSL
cd 3rdparty/openssl-wasm
cp -a precompiled/include $OLD_PWD/tmp/wasi-sysroot/
cp -a precompiled/lib/* $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
cp -a precompiled/lib/* $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cd $OLD_PWD

# Posix/Berkely socket support
cd aux/lib-socket
cmake_wasi_build wasm32-wasi ""
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
cmake_wasi_build wasm32-wasi-threads "-Wl,--shared-memory -pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp $OLD_PWD/3rdparty/wamr/core/iwasm/libraries/lib-socket/inc/wasi_socket_ext.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# JSON library C
cd 3rdparty/json-c
mkdir -p $OLD_PWD/tmp/wasi-sysroot/include/json-c
cmake_wasi_build wasm32-wasi ""
cp $OLD_PWD/3rdparty/json-c/build/libjson-c.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
cmake_wasi_build wasm32-wasi-threads "-pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/3rdparty/json-c/build/libjson-c.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
find $OLD_PWD/3rdparty/json-c -name "*.h" -exec cp {} $OLD_PWD/tmp/wasi-sysroot/include/json-c/ \;
cd $OLD_PWD

# YAML library C
cd 3rdparty/libyaml
cmake_wasi_build wasm32-wasi ""
cp $OLD_PWD/3rdparty/libyaml/build/libyaml.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
cmake_wasi_build wasm32-wasi-threads "-pthread -ftls-model=local-exec -mbulk-memory"
cp $OLD_PWD/3rdparty/libyaml/build/libyaml.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp $OLD_PWD/3rdparty/libyaml/include/yaml.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# YAML library C++
# cd 3rdparty/yaml-cpp
# cmake_wasi_build wasm32-wasi "-fwasm-exceptions"
# cp $OLD_PWD/3rdparty/yaml-cpp/build/libyaml-cpp.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi/
# cmake_wasi_build wasm32-wasi-threads "-fwasm-exceptions -pthread -ftls-model=local-exec -mbulk-memory"
# cp $OLD_PWD/3rdparty/yaml-cpp/build/libyaml-cpp.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
# cp -a 3rdparty/yaml-cpp/include/yaml-cpp $OLD_PWD/tmp/wasi-sysroot/include/
# cd $OLD_PWD

# Boost header-only libraries
cd tmp
if [ -f boost.tar.bz2 ]; then
    rm boost.tar.bz2
fi
curl -L https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.bz2 --output boost.tar.bz2
if [ -d boost ]; then
    rm -rf boost
fi
mkdir boost
tar xvf boost.tar.bz2 -C ./boost
tar cvf boost.tar -C boost/boost_1_83_0/ boost
cd $OLD_PWD

# Package up the sysroot
if [ -d tmp/the-sysroot ]; then
    rm -rf tmp/the-sysroot
fi
mkdir -p tmp/the-sysroot/Clang
mkdir -p tmp/the-sysroot/Sysroot
mkdir -p tmp/the-sysroot/Clang/lib/wasi/
cp -a $OLD_PWD/tmp/wasi-sysroot/* tmp/the-sysroot/Sysroot
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/clang/17/include tmp/the-sysroot/Clang/
cp -a $OLD_PWD/tmp/lib/wasi/* tmp/the-sysroot/Clang/lib/wasi/
tar cvf tmp/the-sysroot.tar -C tmp/the-sysroot .
cd $OLD_PWD

# Rust
#cd 3rdparty/rust
#./bootstrap.sh
#cd $OLD_PWD

# CMake
#cd 3rdparty/CMake
#LIBNAME="cmake"
#cmake_iossystem_build "-DBUILD_TESTING=0 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/3rdparty/llvm/no_system/build-iphoneos/Debug-iphoneos" "$LIBNAME"
#cd $OLD_PWD

# Ninja
#cd 3rdparty/ninja
#LIBNAME="ninja"
#cmake_iossystem_build "-DBUILD_TESTING=0 -DNINJA_BUILD_FRAMEWORK=1 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/3rdparty/llvm/no_system/build-iphoneos/Debug-iphoneos" "$LIBNAME"
#cd $OLD_PWD

cd tmp
if [ ! -d angle-metal ]; then
    git clone https://github.com/fredldotme/angle-metal
fi
cd $OLD_PWD

# Done!
exit 0
