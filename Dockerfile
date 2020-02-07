FROM debian:buster

LABEL maintainer="Julio Gutierrez <bubuntux@gmail.com>"

HEALTHCHECK --interval=60s --timeout=5s --start-period=120s \
		CMD ping -c 1 -q google.com; if test "$?" != "0"; then nordvpn connect ${CONNECT} ; exit 1; fi

ARG NORDVPN_BIN_ARCH=armhl
ARG NORDVPN_BIN_VERSION=3.6.0-5

RUN addgroup --system vpn && \
    apt-get update && apt-get upgrade -y && \
    curl "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn_${NORDVPN_BIN_VERSION}_${NORDVPN_BIN_ARCH}.deb" -o /tmp/nordvpn.deb && \
    apt-get install -y /tmp/nordvpn.deb || echo "error on post-installation script expected" && \
    update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy && \
    apt-get clean && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/*

COPY start_vpn.sh /usr/bin
CMD /usr/bin/start_vpn.sh
