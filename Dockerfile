# syntax=docker/dockerfile:1

ARG QBITTORRENT_VERSION=5.1.4
ARG LIBTORRENT_VERSION=2.0.11

ARG ALPINE_VERSION=3.22
ARG XX_VERSION=1.9.0

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS base
COPY --from=xx / /
RUN apk --update --no-cache add git

FROM base AS libtorrent-src
ARG LIBTORRENT_VERSION
WORKDIR /src
RUN git clone --branch v${LIBTORRENT_VERSION} --depth 1 --recurse-submodules https://github.com/arvidn/libtorrent.git .

FROM base AS qbittorrent-src
ARG QBITTORRENT_VERSION
WORKDIR /src
RUN git clone --branch release-${QBITTORRENT_VERSION} --shallow-submodules --recurse-submodules https://github.com/qbittorrent/qBittorrent.git .

FROM base AS build
RUN apk --update --no-cache add binutils clang cmake libtool linux-headers ninja perl pkgconf tree

COPY --from=libtorrent-src /src /src/libtorrent
WORKDIR /src/libtorrent
ARG TARGETPLATFORM
RUN xx-apk --no-cache --no-scripts add gcc g++ boost-dev cppunit-dev ncurses-dev openssl-dev python3-dev py3-numpy-dev zlib-dev
RUN <<EOT
  set -ex
  export QEMU_LD_PREFIX=$(xx-info sysroot)
  CXXFLAGS="$CXXFLAGS -O2 -DNDEBUG -flto=auto"
  cmake -Wno-dev -G Ninja -B build $(xx-clang --print-cmake-defines) \
    -DCMAKE_SYSROOT="$(xx-info sysroot)" \
    -DCMAKE_CXX_FLAGS="-w -s" \
    -DCMAKE_CXX_STANDARD="17" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_INSTALL_LIBDIR="lib" \
    -DCMAKE_INSTALL_PREFIX="$(xx-info sysroot)usr/local"
  cmake --build build
  cmake --install build
  mkdir -p /out/usr/local/lib
  cp $(xx-info sysroot)usr/local/lib/libtorrent-rasterbar.so* /out/usr/local/lib/
EOT

COPY --from=qbittorrent-src /src /src/qbittorrent
WORKDIR /src/qbittorrent
RUN xx-apk --no-cache --no-scripts add boost-dev icu-dev qt6-qtbase-dev qt6-qtbase-private-dev qt6-qttools-dev qt6-qtsvg-dev samurai
RUN <<EOT
  set -ex
  ln -s $(xx-info sysroot)usr/lib/libproxy/libpxbackend*.so $(xx-info sysroot)usr/lib/
  export QEMU_LD_PREFIX=$(xx-info sysroot)
  cmake -Wno-dev -G Ninja -B build-nox $(xx-clang --print-cmake-defines) \
    -DGUI=OFF \
    -DWEBUI=ON \
    -DSTACKTRACE=OFF \
    -DTESTING=OFF \
    -DCMAKE_SYSROOT="$(xx-info sysroot)" \
    -DCMAKE_CXX_FLAGS="-w -s" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_INSTALL_PREFIX="$(xx-info sysroot)usr/local"
  cmake --build build-nox
  cmake --install build-nox
  mkdir -p /out/usr/local/bin
  cp $(xx-info sysroot)usr/local/bin/qbittorrent-nox /out/usr/local/bin/
EOT

FROM crazymax/yasu:latest AS yasu
FROM alpine:${ALPINE_VERSION}

COPY --from=yasu / /

RUN apk --update --no-cache add \
    bind-tools \
    boost \
    curl \
    icu \
    openssl \
    qt6-qtbase \
    qt6-qtsvg \
    shadow \
    tzdata \
    unzip \
    zlib

ENV QBITTORRENT_HOME="/home/qbittorrent" \
  TZ="UTC" \
  PUID="1500" \
  PGID="1500" \
  WEBUI_PORT="8080"

COPY --from=build /out /
COPY entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh \
  && addgroup -g ${PGID} qbittorrent \
  && adduser -D -h ${QBITTORRENT_HOME} -u ${PUID} -G qbittorrent -s /bin/sh qbittorrent \
  && qbittorrent-nox --version \
  && uname -a

EXPOSE 6881 6881/udp ${WEBUI_PORT}
WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/usr/local/bin/qbittorrent-nox" ]

HEALTHCHECK --interval=10s --timeout=10s --start-period=20s \
  CMD curl --fail http://127.0.0.1:${WEBUI_PORT}/api/v2/app/version || exit 1
