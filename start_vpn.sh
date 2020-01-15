#!/bin/bash

[[ -n ${DEBUG} ]] && set -x

kill_switch() {
	iptables  -F OUTPUT
	ip6tables -F OUTPUT 2> /dev/null
	iptables  -P OUTPUT DROP
	ip6tables -P OUTPUT DROP 2> /dev/null
	iptables  -A OUTPUT -o lo -j ACCEPT
	ip6tables -A OUTPUT -o lo -j ACCEPT 2> /dev/null

	local net_iface=${NET_IFACE:-"eth0"}
	      docker_network=` ip -o addr show dev ${net_iface} | awk '$3 == "inet"  {print $4}'      ` \
	      docker6_network=`ip -o addr show dev ${net_iface} | awk '$3 == "inet6" {print $4; exit}'`	
	[[ -n ${docker_network} ]]  && iptables  -A OUTPUT -d ${docker_network} -j ACCEPT
	[[ -n ${docker6_network} ]] && ip6tables -A OUTPUT -d ${docker6_network} -j ACCEPT 2> /dev/null
	
	if [[ ${GROUPID:-""} =~ ^[0-9]+$ ]]; then
		groupmod -g ${GROUPID} -o vpn
	else
		groupadd vpn 
	fi
	iptables  -A OUTPUT -m owner --gid-owner vpn -j ACCEPT || {
		iptables  -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
		iptables  -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
		iptables  -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
		iptables  -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
		iptables  -A OUTPUT -o ${net_iface} -d api.nordvpn.com -j ACCEPT
	}
        ip6tables -A OUTPUT -m owner --gid-owner vpn -j ACCEPT 2>/dev/null || {
		ip6tables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT 2>/dev/null
		ip6tables -A OUTPUT -o ${net_iface} -d api.nordvpn.com -j ACCEPT 2>/dev/null
	}
}

setup_nordvpn() {
	[[ -n ${TECHNOLOGY} ]] && nordvpn set technology ${TECHNOLOGY}
	[[ -n ${PROTOCOL} ]]  && nordvpn set protocol ${PROTOCOL} 
	[[ -n ${OBFUSCATE} ]] && nordvpn set obfuscate ${OBFUSCATE}
	[[ -n ${CYBER_SEC} ]] && nordvpn set cybersec ${CYBER_SEC}
	[[ -n ${DNS} ]] && nordvpn set dns ${DNS}
	[[ -n ${SUBNET} ]] && for net in ${SUBNET//[;,]/ }; do nordvpn whitelist add subnet $net; done
	[[ -n ${DEBUG} ]] && nordvpn settings
}

kill_switch

sg vpn -c nordvpnd & 
sleep 0.5

nordvpn login -u ${USER} -p ${PASS} || exit 1

setup_nordvpn

nordvpn connect ${CONNECT} || exit 1

tail -f --pid=$(pidof nordvpnd) /var/log/nordvpn/daemon.log
