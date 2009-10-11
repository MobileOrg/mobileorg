#!/bin/sh

function build_neon_for_sdk_version {
  SDK_VERSION=$1
  RLM_GCC=$2

  RLM_PLATFORM=iPhoneSimulator
  RLM_SDK=iPhoneSimulator$SDK_VERSION
  RLM_ARCH=i386
  RLM_EXTRA_CFLAGS=-mmacosx-version-min=10.4
  build_neon

  RLM_PLATFORM=iPhoneOS
  RLM_SDK=iPhoneOS$SDK_VERSION
  RLM_ARCH=armv6
  RLM_EXTRA_CFLAGS=
  build_neon

  cd $BUILD_ROOT

  echo "--- Making fat libraries"
  /Developer/Platforms/$RLM_PLATFORM.platform/Developer/usr/bin/lipo -arch armv6 build-neon-iPhoneOS$SDK_VERSION/stage/lib/libneon.a -arch i386 build-neon-iPhoneSimulator$SDK_VERSION/stage/lib/libneon.a -create -output libneon.a

  echo "--- Installing into $OUTPUT_DIR"
  cp -r build-neon-iPhoneOS$SDK_VERSION/stage/include $OUTPUT_DIR
  mv libneon.a $OUTPUT_DIR/lib/libmyneon.a
}

function build_neon {
  echo "--- Building neon for $RLM_SDK"

  BUILD_DIR=$BUILD_ROOT/build-neon-$RLM_SDK

  rm -rf $BUILD_DIR
  mkdir -p $BUILD_DIR

  cd $BUILD_DIR

  STAGED_INSTALL_DIR=`pwd`/stage

  tar -xzf $BUILD_ROOT/neon-$NEON_VERSION.tar.gz
  cd neon-$NEON_VERSION

  ./configure --with-libxml2 --with-ssl=openssl --with-libs=$OUTPUT_DIR:/Developer/Platforms/$RLM_PLATFORM.platform/Developer/SDKs/$RLM_SDK.sdk --prefix=$STAGED_INSTALL_DIR &>/dev/null

  echo "---    Patching makefile"
  RLM_CC="\\/Developer\\/Platforms\\/$RLM_PLATFORM.platform\\/Developer\\/usr\\/bin\\/$RLM_GCC"

  sed -e "s/^CC =.*/CC = $RLM_CC/" <src/Makefile >src/Makefile.rlm && mv src/Makefile.rlm src/Makefile
  sed -e "s/^CFLAGS = -g -O2 -prefer-pic/CFLAGS = $RLM_EXTRA_CFLAGS -O2 -prefer-pic -arch $RLM_ARCH -isysroot \\/Developer\\/Platforms\\/$RLM_PLATFORM.platform\\/Developer\\/SDKs\\/$RLM_SDK.sdk/" <src/Makefile >src/Makefile.rlm && mv src/Makefile.rlm src/Makefile
  sed -e "s/-flat_namespace$/-flat_namespace -arch $RLM_ARCH/" <src/Makefile >src/Makefile.rlm && mv src/Makefile.rlm src/Makefile
  sed -e "s/^#define HAVE_TIMEZONE 1$//" <config.h >config.h.rlm && mv config.h.rlm config.h
  sed -e "s/^#define HAVE_GSSAPI 1$//" <config.h >config.h.rlm && mv config.h.rlm config.h

  echo "---    Running make"
  make &>/dev/null
  
  echo "---    Installing into staging area"
  make install &>/dev/null
}

set -e

NEON_VERSION=0.29.0

PROJECT_DIR=`dirname $0`
PROJECT_DIR="`( cd \"$PROJECT_DIR\" && pwd )`"
OUTPUT_DIR=$PROJECT_DIR/vendor-libs
BUILD_ROOT=$PROJECT_DIR/build/vendor

mkdir -p $BUILD_ROOT &>/dev/null
mkdir -p $OUTPUT_DIR/include &>/dev/null
mkdir -p $OUTPUT_DIR/lib &>/dev/null

cd $BUILD_ROOT && wget http://www.webdav.org/neon/neon-$NEON_VERSION.tar.gz

build_neon_for_sdk_version 3.1 gcc-4.2

