#!/bin/sh

WAN_IP=${WAN_IP:-$(dig +short myip.opendns.com @resolver1.opendns.com)}
echo "WAN IP address is ${WAN_IP}"

if [ -n "${PGID}" ] && [ "${PGID}" != "$(id -g qbittorrent)" ]; then
  echo "Switching to PGID ${PGID}..."
  sed -i -e "s/^qbittorrent:\([^:]*\):[0-9]*/qbittorrent:\1:${PGID}/" /etc/group
  sed -i -e "s/^qbittorrent:\([^:]*\):\([0-9]*\):[0-9]*/qbittorrent:\1:\2:${PGID}/" /etc/passwd
fi
if [ -n "${PUID}" ] && [ "${PUID}" != "$(id -u qbittorrent)" ]; then
  echo "Switching to PUID ${PUID}..."
  sed -i -e "s/^qbittorrent:\([^:]*\):[0-9]*:\([0-9]*\)/qbittorrent:\1:${PUID}:\2/" /etc/passwd
fi

ALT_WEBUI=${ALT_WEBUI:-false}
if [ "${ALT_WEBUI}" != "true" ]; then
  ALT_WEBUI=false
fi

# /data/watch | Default save location
WATCH_DIR="@Variant(\0\0\0\x1c\0\0\0\x1\0\0\0\x16\0/\0\x64\0\x61\0t\0\x61\0/\0w\0\x61\0t\0\x63\0h\0\0\0\x2\0\0\0\x1)"

echo "Creating folders..."
mkdir -p /data/downloads \
  /data/temp \
  /data/torrents \
  /data/watch \
  /data/webui

# https://github.com/qbittorrent/qBittorrent/blob/master/src/base/settingsstorage.cpp
if [ ! -f /data/config/qBittorrent.conf ]; then
  echo "Initializing qBittorrent configuration..."
  cat > /data/config/qBittorrent.conf <<EOL
[General]
ported_to_new_savepath_system=true

[Application]
FileLogger\Enabled=true
FileLogger\Path=/var/log/qbittorrent

[LegalNotice]
Accepted=true

[Preferences]
Bittorrent\AddTrackers=false
Connection\InetAddress=${WAN_IP}
Connection\InterfaceListenIPv6=false
Connection\PortRangeMin=6881
Connection\UseUPnP=false
Downloads\PreAllocation=true
Downloads\SavePath=/data/downloads
Downloads\ScanDirsV2=${WATCH_DIR}
Downloads\StartInPause=false
Downloads\TempPath=/data/temp
Downloads\TempPathEnabled=true
Downloads\FinishedTorrentExportDir=/data/torrents
General\Locale=en
General\UseRandomPort=false
WebUI\Enabled=true
WebUI\HTTPS\Enabled=false
WebUI\Address=0.0.0.0
WebUI\Port=${WEBUI_PORT}
WebUI\LocalHostAuth=false
WebUI\AlternativeUIEnabled=${ALT_WEBUI}
WebUI\RootFolder=/data/webui
EOL
fi

echo "Overriding required parameters..."
sed -i "s!ported_to_new_savepath_system.*!ported_to_new_savepath_system=true!g" /data/config/qBittorrent.conf
sed -i "s!FileLogger\\\Enabled.*!FileLogger\\Enabled=true!g" /data/config/qBittorrent.conf
sed -i "s!FileLogger\\\Path.*!FileLogger\\Path=/var/log/qbittorrent!g" /data/config/qBittorrent.conf
sed -i "s!Connection\\\InetAddress.*!Connection\\InetAddress=${WAN_IP}!g" /data/config/qBittorrent.conf
sed -i "s!Connection\\\InterfaceListenIPv6.*!Connection\\InterfaceListenIPv6=false!g" /data/config/qBittorrent.conf
sed -i "s!Connection\\\UseUPnP.*!Connection\\UseUPnP=false!g" /data/config/qBittorrent.conf
sed -i "s!Connection\\\InetAddress.*!Connection\\InetAddress=${WAN_IP}!g" /data/config/qBittorrent.conf
sed -i "s!Downloads\\\SavePath.*!Downloads\\SavePath=/data/downloads!g" /data/config/qBittorrent.conf
sed -i "s!Downloads\\\ScanDirsV2.*!Downloads\\ScanDirsV2=${WATCH_DIR}!g" /data/config/qBittorrent.conf
sed -i "s!Downloads\\\TempPath.*!Downloads\\TempPath=/data/temp!g" /data/config/qBittorrent.conf
sed -i "s!Downloads\\\TempPathEnabled.*!Downloads\\TempPathEnabled=true!g" /data/config/qBittorrent.conf
sed -i "s!Downloads\\\FinishedTorrentExportDir.*!Downloads\\FinishedTorrentExportDir=/data/torrents!g" /data/config/qBittorrent.conf
sed -i "s!WebUI\\\Enabled.*!WebUI\\Enabled=true!g" /data/config/qBittorrent.conf
sed -i "s!WebUI\\\Address.*!WebUI\\Address=0\.0\.0\.0!g" /data/config/qBittorrent.conf
sed -i "s!WebUI\\\Port.*!WebUI\\Port=8080!g" /data/config/qBittorrent.conf
sed -i "s!WebUI\\\LocalHostAuth.*!WebUI\\LocalHostAuth=false!g" /data/config/qBittorrent.conf
sed -i "s!WebUI\\\RootFolder.*!WebUI\\RootFolder=/data/webui!g" /data/config/qBittorrent.conf

echo "Fixing perms..."
chown -R qbittorrent:qbittorrent /data "${QBITTORRENT_HOME}" /var/log/qbittorrent

exec su-exec qbittorrent:qbittorrent "$@"
