#!/bin/bash
set -e

export HOME=`pwd`

#sudo apt-get update -y
#sudo apt-get install --no-install-recommends -y wget curl ca-certificates xz-utils build-essential pkg-config clang

## DEPENDENCES ##
DEPS_VER="002"

TRANSMISSION_VER=${TRANSMISSION_VER:-master}
C_ARES_VER=${C_ARES_VER:-1.16.0}
OPENSSL_VER=${OPENSSL_VER:-1.1.1g}
ZLIB_VER=${ZLIB_VER:-1.2.11}
LIBIDN2_VER=${LIBIDN2_VER:-2.3.0}
LIBEVENT_VER=${LIBEVENT_VER:-2.1.11-stable}
# LIBSSH2_VER=${LIBSSH2_VER:-1.9.0}
NGHTTP2_VER=${NGHTTP2_VER:-1.40.0}
CURL_VER=${CURL_VER:-7.70.0}

TRANSMISSION_GITURL="https://gitlab.com/mitsui/cbfbdbd2.git"

PREFIX=$HOME/build_deps
PREFIX_TRANSMISSION=$HOME/build_result
BUILD_DIRECTORY=$HOME/build_sources
ARTIFACTS_DIR=$HOME/binary

DOWNLOADER='curl -LO'
NUM_THREAD=-j`nproc`
[ -n "$NO_CI_CACHE" ] && PREFIX=$PREFIX-no_ci_cache
[ -f $PREFIX/DEPMARK_$DEPS_VER ] || rm -rf $PREFIX || true
[ -n "$BUILD_DEPS_ONLY" ] && rm -rf $PREFIX || true

mkdir -p $PREFIX || true
mkdir -p $BUILD_DIRECTORY || true
mkdir -p $ARTIFACTS_DIR || true
mkdir -p $PREFIX_TRANSMISSION || true

TARGET_HOST=${TARGET_HOST:-x86_64-linux-gnu}
export CC=${CC:-$TARGET_HOST-gcc}
export CXX=${CXX:-$TARGET_HOST-g++}
export AR=${AR:-$TARGET_HOST-ar}
export LD=${LD:-$TARGET_HOST-ld}
export RANLIB=${RANLIB:-$TARGET_HOST-ranlib}
export WINDRES=${WINDRES:-$TARGET_HOST-windres}

LIBEVENT_LIBS="-ldl"
CURL_LIBS="-ldl -lpthread"
CURL_SSLSEL="--with-ssl"
TRANSMISSION_LDFLAGS='-Wl,-static -static-libgcc -static-libstdc++'
TRANSMISSION_LIBS='-ldl -lpthread -lrt -lm -lc'

case "$TARGET_HOST" in
  i686-linux-gnu)
    OPENSSL_TARGET=linux-elf
    export CFLAGS="$CFLAGS -m32"
    export CXXFLAGS="$CXXFLAGS -m32"
    export LDFLAGS="$LDFLAGS -m32"
    ;;
  i686-w64-mingw32)
    OPENSSL_TARGET=mingw
    LIBEVENT_LIBS="-lcrypt32"
    CURL_CFLAGS='-DCARES_STATICLIB'
    CURL_LIBS=''
    CURL_SSLSEL="--with-winssl --without-nghttp2"
    TRANSMISSION_CPPFLAGS='-DWIN32'
    TRANSMISSION_LDFLAGS='-static'
    TRANSMISSION_LIBS='-luuid -lole32'
    ;;
  x86_64-w64-mingw32)
    OPENSSL_TARGET=mingw64
    LIBEVENT_LIBS=""
    CURL_CFLAGS='-DCARES_STATICLIB'
    CURL_LIBS=''
    CURL_SSLSEL="--with-winssl --without-nghttp2"
    TRANSMISSION_CPPFLAGS='-DWIN32'
    TRANSMISSION_LDFLAGS='-static'
    TRANSMISSION_LIBS='-luuid -lole32'
    ;;
  arm-linux-gnueabihf)
    OPENSSL_TARGET=linux-armv4
    ;;
  aarch64-linux-gnu)
    OPENSSL_TARGET=linux-aarch64
    ;;
  *)
    OPENSSL_TARGET=linux-x86_64
    ;;
esac

C_ARES_CFLAGS=$CFLAGS
export PKG_CONFIG='pkg-config --static'
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig/
export LD_LIBRARY_PATH=$PREFIX/lib/
export CFLAGS="$CFLAGS -I$PREFIX/include"
export CXXFLAGS="$CXXFLAGS -I$PREFIX/include"
export LDFLAGS="$LDFLAGS -L$PREFIX/lib"

echo 'CC and CXX tool:'
$CC --version || true
$CXX --version || true
uname -a || true

## BUILD ##
build_zlib() {
  echo '---------- Build ZLib ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://zlib.net/zlib-$ZLIB_VER.tar.xz
  tar xf zlib-$ZLIB_VER.tar.xz
  cd zlib-$ZLIB_VER
  ./configure --prefix=$PREFIX --static
  make $NUM_THREAD
  make install
}

build_cares() {
  echo '---------- Build C-Ares ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER http://c-ares.haxx.se/download/c-ares-$C_ARES_VER.tar.gz
  tar xf c-ares-$C_ARES_VER.tar.gz
  cd c-ares-$C_ARES_VER
  CFLAGS=$C_ARES_CFLAGS ./configure --prefix=$PREFIX --host=$TARGET_HOST --enable-static --disable-shared
  make $NUM_THREAD
  make install
}

