#!/usr/bin/env bash
set -e

testAlias+=(
	[eilidhmae/openvpn]='openvpn'
)

imageTests+=(
	[openvpn]='
	paranoid
	'
)
