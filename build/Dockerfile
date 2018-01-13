FROM debian:stable-slim

ARG LMS_VERSION=7.9.0

ENV HTTP_PORT=9000 \
    SQUEEZE_VOL="/config" \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update -q && \
    apt-get install -q -y --no-install-recommends \
        curl \
        faad \
        wavpack \
        flac \
        lame \
        sox \
        libsox-fmt-mp3 \
        tzdata \
        libio-socket-ssl-perl

# Install LMS nightly build and upgrade tools
RUN url=$( curl -Lsf "http://www.mysqueezebox.com/update/?version=${LMS_VERSION}&revision=1&geturl=1&os=deb" | sed 's/_all/_amd64/' ) && \
    curl -Lsf -o /tmp/logitechmediaserver.deb $url && \
    dpkg -i /tmp/logitechmediaserver.deb && \
    rm -f /tmp/logitechmediaserver.deb && \
    # Reduce LMS of cruft: Font, Graphics
    for lms_cruft in "CPAN/Font" Graphics; do \
        rm -rf "/usr/share/squeezeboxserver/$lms_cruft"; \
    done && \
    # Reduce LMS of cruft: old Perl modules
    for perl_cruft in 5.8 5.10 5.12 5.14 5.16 5.18 5.20 5.22; do \
        rm -rf /usr/share/squeezeboxserver/CPAN/arch/$perl_cruft; \
    done && \
    # Patch TranscodingHelper.pm to make new variable available
    # to custom-convert.conf: sample rate
    sed -i -e '/^[[:space:]]\+outputChannels/a\\t\t\tsamplerate       => $track->samplerate() || 44100,' -e "/^[[:space:]]\+\$subs{'OCHANNELS'} =/a\ \ \ \ \ \ \ \ \$subs{'SAMPLERATE'} = \$transcoder->{'samplerate'};" /usr/share/perl5/Slim/Player/TranscodingHelper.pm && \
    # Link in the updated de/transcoding tools
    # Add tools 
    for tool in faad flac lame mac sox wvunpack; do \
        if [ -f "/usr/bin/${tool}" ]; then \
              rm -f "/usr/share/squeezeboxserver/Bin/x86_64-linux/${tool}"; \
              ln -s "/usr/bin/${tool}" "/usr/share/squeezeboxserver/Bin/x86_64-linux/${tool}"; \
        fi; \
    done && \
	# Clean up
	apt-get update -q && \
    apt-get upgrade -q -y --no-install-recommends && \
    apt-get dist-upgrade -q -y --no-install-recommends && \
    apt-get clean -q -y && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/* \
        /usr/local/share/* && \
    # Volumes and permissions
    mkdir -p $SQUEEZE_VOL && \
    chown -R squeezeboxserver:nogroup $SQUEEZE_VOL

VOLUME $SQUEEZE_VOL

EXPOSE 3483 3483/udp $HTTP_PORT 9090

COPY prefs/* /etc/squeezeboxserver/

COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh \
    && chmod +x /healthcheck.sh

HEALTHCHECK --interval=5m --timeout=5s \
    CMD /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
