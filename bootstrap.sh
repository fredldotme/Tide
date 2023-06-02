#!/bin/bash

set -e

# 1) LLVM
OLD_PWD=$(pwd)
#cd 3rdparty/llvm/
#./bootstrap.sh
cd $OLD_PWD

# 2) libclang-cpp
OLD_PWD=$(pwd)
LIBNAME=libclang
if [ ! -d tmp ]; then
    mkdir tmp
fi
cd tmp
rm -rf libclang.framework || true
mkdir -p $LIBNAME.framework/
cd $LIBNAME.framework
cp -a $OLD_PWD/aux/libclang-cpp/Info.plist ./
lipo -create $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/libclang.dylib -output ./$LIBNAME
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/libclang.dylib ./$LIBNAME
plutil -convert binary1 Info.plist
cd $OLD_PWD

# 3) wasi-sdk
OLD_PWD=$(pwd)
if [ ! -d tmp ]; then
    mkdir tmp
fi
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz --output wasi-sdk.tar.gz
tar xvf wasi-sdk.tar.gz
cd $OLD_PWD

# 4) libclang_rt
OLD_PWD=$(pwd)
if [ ! -d tmp ]; then
    mkdir tmp
fi
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cd $OLD_PWD

# Done!
exit 0
