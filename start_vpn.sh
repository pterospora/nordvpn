#!/bin/bash
[[ -n ${DEBUG} ]] && set -x
NET_IFACE=${NET_IFACE:-"eth0"}
[[ -n ${COUNTRY} && -z ${CONNECT} ]] && CONNECT=${COUNTRY}
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g $GROUPID -o vpn

kill_switch() {
	iptables  -F OUTPUT
	ip6tables -F OUTPUT 2> /dev/null
	iptables  -P OUTPUT DROP
	ip6tables -P OUTPUT DROP 2> /dev/null
	iptables  -A OUTPUT -o lo -j ACCEPT
	ip6tables -A OUTPUT -o lo -j ACCEPT 2> /dev/null

	local docker_network=` ip -o addr show dev ${NET_IFACE} | awk '$3 == "inet"  {print $4}'      ` \
	      docker6_network=`ip -o addr show dev ${NET_IFACE} | awk '$3 == "inet6" {print $4; exit}'`	
	[[ -n ${docker_network} ]]  && iptables  -A OUTPUT -d ${docker_network} -j ACCEPT
	[[ -n ${docker6_network} ]] && ip6tables -A OUTPUT -d ${docker6_network} -j ACCEPT 2> /dev/null
	
	iptables  -A OUTPUT -m owner --gid-owner vpn -j ACCEPT || {
		iptables  -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
		iptables  -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
		iptables  -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
		iptables  -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
		iptables  -A OUTPUT -o ${NET_IFACE} -d api.nordvpn.com -j ACCEPT
	}
        ip6tables -A OUTPUT -m owner --gid-owner vpn -j ACCEPT 2>/dev/null || {
		ip6tables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -o ${NET_IFACE} -d api.nordvpn.com -j ACCEPT 2>/dev/null
	}

	[[ -n ${NETWORK} ]]  && for net in ${NETWORK//[;,]/ };  do return_route ${net};  done
	[[ -n ${NETWORK6} ]] && for net in ${NETWORK6//[;,]/ }; do return_route6 ${net}; done
	[[ -n ${WHITELIST} ]] && for domain in ${WHITELIST//[;,]/ }; do white_list ${domain}; done
}

return_route() { # Add a route back to your network, so that return traffic works
    local network="$1" gw="$(ip route | awk '/default/ {print $3}')"
    ip route add to ${network} via ${gw} dev ${NET_IFACE}
    iptables -A OUTPUT --destination ${network} -j ACCEPT
}

return_route6() { # Add a route back to your network, so that return traffic works
    local network="$1" gw="$(ip -6 route | awk '/default/ {print $3}')"
    ip -6 route add to ${network} via ${gw} dev ${NET_IFACE}
    ip6tables -A OUTPUT --destination ${network} -j ACCEPT 2>/dev/null
}

white_list() { # Allow unsecured traffic for an specific domain
    local domain=`echo $1 | sed 's/^.*:\/\///;s/\/.*$//'`
    iptables  -A OUTPUT -o ${NET_IFACE} -d ${domain} -j ACCEPT
    ip6tables -A OUTPUT -o ${NET_IFACE} -d ${domain} -j ACCEPT 2>/dev/null
}

setup_nordvpn() {
	[[ -n ${TECHNOLOGY} ]] && nordvpn set technology ${TECHNOLOGY}
	[[ -n ${PROTOCOL} ]]  && nordvpn set protocol ${PROTOCOL} 
	[[ -n ${OBFUSCATE} ]] && nordvpn set obfuscate ${OBFUSCATE}
	[[ -n ${CYBER_SEC} ]] && nordvpn set cybersec ${CYBER_SEC}
	[[ -n ${DNS} ]] && nordvpn set dns ${DNS}
 	[[ -n ${NETWORK} ]] && for net in ${NETWORK//[;,]/ }; do nordvpn whitelist add subnet $net; done 
	[[ -n ${DEBUG} ]] && nordvpn settings
}

kill_switch

sg vpn -c nordvpnd & 
sleep 0.75

nordvpn login -u ${USER} -p ${PASS} || exit 1

setup_nordvpn

nordvpn connect ${CONNECT} || exit 1

tail -f --pid=$(pidof nordvpnd) /var/log/nordvpn/daemon.log
