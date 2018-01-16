######## Manual Tasks on the host ######
# Please execute the following two lines on the host BIG-IP,
# on which you plan to start this script from the BIG-IQ
#
# Enable bash script for admin on both bigips, additional change password of admin for UDF:
# (tmos) # modify auth user admin password admin shell bash
#
# UDF specific: Disabeling hostname update over UDF
# (tmos) # modify sys management-dhcp sys-mgmt-dhcp-config request-options delete { domain-name domain-name-servers ntp-servers host-name }
# (tmos) # modify sys global-settings hostname bigip1
# (tmos) # save sys config partitions all
# > full_box_reboot
#
# Authorize admin on host to access peer without password (Please replace <<peer_mgmt_ip>>):
# > ssh-copy-id -i /root/.ssh/identity.pub admin@<<peer_mgmt_ip>>


######## VARS ##########################
HOST_MGMT_IP="10.1.1.14"
PEER_MGMT_IP="10.1.1.15"

ADMIN_PASSWD="admin"

# System
HOSTNAME_a="dmzlb1.f5demo.com"
HOSTNAME_b="dmzlb2.f5demo.com"
DEVICE_GROUP_NAME="dmzlb_cluster"
# DNS
DNS_SERVER="9.9.9.9 8.8.8.8"
DNS_SEARCH="localhost f5demo.com"
# NTP
NTP_SERVER="0.de.pool.ntp.org 1.de.pool.ntp.org"
NTP_TIMEZONE="Europe/Berlin"
# GUI
IDLE_TIMEOUT="9000"

# Network
EXT_VLAN_INTERFACE="1.1"
EXT_SELF_IP_MASK="24"
EXT_SELF_IP="10.1.10.20"
EXT_SELF_IP_a="10.1.10.21"
EXT_SELF_IP_b="10.1.10.22"

HA_VLAN_INTERFACE="1.2"
HA_SELF_IP_MASK="24"
HA_SELF_IP_a="10.1.20.21"
HA_SELF_IP_b="10.1.20.22"

#######################################

# System
tmsh modify /sys global-settings hostname $HOSTNAME_a
ssh admin@$PEER_MGMT_IP tmsh modify /sys global-settings hostname $HOSTNAME_b

tmsh modify /sys db ui.system.preferences.recordsperscreen value 100
ssh admin@$PEER_MGMT_IP tmsh modify /sys db ui.system.preferences.recordsperscreen value 100
tmsh modify sys httpd auth-pam-idle-timeout $IDLE_TIMEOUT
ssh admin@$PEER_MGMT_IP tmsh modify sys httpd auth-pam-idle-timeout $IDLE_TIMEOUT
tmsh modify /sys db ui.system.preferences.startscreen value network_map
ssh admin@$PEER_MGMT_IP tmsh modify /sys db ui.system.preferences.startscreen value network_map

tmsh modify /sys global-settings gui-setup disabled
ssh admin@$PEER_MGMT_IP tmsh modify /sys global-settings gui-setup disabled

# DNS
tmsh modify /sys dns name-servers add { $DNS_SERVER } search add { $DNS_SEARCH }
ssh admin@$PEER_MGMT_IP tmsh modify /sys dns name-servers add { $DNS_SERVER } search add { $DNS_SEARCH }
# NTP
tmsh modify /sys ntp servers add { $NTP_SERVER } timezone $NTP_TIMEZONE
ssh admin@$PEER_MGMT_IP tmsh modify /sys ntp servers add { $NTP_SERVER } timezone $NTP_TIMEZONE

# Network
tmsh create /net vlan external interfaces add { $EXT_VLAN_INTERFACE { untagged } }  tag 20
tmsh create /net self ext_self address $EXT_SELF_IP_a/$EXT_SELF_IP_MASK vlan external
tmsh create /net self ext_floating_self address $EXT_SELF_IP/$EXT_SELF_IP_MASK vlan external traffic-group traffic-group-1
ssh admin@$PEER_MGMT_IP tmsh create /net vlan external interfaces add { $EXT_VLAN_INTERFACE { untagged } }  tag 20
ssh admin@$PEER_MGMT_IP tmsh create /net self ext_self address $EXT_SELF_IP_b/$EXT_SELF_IP_MASK vlan external

tmsh create /net vlan ha interfaces add { $HA_VLAN_INTERFACE { untagged } }  tag 10
tmsh create /net self ha_self address $HA_SELF_IP_a/$HA_SELF_IP_MASK vlan ha allow-service default
ssh admin@$PEER_MGMT_IP tmsh create /net vlan ha interfaces add { $HA_VLAN_INTERFACE { untagged } }  tag 10
ssh admin@$PEER_MGMT_IP tmsh create /net self ha_self address $HA_SELF_IP_b/$HA_SELF_IP_MASK vlan ha allow-service default

######################
# HA Setup

# set device name
tmsh mv /cm device bigip1 $HOSTNAME_a
ssh admin@$PEER_MGMT_IP tmsh mv /cm device bigip1 $HOSTNAME_b
# set configsync ip
tmsh modify cm device $HOSTNAME_a configsync-ip $EXT_SELF_IP_a
ssh admin@$PEER_MGMT_IP tmsh modify cm device $HOSTNAME_b configsync-ip $EXT_SELF_IP_b
# set heartbeat ip
tmsh modify /cm device $HOSTNAME_a unicast-address { { ip $HA_SELF_IP_a } { ip $HOST_MGMT_IP } }
ssh admin@$PEER_MGMT_IP tmsh modify /cm device $HOSTNAME_b unicast-address { { ip $HA_SELF_IP_b } { ip $PEER_MGMT_IP } }
# set mirroring ip
tmsh modify cm device $HOSTNAME_a mirror-ip $EXT_SELF_IP_a
ssh admin@$PEER_MGMT_IP tmsh modify cm device $HOSTNAME_b mirror-ip $EXT_SELF_IP_b
# setup trust
tmsh modify cm trust-domain Root ca-devices add { $PEER_MGMT_IP } name $HOSTNAME_b username admin password $ADMIN_PASSWD
# Create Device Group
tmsh create cm device-group $DEVICE_GROUP_NAME  devices add { $HOSTNAME_a $HOSTNAME_b } type sync-failover network-failover enabled
# Wait until ready to sync
echo "Wait until ready to sync:"
for i in {0..60..2}
do
  value=$( tmsh show cm sync-status | grep Color | grep -ic blue )
  echo "Wait $i seconds"
  if [ $value -eq 1 ]
  then
    echo " - Ready for Sync - "
    break
  else
    if [ $i -eq 60 ]
    then
      echo " - Not ready to sync - Exit - "
      exit
    fi
    sleep 2
  fi
done
# Initial Sync
tmsh run cm config-sync force-full-load-push to-group $DEVICE_GROUP_NAME
# Wait until sync is finished
echo "Wait until sync is finished:"
for i in {0..60..2}
do
  value=$( tmsh show cm sync-status | grep Color | grep -ic green )
  echo "Wait $i seconds"
  if [ $value -eq 1 ]
  then
    echo " - Sync is done - "
    break
  else
    if [ $i -eq 60 ]
    then
      echo " - Sync Failed - "
    fi
    sleep 2
  fi
done

# Show Sync status
tmsh show cm sync-status
ssh admin@$PEER_MGMT_IP tmsh show cm sync-status

# save changes
tmsh save /sys config
ssh admin@$PEER_MGMT_IP tmsh save /sys config
