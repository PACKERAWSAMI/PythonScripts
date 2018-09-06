i#!/bin/bash
set -e

echo 'HTTPS_PROXY=' >> /etc/environment
echo 'HTTP_PROXY=' >> /etc/environment
echo 'http_proxy=' >> /etc/environment
echo 'https_proxy=' >> /etc/environment
echo 'NO_PROXY=169.254.169.254,s3.amazonaws.com' >> /etc/environment
echo 'no_proxy=169.254.169.254,s3.amazonaws.com' >> /etc/environment

source /etc/environment
touch /var/log/consul-server-cluster-join.log

SERVER_COUNT=5

JOIN_ADDRS=$(aws ec2 describe-instances  --region=us-east-1 --filters  "Name=tag:Name,Values=Consul"  --query "Reservations[*].Instances[*].PrivateIpAddress" | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
BIND=`ip -4 addr show eth0 | grep -oP "(?<=inet ).*(?=/)"`
mkdir -p /mnt/consul/


cat >> /tmp/consul.service << 'EOF'
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target


[Service]
User=root
Group=root
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -server -data-dir=/mnt/consul/ -client=0.0.0.0 -ui -config-dir=/etc/consul.d/ >> /var/log/consul-server-service.log 2>&1
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT


[Install]
WantedBy=multi-user.target
EOF


cat >> /tmp/config.json << 'FE1'
	{
	  "bootstrap_expect": bse,
	  "bind_addr": "biad",
	  "datacenter": "us-east-1",
	  "encrypt": "dhgtdbeftbaGFHSV==",
	"log_level": "INFO",
	"enable_syslog": true,
    "client_addr": "0.0.0.0",
    "disable_remote_exec": true,
  "leave_on_terminate": true,
  "rejoin_after_leave": true,
	"retry_interval": "10s",
"retry_join_ec2": {
       "tag_key": "Name",
       "tag_value": "Consul"
     },
"ports" : {
"dns": 8600,
	"http": 8500,
	"rpc": 8400,
	"serf_lan": 8301,
	"serf_wan": 8302,
	"server": 8300

}
	}
FE1


echo "Create Consul  directories..."
	mkdir -p /etc/consul.d
	mkdir -p /mnt/consul

echo "get Consul..."
	cd /tmp
	curl -O -k  <url>consul-0.0.9.zip
	echo "Install Consul..."
	unzip consul-0.0.9.zip >/dev/null
	chmod +x consul
	chown root:root consul
	mv consul /usr/local/bin/consul



echo "Update the Consul configiguration"
	sed -i -- "s/bse/${SERVER_COUNT}/g" /tmp/config.json
	sed -i -- "s/biad/${BIND}/g" /tmp/config.json

mv /tmp/config.json /etc/consul.d
	chown root:root /etc/consul.d/config.json
	chmod 0644 /etc/consul.d/config.json



	mv /tmp/consul.service /lib/systemd/system
	chown root:root /lib/systemd/system/consul.service
	chmod 0644 /lib/systemd/system/consul.service


systemctl enable consul.service
service consul start
systemctl status consul.service
journalctl -xn


cp /tmp/join-cluster.sh /usr/bin
chown root:root /usr/bin/join-cluster.sh
chmod 0755 /usr/bin/join-cluster.sh

cp  /tmp/join-cluster.service /lib/systemd/system
chown root:root /lib/systemd/system/join-cluster.service
chmod 0644 /lib/systemd/system/join-cluster.service
#Install the systemd.timer file
cp /tmp/join-cluster.timer /lib/systemd/system
chown root:root /lib/systemd/system/join-cluster.timer
chmod 0644 /lib/systemd/system/join-cluster.timer


systemctl start join-cluster.timer
systemctl enable join-cluster.timer

#creating symbolic link for messages
ln -s /var/log/messages ${LOG_DIR}/messages




set +e
	COUNTER=0
	while [ ${COUNTER} -lt 20 ]
	do
	   for ADDR in $(echo ${JOIN_ADDRS})
	   do
	        LOCAL=$(echo "${BIND}" | tr -d '"')
	        OTHER=$(echo "${ADDR}" | tr -d '"')


	        if [[ "${LOCAL}" != "${OTHER}" ]]
	        then
	                echo "Trying to join ${LOCAL} to consul server ${OTHER}..."
	                /usr/local/bin/consul join "${OTHER}" >> /var/log/consul-server-cluster-join.log 2>&1
	                RC=$?
	                if [ ${RC} -eq 0 ]
	                then
	                        echo "Successfully joined ${LOCAL} to consul server ${OTHER}..."
	                        break 2
	                fi


	                echo "Failed to join ${LOCAL} to consul server ${OTHER}..."
	        fi
	   done


	   let COUNTER=COUNTER+1
	   sleep 5
	done

