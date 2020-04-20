#!/bin/bash
set -e

export HOME=`pwd`

#sudo apt-get update -y
#sudo apt-get install --no-install-recommends -y wget curl ca-certificates xz-utils build-essential pkg-config clang

## DEPENDENCES ##
TRANSMISSION_VER=${TRANSMISSION_VER:-master}
C_ARES_VER=${C_ARES_VER:-1.14.0}
OPENSSL_VER=${OPENSSL_VER:-1.1.1f}
ZLIB_VER=${ZLIB_VER:-1.2.11}
LIBIDN2_VER=${LIBIDN2_VER:-2.3.0}
LIBEVENT_VER=${LIBEVENT_VER:-2.1.11-stable}
# LIBSSH2_VER=${LIBSSH2_VER:-1.9.0}
NGHTTP2_VER=${NGHTTP2_VER:-1.40.0}
CURL_VER=${CURL_VER:-7.69.1}

PREFIX=$HOME/build_deps
BUILD_DIRECTORY=$HOME/transmission_build
BUILD_BINARY_DIR=$HOME/binary

DOWNLOADER='curl -LO'
NUM_THREAD=-j`nproc`

mkdir -p $PREFIX
mkdir -p $BUILD_DIRECTORY
mkdir -p $BUILD_BINARY_DIR

export CC=${CC:-clang}
export CXX=${CXX:-clang++}
export PKG_CONFIG='pkg-config --static'
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig/
export LD_LIBRARY_PATH=$PREFIX/lib/
export CFLAGS=-I$PREFIX/include
export LDFLAGS=-L$PREFIX/lib
export CXXFLAGS=$CFLAGS
C_ARES_CFLAGS=''

echo 'CC and CXX tool:'
$CC --version || true
$CXX --version || true
uname -a || true

## BUILD ##
build_zlib() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://zlib.net/zlib-$ZLIB_VER.tar.xz
  tar xf zlib-$ZLIB_VER.tar.xz
  cd zlib-$ZLIB_VER
  ./configure --prefix=$PREFIX --static
  make $NUM_THREAD
  make install
}

build_cares() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER http://c-ares.haxx.se/download/c-ares-$C_ARES_VER.tar.gz
  tar xf c-ares-*
  cd c-ares-*/
  CFLAGS=$C_ARES_CFLAGS ./configure --prefix=$PREFIX --enable-static --disable-shared
  make $NUM_THREAD
  make install
}

build_openssl() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz
  tar xf openssl-$OPENSSL_VER.tar.gz
  cd openssl-$OPENSSL_VER
  ./config --prefix=$PREFIX --with-zlib-include=$PREFIX/include --with-zlib-lib=$PREFIX/lib zlib no-shared
  make $NUM_THREAD
  make install_sw
}

build_libidn2() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://ftp.gnu.org/gnu/libidn/libidn2-$LIBIDN2_VER.tar.gz
  tar xf libidn2-$LIBIDN2_VER.tar.gz
  cd libidn2-$LIBIDN2_VER
  ./configure --prefix=$PREFIX --enable-static --disable-shared
  make $NUM_THREAD
  make install
}

build_libevent() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VER/libevent-$LIBEVENT_VER.tar.gz
  tar xf libevent-$LIBEVENT_VER.tar.gz
  cd libevent-$LIBEVENT_VER
  LIBS=-ldl ./configure --prefix=$PREFIX --enable-static --disable-shared --disable-samples
  make $NUM_THREAD
  make install
}

#build_libssh2() {
#  cd $BUILD_DIRECTORY
#  $DOWNLOADER https://www.libssh2.org/download/libssh2-$LIBSSH2_VER.tar.gz
#  tar xf libssh2-$LIBSSH2_VER.tar.gz
#  cd libssh2-$LIBSSH2_VER
#  LIBS='-ldl -lpthread' ./configure --prefix=$PREFIX --without-libgcrypt --with-openssl --without-wincng --enable-static --disable-shared
#  make $NUM_THREAD
#  make install
#}

build_nghttp2() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://github.com/nghttp2/nghttp2/releases/download/v$NGHTTP2_VER/nghttp2-$NGHTTP2_VER.tar.xz
  tar xf nghttp2-$NGHTTP2_VER.tar.xz
  cd nghttp2-$NGHTTP2_VER
  ./configure --prefix=$PREFIX --enable-static --disable-shared --disable-python-bindings
  make $NUM_THREAD
  make install
}

