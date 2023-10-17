#!/bin/bash

set -e

if [ -z "$ROOT" ]; then
    echo "You're using this wrong, use 'clickable' instead."
    exit 1
fi

# Start off at the build dir
cd $BUILD_DIR

if [ ! -d qt6 ]; then
    git clone https://github.com/qt/qtbase.git -b 6.6.0 qt6
fi
cd qt6
if [ ! -d build ]; then
    mkdir build
fi
cd build

ARCH_ARGS="-DQT_FEATURE_opengles2=ON -DQT_FEATURE_opengles3=ON -DQT_FEATURE_opengles31=ON -DQT_FEATURE_opengles32=ON"
if [ "$ARCH" = "amd64" ]; then
    ARCH_ARGS=""
fi

cmake -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $ARCH_ARGS ..
ninja
ninja install
cd ../..

if [ ! -d qt6shadertools ]; then
    git clone https://github.com/qt/qtshadertools.git -b 6.6.0 qt6shadertools
fi
cd qt6shadertools
if [ ! -d build ]; then
    mkdir build
fi
cd build

cmake -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
ninja
ninja install
cd ../..

if [ ! -d qt6declarative ]; then
    git clone https://github.com/qt/qtdeclarative.git -b 6.6.0 qt6declarative
fi
cd qt6declarative
if [ ! -d build ]; then
    mkdir build
fi
cd build

cmake -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
ninja
ninja install
cd ../..

if [ ! -d qt6wayland ]; then
    git clone https://github.com/qt/qtwayland.git -b 6.6.0 qt6wayland
fi
cd qt6wayland
if [ ! -d build ]; then
    mkdir build
fi
cd build

cmake -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
ninja
ninja install
cd ../..

# Segue to bootstrap resources and LLVM tooling
cd ${ROOT}
bash bootstrap.sh --linux

# Back to the build dir
cd $BUILD_DIR

if [ ! -d build ]; then
    mkdir build
fi
cd build

cmake -GNinja -DBUILD_CLICK_METADATA=ON -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $SRC_DIR
ninja
ninja install

rm -rf $INSTALL_DIR/{mkspecs,include,libexec}

exit 0