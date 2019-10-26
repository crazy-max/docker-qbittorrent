<p align="center"><a href="https://github.com/crazy-max/docker-qbittorrent" target="_blank"><img height="128" src=".res/docker-qbittorrent.jpg"></a></p>

<p align="center">
  <a href="https://hub.docker.com/r/crazymax/qbittorrent/tags?page=1&ordering=last_updated"><img src="https://img.shields.io/github/v/tag/crazy-max/docker-qbittorrent?label=version&style=flat-square" alt="Latest Version"></a>
  <a href="https://github.com/crazy-max/docker-qbittorrent/actions?workflow=build"><img src="https://github.com/crazy-max/docker-qbittorrent/workflows/build/badge.svg" alt="Build Status"></a>
  <a href="https://hub.docker.com/r/crazymax/qbittorrent/"><img src="https://img.shields.io/docker/stars/crazymax/qbittorrent.svg?style=flat-square" alt="Docker Stars"></a>
  <a href="https://hub.docker.com/r/crazymax/qbittorrent/"><img src="https://img.shields.io/docker/pulls/crazymax/qbittorrent.svg?style=flat-square" alt="Docker Pulls"></a>
  <a href="https://www.codacy.com/app/crazy-max/docker-qbittorrent"><img src="https://img.shields.io/codacy/grade/c584240706dc4cc48bd7ebdcd42d7641.svg?style=flat-square" alt="Code Quality"></a>
  <br /><a href="https://www.patreon.com/crazymax"><img src="https://img.shields.io/badge/donate-patreon-f96854.svg?logo=patreon&style=flat-square" alt="Support me on Patreon"></a>
  <a href="https://www.paypal.me/crazyws"><img src="https://img.shields.io/badge/donate-paypal-00457c.svg?logo=paypal&style=flat-square" alt="Donate Paypal"></a>
</p>

## About

🐳 [qBittorrent](https://www.qbittorrent.org/) image based on Alpine Linux.<br />
If you are interested, [check out](https://hub.docker.com/r/crazymax/) my other 🐳 Docker images!

💡 Want to be notified of new releases? Check out 🔔 [Diun (Docker Image Update Notifier)](https://github.com/crazy-max/diun) project!

## Features

* Run as non-root user
* Multi-platform image
* Latest [qBittorrent](https://github.com/qbittorrent/qBittorrent) / [libtorrent-rasterbar](https://github.com/arvidn/libtorrent) release compiled from source
* WAN IP address automatically resolved for reporting to the tracker
* Finished torrents automatically saved to `/data/torrents`
* Handle watch directory from `/data/watch`
* Ability to use an [alternative WebUI](https://github.com/qbittorrent/qBittorrent/wiki/Alternate-WebUI-usage) in `/data/webui`
* Healthcheck through [qBittorrent API](https://github.com/qbittorrent/qBittorrent/wiki/Web-API-Documentation)
* Logs managed through a [dedicated container](examples/traefik/docker-compose.yml)
* [Traefik](https://github.com/containous/traefik-library-image) as reverse proxy and creation/renewal of Let's Encrypt certificates (see [this template](examples/traefik))

## Docker

### Multi-platform image

Following platforms for this image are available:

```
$ docker run --rm mplatform/mquery crazymax/qbittorrent:latest
Image: crazymax/qbittorrent:latest
 * Manifest List: Yes
 * Supported platforms:
   - linux/amd64
   - linux/arm/v7
   - linux/arm64
```

### Environment variables

* `TZ` : Timezone assigned to the container (default `UTC`)
* `WAN_IP` : Public IP address reported to the tracker (default auto resolved with `dig +short myip.opendns.com @resolver1.opendns.com`)
* `ALT_WEBUI`: Enable alternative WebUI located in `/data/webui` (default `false`)

### Volumes

* `/data` : qBittorrent config, downloads, temp, torrents, watch, webui...

> :warning: Note that the volumes should be owned by uid `1500` and gid `1500`. If you don't give the volumes correct permissions, the container may not start.

### Ports

* `6881` : DHT port
* `8080` : qBittorrent HTTP port

## Usage

### Docker Compose

Docker compose is the recommended way to run this image. You can use the following [docker compose template](examples/compose/docker-compose.yml), then run the container:

```bash
$ docker-compose up -d
$ docker-compose logs -f
```

### Command line

You can also use the following minimal command:

```bash
$ docker run -d --name qbittorrent \
  --ulimit nproc=65535 \
  --ulimit nofile=32000:40000 \
  -p 6881:6881/tcp \
  -p 6881:6881/udp \
  -p 8080:8080 \
  -v $(pwd)/data:/data \
  crazymax/qbittorrent:latest
```

## Update

Recreate the container whenever I push an update:

```bash
docker-compose pull
docker-compose up -d
```

## Notes

### qBittorrent Web API

[qBittorrent Web API](https://github.com/qbittorrent/qBittorrent/wiki/Web-API-Documentation) can be used within this image using curl.

```
$ docker-compose exec qbittorrent curl --fail http://127.0.0.1:8080/api/v2/app/version
v4.1.8
```

### Change username and password

You can change the default username `admin` and password `adminadmin` through the API or WebUI.

```
$ docker-compose exec qbittorrent curl --fail -X POST \
  -d 'json={"web_ui_username":"myuser","web_ui_password":"mypassword"}' \
  http://127.0.0.1:8080/api/v2/app/setPreferences
```

## How can I help ?

All kinds of contributions are welcome :raised_hands:!<br />
The most basic way to show your support is to star :star2: the project, or to raise issues :speech_balloon:<br />
But we're not gonna lie to each other, I'd rather you buy me a beer or two :beers:!

[![Support me on Patreon](.res/patreon.png)](https://www.patreon.com/crazymax) 
[![Paypal Donate](.res/paypal.png)](https://www.paypal.me/crazyws)

## License

MIT. See `LICENSE` for more details.