build_curl() {
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://curl.haxx.se/download/curl-$CURL_VER.tar.xz
  tar xf curl-$CURL_VER.tar.xz
  cd curl-$CURL_VER
  LIBS='-ldl -lpthread' ./configure --prefix=$PREFIX \
    --enable-optimize --enable-ares --enable-proxy --enable-gopher --enable-libcurl-option --enable-ipv6 --enable-static \
    --disable-debug --disable-curldebug --disable-manual --disable-ldap --disable-ldaps --disable-sspi --disable-rtsp --disable-tftp \
    --disable-dict --disable-smb --disable-gopher --disable-imap --disable-smtp --disable-telnet --disable-pop3 --disable-alt-svc --disable-shared \
    --without-libssh2 --without-gssapi --without-gnutls --without-libmetalink --without-libpsl
  make $NUM_THREAD
  make install
}

# finally
build_transmission() {
  cd $BUILD_DIRECTORY
  echo '--------Prepare transmission sources--------'
  git clone https://github.com/transmission/transmission.git transmission-src
  cd transmission-src
  git checkout $TRANSMISSION_VER
  git submodule update --init --recursive
  [ -n "$MODIFY_VERSION" ] && sed -E -i 's|m4_define\(\[user_agent_prefix\],\[\S+\]\)|m4_define([user_agent_prefix],['$MODIFY_VERSION'])|' configure.ac
  [ -n "$MODIFY_PEERVER" ] && sed -E -i 's|m4_define\(\[peer_id_prefix\],\[\S+\]\)|m4_define([peer_id_prefix],[-TR'$MODIFY_PEERVER'-])|' configure.ac
  ./autogen.sh || true
  echo '--------Start transmission configure--------'
  LDFLAGS='-static -Wl,-static -static-libgcc' LIBS='-ldl -lpthread -lrt -lm' ./configure --prefix=$PREFIX --enable-utp --enable-daemon --disable-nls --enable-static --disable-shared
  echo '-----------Building transmission------------'
  make $NUM_THREAD
  make install
}

clean_buildcache() {
  cd $BUILD_DIRECTORY
  rm -rf c-ares*
  rm -rf transmission-*
  rm -rf zlib-*
  rm -rf curl-*
  rm -rf openssl-*
  rm -rf libssh2-*
  rm -rf libidn2-*
  rm -rf libevent-*
  rm -rf nghttp2-*
}

pack_and_upload() {
  echo 'Uploading artifacts...'
  cd $BUILD_BINARY_DIR
  local build_time=`date +"%Y%m%d%H%M%S"`
  tar --owner=0 --group=0 -cJf $HOME/transmissionbt.tar.xz *
  curl -T "$HOME/transmissionbt.tar.xz" "https://transfer.sh/transmissionbt-$build_time.tar.xz"
  echo
  [ -n "$TELEGRAM_BOTOKEN" ] && curl -s \
    -F "chat_id=${TELEGRAM_BOTOKEN#*/}" \
    -F "document=@$HOME/transmissionbt.tar.xz" \
    -F "caption=TransmissionBT-$build_time" \
    "https://api.telegram.org/bot${TELEGRAM_BOTOKEN%/*}/sendDocument" >/dev/null
  [ -n "$TERACLOUD_TOKEN" ] && curl -s -u "${TERACLOUD_TOKEN%@*}" -T "$HOME/transmissionbt.tar.xz" \
    "https://${TERACLOUD_TOKEN#*@}/dav/artifacts/transmissionbt-$build_time.tar.xz" >/dev/null
}

[ -f $PREFIX/lib/libz.a ] || build_zlib
[ -f $PREFIX/lib/libcares.a ] || build_cares
[ -f $PREFIX/lib/libcrypto.a -a -f $PREFIX/lib/libssl.a ] || build_openssl
[ -f $PREFIX/lib/libidn2.a ] || build_libidn2
[ -f $PREFIX/lib/libevent.a ] || build_libevent
#[ -f $PREFIX/lib/libssh2.a ] || build_libssh2
[ -f $PREFIX/lib/libnghttp2.a ] || build_nghttp2
[ -f $PREFIX/lib/libcurl.a ] || build_curl

build_transmission

mv $PREFIX/bin/transmission-* $BUILD_BINARY_DIR/
cd $BUILD_BINARY_DIR
if [ "$(ls -A .)" ]; then
  strip -s -x transmission-* || true
  echo "build finished:"
  ls -hl
  [ -n "$SHARE_ARTIFACTS" ] && pack_and_upload || true
  exit 0
fi
echo "no binary found!"
exit 1
