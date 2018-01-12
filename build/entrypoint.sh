#!/usr/bin/env sh

# Define a timestamp function
ts() {
  printf "%s %-8s  [%s] %s " `date +"%Y-%m-%d %H:%M:%S"` "$1"
  shift
  echo "$@"
}

export SQUEEZE_UID=$( id -u squeezeboxserver ) \
       SQUEEZE_GID=$( id -g squeezeboxserver )

if [ ! -z "$PUID" ]; then

    export PUID=$(echo "$PUID" | sed -e 's/[^0-9]*//g')
    ts info "Squeezebox user ID defined as $PUID"
  
else

    export PUID="99"
    ts warn "Squeezebox user ID not defined (via -e PUID), defaulting to 99"

fi

if [ ! -z "$PGID" ]; then

    export PGID=$(echo "$PGID" | sed -e 's/[^0-9]*//g')
    ts info "Squeezebox group ID defined as $PGID"
  
else

    export PGID="100"
    ts warn "Squeezebox group ID not defined (via -e PUID), defaulting to 100"

fi  
  
[ "$SQUEEZE_UID" != "$PUID" ] && \
    usermod -o -u "$PUID" squeezeboxserver &>/dev/null

[ "$SQUEEZE_GID" != "$PGID" ] && \
    groupmod -o -g "$PGID" nogroup &>/dev/null

if [ "$SQUEEZE_VOL" ] && [ -d "$SQUEEZE_VOL" ]; then
    for subdir in prefs logs cache; do
        mkdir -p $SQUEEZE_VOL/$subdir
    done
    chown -R squeezeboxserver:nogroup $SQUEEZE_VOL
fi

# This has to happen every time in case our new uid/gid is different
# from what was previously used in the volume.
for f in /usr/share/squeezeboxserver /etc/squeezeboxserver $SQUEEZE_VOL; do
    [ -d "$f" ] && chown -R squeezeboxserver:nogroup "$f"
done

# Set the timezone.
if [ ! -z "$TZ" ] && [ "$TZ" != "$( cat /etc/timezone 2>/dev/null )" ]; then
    echo "$TZ" > /etc/timezone && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata
    ts info "Container timezone set to: $TZ"
else
    ts info "Container timezone not modified"
fi

# LMS config
mkdir -p $SQUEEZE_VOL/cache $SQUEEZE_VOL/logs $SQUEEZE_VOL/prefs
for pref in /etc/squeezeboxserver/*.prefs.install; do
    prefInstalled="$SQUEEZE_VOL/prefs/$( basename $pref | sed -e 's/\.install//' )"
    [ ! -f "$prefInstalled" ] && mv "$pref" "$prefInstalled"
done

# LMS startup arguments
SQUEEZE_RUN_ARGS="--prefsdir $SQUEEZE_VOL/prefs --logdir $SQUEEZE_VOL/logs --cachedir $SQUEEZE_VOL/cache --priority -18 --charset=utf8"
[ "$NO_IMAGE" = false ]         || SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noimage"
[ "$NO_VIDEO" = false ]         || SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --novideo"
[ "$NO_WEB" = true ]            && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noweb"
[ "$NO_MYSQUEEZEBOX" = true ]   && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --nomysqueezebox"
[ "$NO_SLIMP3" = true ]         && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --nosb1slimp3sync"
[ "$NO_ADMIN" = true ]          && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noserver"
[ ! -z "$HTTP_PORT" ]           && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --httpport=$HTTP_PORT"

ts info "Running as user $PUID: squeezeboxserver $SQUEEZE_RUN_ARGS"
exec runuser -u squeezeboxserver -- /usr/sbin/squeezeboxserver $SQUEEZE_RUN_ARGS
