#!/bin/sh

function build_openssl_for_sdk_version {
  SDK_VERSION=$1
  RLM_GCC=$2

  RLM_PLATFORM=iPhoneSimulator
  RLM_SDK=iPhoneSimulator$SDK_VERSION
  RLM_ARCH=i386
  RLM_EXTRA_CFLAGS=-mmacosx-version-min=10.4
  build_openssl

  RLM_PLATFORM=iPhoneOS
  RLM_SDK=iPhoneOS$SDK_VERSION
  RLM_ARCH=armv6
  RLM_EXTRA_CFLAGS=
  build_openssl

  cd $BUILD_ROOT

  echo "--- Making fat libraries"
  /Developer/Platforms/$RLM_PLATFORM.platform/Developer/usr/bin/lipo -arch armv6 build-openssl-iPhoneOS$SDK_VERSION/stage/lib/libcrypto.a -arch i386 build-openssl-iPhoneSimulator$SDK_VERSION/stage/lib/libcrypto.a -create -output libcrypto.a
  /Developer/Platforms/$RLM_PLATFORM.platform/Developer/usr/bin/lipo -arch armv6 build-openssl-iPhoneOS$SDK_VERSION/stage/lib/libssl.a -arch i386 build-openssl-iPhoneSimulator$SDK_VERSION/stage/lib/libssl.a -create -output libssl.a

  echo "--- Installing into $OUTPUT_DIR"
  cp -r build-openssl-iPhoneOS$SDK_VERSION/stage/include $OUTPUT_DIR
  mv libcrypto.a $OUTPUT_DIR/lib
  mv libssl.a $OUTPUT_DIR/lib
}

function build_openssl {
  echo "--- Building openssl for $RLM_SDK"

  BUILD_DIR=$BUILD_ROOT/build-openssl-$RLM_SDK

  rm -rf $BUILD_DIR
  mkdir -p $BUILD_DIR

  cd $BUILD_DIR

  STAGED_INSTALL_DIR=`pwd`/stage

  tar -xzf $BUILD_ROOT/openssl-$SSL_VERSION.tar.gz
  cd openssl-$SSL_VERSION
  ./config --openssldir="$STAGED_INSTALL_DIR" >/dev/null

  echo "---    Patching makefile"
  RLM_CC="\\/Developer\\/Platforms\\/$RLM_PLATFORM.platform\\/Developer\\/usr\\/bin\\/$RLM_GCC"
  sed -e "s/^CC=.*/CC=$RLM_CC/" <Makefile >Makefile.rlm && mv Makefile.rlm Makefile
  sed -e "s/^CFLAG= -DOPENSSL_THREADS -D_REENTRANT -DDSO_DLFCN -DHAVE_DLFCN_H -arch i386 -O3 -fomit-frame-pointer -DL_ENDIAN/CFLAG= $RLM_EXTRA_CFLAGS -isysroot \\/Developer\\/Platforms\\/$RLM_PLATFORM.platform\\/Developer\\/SDKs\\/$RLM_SDK.sdk -DOPENSSL_THREADS -D_REENTRANT -DDSO_DLFCN -DHAVE_DLFCN_H -arch $RLM_ARCH -O3 -fomit-frame-pointer -DL_ENDIAN/" < Makefile > Makefile.rlm && mv Makefile.rlm Makefile
  sed -e "s/^SHARED_LDFLAGS=-arch i386 -dynamiclib/SHARED_LDFLAGS=-arch $RLM_ARCH -dynamiclib/" < Makefile > Makefile.rlm && mv Makefile.rlm Makefile

  echo "---    Patching crypto/ui/ui_openssl.c"
  sed -e "s/^static volatile sig_atomic_t intr_signal;/static volatile int intr_signal;/" < crypto/ui/ui_openssl.c > crypto/ui/ui_openssl.c.rlm && mv crypto/ui/ui_openssl.c.rlm crypto/ui/ui_openssl.c

  echo "---    Running make"
  make &>/dev/null
  
  echo "---    Installing into staging area"
  make install &>/dev/null
}

set -e

SSL_VERSION=0.9.8k

PROJECT_DIR=`dirname $0`
PROJECT_DIR="`( cd \"$PROJECT_DIR\" && pwd )`"
OUTPUT_DIR=$PROJECT_DIR/vendor-libs
BUILD_ROOT=$PROJECT_DIR/build/vendor

mkdir -p $BUILD_ROOT &>/dev/null
mkdir -p $OUTPUT_DIR/include &>/dev/null
mkdir -p $OUTPUT_DIR/lib &>/dev/null

cd $BUILD_ROOT && wget http://www.openssl.org/source/openssl-$SSL_VERSION.tar.gz

build_openssl_for_sdk_version 3.1 gcc-4.2

