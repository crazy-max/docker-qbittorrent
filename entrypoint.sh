#!/bin/sh

if [ -n "${DHT_PORT}" ]; then
  if ! { [ "${DHT_PORT}" -ge 1 ] && [ "${DHT_PORT}" -le 65535 ]; } 2>/dev/null; then
    echo "DHT_PORT must be an integer from 1 to 65535" >&2
    exit 1
  fi
  export QBT_TORRENTING_PORT="${DHT_PORT}"
fi

if [ -z "${WAN_IP}" ]; then
  WAN_IP=$(dig +short myip.opendns.com @resolver1.opendns.com) || WAN_IP=
fi
echo "WAN IP address is ${WAN_IP}"

if [ -n "${PGID}" ] && [ "${PGID}" != "$(id -g qbittorrent)" ]; then
  echo "Switching to PGID ${PGID}..."
  groupmod -o -g "${PGID}" qbittorrent || exit 1
fi
if [ -n "${PUID}" ] && [ "${PUID}" != "$(id -u qbittorrent)" ]; then
  echo "Switching to PUID ${PUID}..."
  usermod -o -u "${PUID}" qbittorrent || exit 1
fi

WEBUI_PORT=${WEBUI_PORT:-8080}
ALT_WEBUI=${ALT_WEBUI:-false}
if [ "${ALT_WEBUI}" != "true" ]; then
  ALT_WEBUI=false
fi

echo "Creating folders..."
mkdir -p /data/config \
  /data/data \
  /data/downloads \
  /data/temp \
  /data/torrents \
  /data/watch \
  /data/webui \
  "${QBITTORRENT_HOME}/.config" \
  "${QBITTORRENT_HOME}/.local/share" \
  /var/log/qbittorrent
if [ ! -e "${QBITTORRENT_HOME}/.config/qBittorrent" ]; then
  ln -s /data/config "${QBITTORRENT_HOME}/.config/qBittorrent"
fi
if [ ! -e "${QBITTORRENT_HOME}/.local/share/qBittorrent" ]; then
  ln -s /data/data "${QBITTORRENT_HOME}/.local/share/qBittorrent"
fi

# https://github.com/qbittorrent/qBittorrent/blob/master/src/base/settingsstorage.cpp
if [ ! -f /data/config/qBittorrent.conf ]; then
  echo "Initializing qBittorrent configuration..."
  cat > /data/config/qBittorrent.conf <<EOL
[General]
ported_to_new_savepath_system=true

[Application]
FileLogger\Enabled=true
FileLogger\Path=/var/log/qbittorrent

[BitTorrent]
Session\AddTrackersEnabled=false
Session\AddTorrentStopped=false
Session\AnnounceIP=${WAN_IP}
Session\DefaultSavePath=/data/downloads
Session\FinishedTorrentBackupDirectory=/data/torrents
Session\FinishedTorrentBackupDirectoryEnabled=true
Session\Port=6881
Session\Preallocation=true
Session\TempPath=/data/temp
Session\TempPathEnabled=true

[LegalNotice]
Accepted=true

[Network]
PortForwardingEnabled=false

[Preferences]
General\Locale=en

[WebUI]
Enabled=true
HTTPS\Enabled=false
Address=0.0.0.0
Port=${WEBUI_PORT}
LocalHostAuth=false
AlternativeUIEnabled=${ALT_WEBUI}
RootFolder=/data/webui
EOL
fi

echo "Overriding required parameters..."
sed -i "s!ported_to_new_savepath_system.*!ported_to_new_savepath_system=true!g" /data/config/qBittorrent.conf
sed -i "s!FileLogger\\\Enabled=.*!FileLogger\\\Enabled=true!g" /data/config/qBittorrent.conf
sed -i "s!FileLogger\\\Path=.*!FileLogger\\\Path=/var/log/qbittorrent!g" /data/config/qBittorrent.conf

# qBittorrent migrates legacy [Preferences] keys on the first upgraded start.
sed -i \
  -e 's!^Connection\\InetAddress=.*!Connection\\InetAddress='"${WAN_IP}"'!' \
  -e 's!^Session\\AnnounceIP=.*!Session\\AnnounceIP='"${WAN_IP}"'!' \
  /data/config/qBittorrent.conf
sed -i \
  -e 's!^Downloads\\SavePath=.*!Downloads\\SavePath=/data/downloads!' \
  -e 's!^Downloads\\TempPath=.*!Downloads\\TempPath=/data/temp!' \
  -e 's!^Downloads\\TempPathEnabled=.*!Downloads\\TempPathEnabled=true!' \
  -e 's!^Downloads\\FinishedTorrentExportDir=.*!Downloads\\FinishedTorrentExportDir=/data/torrents!' \
  -e 's!^WebUI\\Enabled=.*!WebUI\\Enabled=true!' \
  -e 's!^WebUI\\Address=.*!WebUI\\Address=0.0.0.0!' \
  -e 's!^WebUI\\Port=.*!WebUI\\Port='"${WEBUI_PORT}"'!' \
  -e 's!^WebUI\\LocalHostAuth=.*!WebUI\\LocalHostAuth=false!' \
  -e 's!^WebUI\\RootFolder=.*!WebUI\\RootFolder=/data/webui!' \
  -e '/^\[WebUI\]/,/^\[/ {
    s!^Enabled=.*!Enabled=true!
    s!^Address=.*!Address=0.0.0.0!
    s!^Port=.*!Port='"${WEBUI_PORT}"'!
    s!^LocalHostAuth=.*!LocalHostAuth=false!
    s!^RootFolder=.*!RootFolder=/data/webui!
  }' /data/config/qBittorrent.conf

echo "Fixing perms..."
chown qbittorrent:qbittorrent /data \
  /data/config \
  /data/config/qBittorrent.conf \
  /data/data \
  /data/downloads \
  /data/temp \
  /data/torrents \
  /data/watch \
  /data/webui
chown -R qbittorrent:qbittorrent "${QBITTORRENT_HOME}" /var/log/qbittorrent

exec gosu qbittorrent:qbittorrent "$@"
