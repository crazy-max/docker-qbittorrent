ARG LIBTORRENT_VERSION=1.2.14
ARG QBITTORRENT_VERSION=4.3.8

FROM crazymax/yasu:latest AS yasu
FROM alpine:3.14 AS builder

RUN apk add --update --no-cache \
    autoconf \
    automake \
    binutils \
    boost-dev \
    build-base \
    cppunit-dev \
    git \
    libtool \
    linux-headers \
    ncurses-dev \
    openssl-dev \
    zlib-dev \
  && rm -rf /tmp/* /var/cache/apk/*

ARG LIBTORRENT_VERSION
RUN cd /tmp \
  && git clone --branch v${LIBTORRENT_VERSION} --recurse-submodules https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
  && ./autotool.sh \
  && ./configure CXXFLAGS="-std=c++14" --with-libiconv \
  && make -j$(nproc) \
  && make install-strip \
  && ls -al /usr/local/lib/

RUN apk add --update --no-cache \
    qt5-qtbase \
    qt5-qttools-dev \
  && rm -rf /tmp/* /var/cache/apk/*

ARG QBITTORRENT_VERSION
RUN cd /tmp \
  && git clone --branch release-${QBITTORRENT_VERSION} https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && ./configure --disable-gui \
  && make -j$(nproc) \
  && make install \
  && ls -al /usr/local/bin/ \
  && qbittorrent-nox --help

FROM alpine:3.14

COPY --from=yasu / /
COPY --from=builder /usr/local/lib/libtorrent-rasterbar.so.10.0.0 /usr/lib/libtorrent-rasterbar.so.10
COPY --from=builder /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

RUN apk --update --no-cache add \
    bind-tools \
    curl \
    openssl \
    qt5-qtbase \
    shadow \
    tzdata \
    unrar \
    unzip \
    zlib \
  && rm -rf /tmp/* /var/cache/apk/*

ENV QBITTORRENT_HOME="/home/qbittorrent" \
  TZ="UTC" \
  PUID="1500" \
  PGID="1500" \
  WEBUI_PORT="8080"

COPY entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh \
  && addgroup -g ${PGID} qbittorrent \
  && adduser -D -h ${QBITTORRENT_HOME} -u ${PUID} -G qbittorrent -s /bin/sh qbittorrent \
  && qbittorrent-nox --version

EXPOSE 6881 6881/udp ${WEBUI_PORT}
WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/usr/bin/qbittorrent-nox" ]

HEALTHCHECK --interval=10s --timeout=10s --start-period=20s \
  CMD curl --fail http://127.0.0.1:${WEBUI_PORT}/api/v2/app/version || exit 1
