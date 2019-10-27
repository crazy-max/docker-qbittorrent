FROM alpine:3.10 as builder

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

RUN apk add --update --no-cache \
    autoconf \
    automake \
    binutils \
    boost-dev \
    boost-python3 \
    build-base \
    cppunit-dev \
    git \
    libtool \
    linux-headers \
    ncurses-dev \
    openssl-dev \
    python3-dev \
    zlib-dev \
  && rm -rf /tmp/* /var/cache/apk/*

ENV LIBTORRENT_VERSION="1.1.13"

RUN cd /tmp \
  && git clone https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
  && git checkout tags/libtorrent-${LIBTORRENT_VERSION//./_} \
  && ./autotool.sh \
  && ./configure \
    --with-libiconv \
    --enable-python-binding \
    --with-boost-python="$(ls -1 /usr/lib/libboost_python3*.so* | sort | head -1 | sed 's/.*.\/lib\(.*\)\.so.*/\1/')" \
    PYTHON="$(which python3)" \
  && make -j$(nproc) \
  && make install-strip \
  && ls -al /usr/local/lib/

RUN apk add --update --no-cache \
    qt5-qtbase \
    qt5-qttools-dev \
  && rm -rf /tmp/* /var/cache/apk/*

ENV QBITTORRENT_VERSION="4.1.8"

RUN cd /tmp \
  && git clone https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && git checkout tags/release-${QBITTORRENT_VERSION} \
  && ./configure --disable-gui \
  && make -j$(nproc) \
  && make install \
  && ls -al /usr/local/bin/ \
  && qbittorrent-nox --help

FROM alpine:3.10

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL maintainer="CrazyMax" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="qbittorrent" \
  org.label-schema.description="qBittorrent" \
  org.label-schema.version=$VERSION \
  org.label-schema.url="https://github.com/crazy-max/docker-qbittorrent" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/crazy-max/docker-qbittorrent" \
  org.label-schema.vendor="CrazyMax" \
  org.label-schema.schema-version="1.0"

COPY --from=builder /usr/local/lib/libtorrent-rasterbar.so.9.0.0 /usr/lib/libtorrent-rasterbar.so.9
COPY --from=builder /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

RUN apk --update --no-cache add \
    bind-tools \
    curl \
    py2-pip \
    qt5-qtbase \
    shadow \
    tzdata \
  && pip install crudini \
  && crudini --version \
  && rm -rf /tmp/* /var/cache/apk/*

ENV QBITTORRENT_HOME="/home/qbittorrent" \
  TZ="UTC"

COPY entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh \
  && addgroup -g 1500 qbittorrent \
  && adduser -D -h ${QBITTORRENT_HOME} -u 1500 -G qbittorrent -s /sbin/nologin qbittorrent \
  && mkdir -p \
    /data/config \
    /data/data \
    ${QBITTORRENT_HOME}/.config \
    ${QBITTORRENT_HOME}/.local/share/data \
    /var/log/qbittorrent \
  && ln -s /data/config ${QBITTORRENT_HOME}/.config/qBittorrent \
  && ln -s /data/data ${QBITTORRENT_HOME}/.local/share/data/qBittorrent \
  && chown -R qbittorrent. /data ${QBITTORRENT_HOME} /var/log/qbittorrent

USER qbittorrent

EXPOSE 6881 6881/udp 8080
WORKDIR /data
VOLUME [ "/data" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/usr/bin/qbittorrent-nox" ]

HEALTHCHECK --interval=10s --timeout=10s --start-period=10s \
  CMD curl --fail http://127.0.0.1:8080/api/v2/app/version || exit 1
