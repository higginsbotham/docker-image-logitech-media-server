#!/bin/sh

# Define a timestamp function
ts() {
  printf "[%s %-8s]  %s  " `date +"%y-%m-%d %H:%M:%S.%4N"` "$( echo "$1" | sed 's/./\U&/g' )"
  shift
  echo "$@"
}

export SQUEEZE_UID=$( id -u squeezeboxserver ) \
       SQUEEZE_GID=$( id -g squeezeboxserver )

if [ ! -z "$PUID" ]; then

    export PUID=$(echo "$PUID" | sed -e 's/[^0-9]*//g')
    ts setup "Squeezebox UID defined as $PUID"
  
else

    export PUID="99"
    ts warn "Squeezebox UID not defined (via -e PUID), defaulting to  99"

fi

if [ ! -z "$PGID" ]; then

    export PGID=$(echo "$PGID" | sed -e 's/[^0-9]*//g')
    ts setup "Squeezebox GID defined as $PGID"
  
else

    export PGID="100"
    ts warn "Squeezebox GID not defined (via -e PUID), defaulting to 100"

fi  
  
[ "$SQUEEZE_UID" != "$PUID" ] && \
    usermod -o -u "$PUID" squeezeboxserver &>/dev/null

[ "$SQUEEZE_GID" != "$PGID" ] && \
    groupmod -o -g "$PGID" nogroup &>/dev/null

if [ "$SQUEEZE_VOL" ] && [ -d "$SQUEEZE_VOL" ]; then
    for subdir in prefs logs cache; do
        [ ! -d "$SQUEEZE_VOL/$subdir" ] && mkdir -p $SQUEEZE_VOL/$subdir
    done
    chown -R squeezeboxserver:nogroup $SQUEEZE_VOL
fi

# This has to happen every time in case our new uid/gid is different
# from what was previously used in the volume.
for f in /usr/share/squeezeboxserver /etc/squeezeboxserver; do
    [ -d "$f" ] && chown -R squeezeboxserver:nogroup "$f"
done

# Set the timezone.
if [ ! -z "$TZ" ] && [ "$TZ" != "$( cat /etc/timezone 2>/dev/null )" ]; then
    echo "$TZ" > /etc/timezone && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata
    ts setup "Container timezone set to: $TZ"
else
    ts setup "Container timezone not modified: $TZ"
fi

