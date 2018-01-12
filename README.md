# Docker Container for Logitech Media Server

This is a Docker image for running the Logitech Media Server package
(aka SqueezeboxServer).

It contains my own transcoding rules that make use of not-well-documented functionality in order to more fully integrate SoX's stellar resampling capabilities.

Also, when transcoding to MP3 the encoder uses VBR mode for most target bitrates instead of ABR. The two exceptions are when no bitrate target is specified by the player, the default quality setting is VBR 0 (`--preset extreme`), and when 320kbps is specified it uses CBR mode (`--preset insane`).

Binaries for popular de/encoders are updated to latest versions.

The web interface runs on port 9000. Players will connect on that port so make sure it remains published even if you also publish it to host port 80 (`80:9000`), or if you disable the web server (see Environment Variables, below).

Using docker-compose
====================

There is a [docker-compose.yml][] included in this repository. This is currently the best way to build the image and run the container, since it is not published on the Docker Hub. The compose file includes the following:

    volumes:
      - ${AUDIO_DIR}:/music:ro
      - ${PLAYLIST_DIR}:/playlists:rw
      - ${CONFIG_DIR}:/config

To provide values for these, you can edit the file directly, or create a `.env` file that defines each, for example:

    AUDIO_DIR=/music/library
    PLAYLIST_DIR=/music/playlists
    CONFIG_DIR=/var/lib/squeezeboxserver

Environment Variables
---------------------

There are a few other environment variables you can set:

* `TZ`: The timezone, such as `TZ=America/New_York`.
* `PUID` and `PGID`: In case permissions are an issue, set the UID and GID for the process. This will also `chown` the Squeezebox directories. Defaults: `99` (PUID) and `100` (PGID)
* `SOX_OPTS`: Define global options for SoX, such as `--guard` to prevent clipping when resampling.

The [docker-compose.yml][] file can be edited to change these:

* `NO_SLIMP3`: Disable support for SliMP3s, SB1s and associated synchronization. Default: `false`
* `NO_MYSQUEEZEBOX`: Disable mysqueezebox.com integration. Default: `false`
* `NO_IMAGE`: Disable scanning for images. (Will still scan for cover images.) Default: `true`
* `NO_VIDEO`: Disable scanning for videos. Default: `true`
* `NO_WEB`: Disable web interface. JSON-RPC, Comet, and artwork web APIs are still enabled. Default: `false`
* `NO_ADMIN`: Disable web access server settings, but leave player settings accessible. Settings changes are not preserved. Default: `false`

It passes `LMS_VERSION` to the Dockerfile as a build argument:
* `LMS_VERSION`: The version to install. For nightly set to `7.9.1`. Default: `7.9.0`
    
[docker-compose.yml]: docker-compose.yml