build_openssl() {
  echo '---------- Build OpenSSL ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz
  tar xf openssl-$OPENSSL_VER.tar.gz
  cd openssl-$OPENSSL_VER
  ./Configure zlib no-shared --prefix=$PREFIX --with-zlib-include=$PREFIX/include --with-zlib-lib=$PREFIX/lib $OPENSSL_TARGET
  make $NUM_THREAD
  make install_sw
}

build_libidn2() {
  echo '---------- Build IDN2 ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://ftp.gnu.org/gnu/libidn/libidn2-$LIBIDN2_VER.tar.gz
  tar xf libidn2-$LIBIDN2_VER.tar.gz
  cd libidn2-$LIBIDN2_VER
  ./configure --prefix=$PREFIX --host=$TARGET_HOST --enable-static --disable-shared
  make $NUM_THREAD
  make install
}

build_libevent() {
  echo '---------- Build LibEvent ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VER/libevent-$LIBEVENT_VER.tar.gz
  tar xf libevent-$LIBEVENT_VER.tar.gz
  cd libevent-$LIBEVENT_VER
  LIBS="$LIBS $LIBEVENT_LIBS" ./configure --prefix=$PREFIX --host=$TARGET_HOST --enable-static --disable-shared --disable-samples
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
  echo '---------- Build NgHttp2 ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://github.com/nghttp2/nghttp2/releases/download/v$NGHTTP2_VER/nghttp2-$NGHTTP2_VER.tar.xz
  tar xf nghttp2-$NGHTTP2_VER.tar.xz
  cd nghttp2-$NGHTTP2_VER
  ./configure --prefix=$PREFIX --host=$TARGET_HOST --enable-lib-only --enable-static --disable-shared --disable-python-bindings
  make $NUM_THREAD
  make install
}

build_curl() {
  echo '---------- Build Curl ----------'
  cd $BUILD_DIRECTORY
  $DOWNLOADER https://curl.haxx.se/download/curl-$CURL_VER.tar.xz
  tar xf curl-$CURL_VER.tar.xz
  cd curl-$CURL_VER
  CFLAGS="$CFLAGS $CURL_CFLAGS" LIBS="$LIBS $CURL_LIBS" ./configure --prefix=$PREFIX --host=$TARGET_HOST \
    --enable-optimize --enable-ares --enable-proxy --enable-gopher --enable-libcurl-option --enable-ipv6 --enable-static \
    --disable-debug --disable-curldebug --disable-manual --disable-ldap --disable-ldaps --disable-sspi --disable-rtsp --disable-tftp \
    --disable-dict --disable-smb --disable-gopher --disable-imap --disable-smtp --disable-telnet --disable-pop3 --disable-alt-svc --disable-shared \
    $CURL_SSLSEL --without-libssh2 --without-gssapi --without-gnutls --without-libmetalink --without-libpsl
  make $NUM_THREAD
  make install
}

# finally
build_transmission() {
  cd $BUILD_DIRECTORY
  echo '--------Prepare transmission sources--------'
  git clone $TRANSMISSION_GITURL transmission-src
  cd transmission-src
  git checkout $TRANSMISSION_VER
  git submodule update --init --recursive
  [ -n "$MODIFY_VERSION" ] && sed -E -i 's|m4_define\(\[user_agent_prefix\],\[\S+\]\)|m4_define([user_agent_prefix],['$MODIFY_VERSION'])|' configure.ac
  [ -n "$MODIFY_PEERVER" ] && sed -E -i 's|m4_define\(\[peer_id_prefix\],\[\S+\]\)|m4_define([peer_id_prefix],[-TR'$MODIFY_PEERVER'-])|' configure.ac
  ./autogen.sh --host=$TARGET_HOST || true
  echo '--------Start transmission configure--------'
  CPPFLAGS="$TRANSMISSION_CPPFLAGS" LDFLAGS="$LDFLAGS $TRANSMISSION_LDFLAGS" LIBS="$LIBS $TRANSMISSION_LIBS" \
    ./configure --prefix=$PREFIX_TRANSMISSION --host=$TARGET_HOST --enable-utp --enable-daemon --disable-nls --enable-static --disable-shared
  cd third-party
  make $NUM_THREAD
  cp -n libutp/libutp.a $LD_LIBRARY_PATH
  cp -n libnatpmp/libnatpmp.a $LD_LIBRARY_PATH
  cp -n miniupnpc/libminiupnp.a $LD_LIBRARY_PATH
  cp -n libb64/libb64.a $LD_LIBRARY_PATH
  cp -n dht/libdht.a $LD_LIBRARY_PATH
  cd ..
  echo '-----------Building transmission------------'
  make $NUM_THREAD
  make install
}

pack_and_upload() {
  echo 'Uploading artifacts...'
  cd $ARTIFACTS_DIR
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

touch $PREFIX/DEPMARK_$DEPS_VER

[ -n "$BUILD_DEPS_ONLY" ] && exit 0

build_transmission

mv $PREFIX_TRANSMISSION/bin/transmission-* $ARTIFACTS_DIR/
cd $ARTIFACTS_DIR
if [ "$(ls -A .)" ]; then
  strip -s -x transmission-* || true
  echo "build finished:"
  ls -hl
  [ -n "$SHARE_ARTIFACTS" ] && pack_and_upload || true
  exit 0
fi
echo "no binary found!"
exit 1
