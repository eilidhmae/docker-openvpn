#!/usr/bin/env bash
set -e

[ -n "${DEBUG+x}" ] && set -x

OVPN_DATA=dual-data
CLIENT_UDP=test-client
CLIENT_TCP=test-client-tcp
IMG=eilidhmae/openvpn
CLIENT_DIR="$(readlink -f "$(dirname "$BASH_SOURCE")/../../client")"

ip addr ls
SERV_IP=$(ip -4 -o addr show scope global  | awk '{print $4}' | sed -e 's:/.*::' | head -n1)

# get temporary TCP config
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_genconfig -u tcp://$SERV_IP:443

# nopass is insecure
docker run -v $OVPN_DATA:/etc/openvpn --rm -it -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN=Test CA" $IMG ovpn_initpki nopass

# gen TCP client
docker run -v $OVPN_DATA:/etc/openvpn --rm -it $IMG easyrsa --batch build-client-full $CLIENT_TCP nopass
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_getclient $CLIENT_TCP | tee $CLIENT_DIR/config-tcp.ovpn

# switch to UDP config and gen UDP client
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_genconfig -u udp://$SERV_IP
docker run -v $OVPN_DATA:/etc/openvpn --rm -it $IMG easyrsa --batch build-client-full $CLIENT_UDP nopass
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_getclient $CLIENT_UDP | tee $CLIENT_DIR/config.ovpn

#Verify client configs
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_listclients | grep $CLIENT_TCP
docker run -v $OVPN_DATA:/etc/openvpn --rm $IMG ovpn_listclients | grep $CLIENT_UDP

#
# Fire up the server
#

# Run in shell bg to get logs, setup trap to clean-up
trap "{ jobs -p | xargs -r kill; wait; docker volume rm ${OVPN_DATA}; }" EXIT
docker run --name "ovpn-test-udp" -v $OVPN_DATA:/etc/openvpn --rm --privileged -e DEBUG $IMG &
docker run --name "ovpn-test-tcp" -v $OVPN_DATA:/etc/openvpn --rm --privileged -e DEBUG $IMG ovpn_run --proto tcp --port 443 &

# Update configs
for i in $(seq 10); do
    SERV_IP_INTERNAL=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "ovpn-test-udp" 2>/dev/null || true)
    test -n "$SERV_IP_INTERNAL" && break
    sleep 0.1
done
sed -i -e s:$SERV_IP:$SERV_IP_INTERNAL:g $CLIENT_DIR/config.ovpn

for i in $(seq 10); do
    SERV_IP_INTERNAL=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "ovpn-test-tcp" 2>/dev/null || true)
    test -n "$SERV_IP_INTERNAL" && break
    sleep 0.1
done
sed -i -e s:$SERV_IP:$SERV_IP_INTERNAL:g $CLIENT_DIR/config-tcp.ovpn

#
# Fire up test clients in a container
#
docker run --rm --privileged -v $CLIENT_DIR:/client -e DEBUG $IMG /client/wait-for-connect.sh
docker run --rm --privileged -v $CLIENT_DIR:/client -e DEBUG $IMG /client/wait-for-connect.sh "/client/config-tcp.ovpn"

#
# Celebrate
#
cat <<EOF
 ____________               ___________
< it worked! >             < both ways! >
 ------------               ------------
        \   ^__^        ^__^   /
	 \  (oo)\______/(oo)  /
	    (__)\      /(__)
                ||w---w||
                ||     ||
EOF

