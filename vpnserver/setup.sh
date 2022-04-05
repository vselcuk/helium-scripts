#!/bin/bash
set -e 

export APPROVE_IP=y
export ENDPOINT=$(curl -s ifconfig.co)
export IPV6_SUPPORT=n
export PORT_CHOICE=1
export PROTOCOL_CHOICE=1
export DNS=9
export COMPRESSION_ENABLED=n

export CUSTOMIZE_ENC=y
export CIPHER_CHOICE=4
export CERT_TYPE=2
export RSA_KEY_SIZE_CHOICE=1
export CC_CIPHER_CHOICE=1
export DH_TYPE=1
export DH_CURVE_CHOICE=1
export HMAC_ALG_CHOICE=1
export TLS_SIG=2 

export PASS=1

export HELIUM_PORT=44158

declare -a USAGES=("Usage: ${0} --install-vpn true --client-name milesight-4 --host-id 104"
		"Usage: ${0} --add-client true --client-name milesight-4 --host-id 104"
		"Usage: ${0} --remove-client true --client-name milesight-4 --host-id 104"
		"Usage: ${0} --remove-vpn true")


while [ $# -gt 0 ]; do
	if [[ $1 == *"--"* ]]; then
    	param="${1/--/}"
		param="${param/-/_}"
		declare $param="$2"
	fi
	shift
done

function runScript() {
	echo ">>> Running the openvpn-install script:"
	wget https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh -O openvpn-install.sh && bash openvpn-install.sh
}

function removeIpTableLine() {
	echo ">>> Removing the client from iptables"
	iptables -t nat -D PREROUTING -i eth0 -p tcp -m tcp --dport ${HELIUM_PORT} -j DNAT --to-destination 10.8.0.${host_id}:${HELIUM_PORT}
}

function addIpTableLine() {
	echo ">>> Adding the client from iptables"
	iptables -t nat -I PREROUTING -i eth0 -p tcp -m tcp --dport ${HELIUM_PORT} -j DNAT --to-destination 10.8.0.${host_id}:${HELIUM_PORT}
}

function addStaticIp() {
	echo ">>> Adding the client static ip"
	echo "ifconfig-push 10.8.0.${host_id} 255.255.255.0" > /etc/openvpn/ccd/${client_name}
}

function removeStaticIp() {
	echo ">>> Removing the client static ip"
	rm -f /etc/openvpn/ccd/${client_name}
}

function removeRemainingVpnFiles() {
	echo ">>> Removing the remaining vpn files/configurations"
	rm -rf /etc/openvpn
	rm -rf /var/log/openvpn
}

function splitVpnClientConfig() {
	echo ">>> Splitting the openvpn config file"
	DEST_FOLDER="/home/ubuntu/vpn-clients/${client_name}"
	VPN_FILE="/home/ubuntu/${client_name}.ovpn"
	UPDATED_VPN_FILE="${DEST_FOLDER}/client.ovpn"
	mkdir -p $DEST_FOLDER
	cp $VPN_FILE $UPDATED_VPN_FILE

	if grep -q "<ca>" "$VPN_FILE"; then
		sed '1,/<ca>/d;/<\/ca>/,$d' $VPN_FILE > "${DEST_FOLDER}/ca.crt"
		sed -i "/<ca>/,/<\/ca>/c\ca ${DEST_FOLDER}/ca.crt" ${UPDATED_VPN_FILE}
	fi
	if grep -q "<cert>" "$VPN_FILE"; then
		sed '1,/<cert>/d;/<\/cert>/,$d' $VPN_FILE > "${DEST_FOLDER}/client.crt"
		sed -i "/<cert>/,/<\/cert>/c\cert ${DEST_FOLDER}/client.crt" ${UPDATED_VPN_FILE}
	fi
	if grep -q "<key>" "$VPN_FILE"; then
		sed '1,/<key>/d;/<\/key>/,$d' $VPN_FILE > "${DEST_FOLDER}/client.key"
		sed -i "/<key>/,/<\/key>/c\key ${DEST_FOLDER}/client.key" ${UPDATED_VPN_FILE}
	fi
	if grep -q "<tls-auth>" "$VPN_FILE"; then
		sed '1,/<tls-auth>/d;/<\/tls-auth>/,$d' $VPN_FILE > "${DEST_FOLDER}/ta.key"
		sed -i "/<tls-auth>/,/<\/tls-auth>/c\tls-auth ${DEST_FOLDER}/ta.key" ${UPDATED_VPN_FILE}
	fi
	cat $UPDATED_VPN_FILE
}

if [[ $install_vpn != "" ]]; then
	if [[ $client_name != "" ]] && [[ $host_id != "" ]]; then
		echo "install-vpn:${install_vpn} client-name:${client_name} host-id:${host_id}"
		export CLIENT=${client_name}
		export APPROVE_INSTALL=y
		runScript
		addStaticIp
		addIpTableLine
	else
		echo $USAGES[0]
	fi
elif [[ $add_client == "true" ]]; then
	echo "add-client:${add_client}"
	if [[ $client_name != "" ]] && [[ $host_id != "" ]]; then
		echo "add-client:${add_client} client-name:${client_name} host-id:${host_id}"
		export MENU_OPTION=1
		export CLIENT=${client_name}
		runScript
		addStaticIp
		addIpTableLine
		splitVpnClientConfig
	else
		echo $USAGES[1]
	fi
elif [[ $remove_client == "true" ]]; then
	echo "remove-client:${remove_client}"
	if [[ $client_name != "" ]] && [[ $host_id != "" ]]; then
		export MENU_OPTION=2
		export CLIENTNUMBER=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | grep -n $client_name | cut -d ':' -f 1)
		runScript
		removeIpTableLine
		removeStaticIp
	else
		echo $USAGES[2]
	fi
elif [[ $remove_vpn == "true" ]]; then
	echo "remove-vpn:${remove_vpn}"
	export MENU_OPTION=3
	runScript
else
	for str in "${USAGES[@]}"; do
  		echo "$str"
	done
	echo
	echo ">>> Listing iptables lines:"
	iptables -t nat -v -L PREROUTING -n --line-number
fi


# export APPROVE_INSTALL=y
# export APPROVE_IP=y
# export ENDPOINT=$(curl -4 ifconfig.co)
# export IPV6_SUPPORT=n
# export PORT_CHOICE=1
# export PROTOCOL_CHOICE=1
# export DNS=9
# export COMPRESSION_ENABLED=n

# export CUSTOMIZE_ENC=y
# export CIPHER_CHOICE=4
# export CERT_TYPE=2
# export RSA_KEY_SIZE_CHOICE=1
# export CC_CIPHER_CHOICE=1
# export DH_TYPE=1
# export DH_CURVE_CHOICE=1
# export HMAC_ALG_CHOICE=1
# export TLS_SIG=2 


# export CLIENT=clientname
# export HOST_ID=103
# export HELIUM_PORT=44158
# export PASS=1

# wget https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh -O openvpn-install.sh && bash openvpn-install.sh

# echo "ifconfig-push 10.8.0.${HOST_ID} 255.255.255.0" > /etc/openvpn/ccd/${CLIENT}

# add 
# iptables -t nat -I PREROUTING -i eth0 -p tcp -m tcp --dport ${HELIUM_PORT} -j DNAT --to-destination 10.8.0.${HOST_ID}:${HELIUM_PORT}
# delete
# iptables -t nat -D PREROUTING -i eth0 -p tcp -m tcp --dport ${HELIUM_PORT} -j DNAT --to-destination 10.8.0.${HOST_ID}:${HELIUM_PORT}
# list
# iptables -t nat -v -L PREROUTING -n --line-number