# LMS config
set -- /home/*.prefs.install
if [ -f "$1" ]; then
    for pref in /home/*.prefs.install; do
        if [ -f "$pref" ]; then
            ts setup "Installing transcoding rule: $( basename "$pref" | cut -d. -f1 )"
            prefInstalled="$SQUEEZE_VOL/prefs/$( basename "$pref" | sed -e 's/\.install//' )"
            [ ! -f "$prefInstalled" ] && cp "$pref" "$prefInstalled"
            mv "$pref" "$SQUEEZE_VOL/prefs/"
        fi
    done
fi
set -- /home/*.conf
if [ -f "$1" ]; then
    for conf in /home/*.conf; do
        if [ -f "$conf" ]; then
            ts setup "Installing configuration file: $( basename "$conf" | cut -d. -f1 )"
            [ ! -f "/etc/squeezeboxserver/$( basename "$conf" )" ] && mv "$conf" "/etc/squeezeboxserver/"
        fi
    done
fi

# LMS startup arguments
SQUEEZE_RUN_ARGS="--prefsdir $SQUEEZE_VOL/prefs --logdir $SQUEEZE_VOL/logs --cachedir $SQUEEZE_VOL/cache --priority -18 --charset=utf8"
[ "$NO_IMAGE" = false ]         || SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noimage"
[ "$NO_VIDEO" = false ]         || SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --novideo"
[ "$NO_WEB" = true ]            && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noweb"
[ "$NO_MYSQUEEZEBOX" = true ]   && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --nomysqueezebox"
[ "$NO_SLIMP3" = true ]         && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --nosb1slimp3sync"
[ "$NO_ADMIN" = true ]          && SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --noserver"

if [ ! -z "$HTTP_PORT" ] && [ "$HTTP_PORT" -ne "9000" ]; then
    SQUEEZE_RUN_ARGS="$SQUEEZE_RUN_ARGS --httpport=$HTTP_PORT"
    ts warn "Using nonstandard HTTP port ${HTTP_PORT}. You must publish this port using 'docker run -p ${HTTP_PORT}:${HTTP_PORT}' or in the docker-compose.yml file."
fi

if [ ! -z "$SAMPLE_RATE_LIMIT" ]; then
    
    # Sanitize the input
    SAMPLE_RATE_LIMIT="$( echo "$SAMPLE_RATE_LIMIT" | grep -o '[0-9.KMGTPEZY]\+.*' | awk '{ ex = index("KMGTPEZY", substr(toupper($1), length($1))); val = substr($1, 0, length($1)); prod = val * 10^(ex * 3); sum += prod; } END { if (ex >0) print substr(sum,1,6); else print substr($1,1,6) }' | grep -o '[0-9]\+' )"

    # Set rate limits for both families
    SAMPLE_RATE_LIMIT_44="$( echo "$SAMPLE_RATE_LIMIT" | awk '{print sprintf("%.0f",(int($0/44100)/2)*2)*44100}' )"
    SAMPLE_RATE_LIMIT_48="$( echo "$SAMPLE_RATE_LIMIT" | awk '{print sprintf("%.0f",$0/48000)*48000}' )"
    
    [ $SAMPLE_RATE_LIMIT_44 -eq 0 ] && SAMPLE_RATE_LIMIT_44=$SAMPLE_RATE_LIMIT
    [ $SAMPLE_RATE_LIMIT_48 -eq 0 ] && SAMPLE_RATE_LIMIT_48=$SAMPLE_RATE_LIMIT

else
    # Sane defaults. Most headphone DACs can do this.
    SAMPLE_RATE_LIMIT_48=96000
    SAMPLE_RATE_LIMIT_44=88200
fi

sox_upsample_prefs="$SQUEEZE_VOL/prefs/sox_upsample.prefs"
sox_upsample_prefs_TMPL="$sox_upsample_prefs.install"

if [ ! -z "$UPSAMPLE_STREAM" ] && [ "$UPSAMPLE_STREAM" = true ]; then
    if [ -f "$sox_upsample_prefs_TMPL" ]; then
        rm -f "$sox_upsample_prefs"
        while read -r LINE; do 
            
            rate="$( echo $LINE | cut -d: -f1 )"
            params="$( echo $LINE | cut -d: -f2 | sed -e 's/ -a//g' )"
            
            if [ $( expr $rate % 44100 ) -eq 0 ]; then
                # 44.1kHz family
                # No resampling if source is equal to the limit.
                if [ $rate -eq $SAMPLE_RATE_LIMIT_44 ]; then
                    params=""
                elif [ $rate -lt $SAMPLE_RATE_LIMIT_44 ]; then
                # Use aliasing (-a) for upsampling only. Everything above the limit will be downsampled without aliasing.
                    params="$( echo $params | sed -e "s/\([0-9][0-9][0-9]\+\)/-a $SAMPLE_RATE_LIMIT_44/" )"
                else
                    params="$( echo $params | sed -e "s/\([0-9][0-9][0-9]\+\)/$SAMPLE_RATE_LIMIT_44/" )"
                fi
                
            elif [ $( expr $rate % 48000 ) -eq 0 ]; then
                # 48kHz family
                if [ $rate -eq $SAMPLE_RATE_LIMIT_48 ]; then
                    params=""
                elif [ $rate -lt $SAMPLE_RATE_LIMIT_48 ]; then
                    params="$( echo $params | sed -e "s/\([0-9][0-9][0-9]\+\)/-a $SAMPLE_RATE_LIMIT_48/" )"
                else
                    params="$( echo $params | sed -e "s/\([0-9][0-9][0-9]\+\)/$SAMPLE_RATE_LIMIT_48/" )"
                fi
            fi
            
            echo "$rate: $params" >> "$sox_upsample_prefs"
            
        done < "$sox_upsample_prefs_TMPL"
        
    else
        # Template file does not exist.
        ts warn "Transcoding prefs template file for SoX upsampling was not found: $SQUEEZE_VOL/prefs/sox_upsample.prefs.install"  
    fi
    ts info "Resampling streams to ${SAMPLE_RATE_LIMIT_44} Hz or ${SAMPLE_RATE_LIMIT_48} Hz."
fi

ts info "Running as user $PUID: squeezeboxserver $SQUEEZE_RUN_ARGS"
exec runuser -u squeezeboxserver -- /usr/sbin/squeezeboxserver $SQUEEZE_RUN_ARGS
