######## Manual Tasks on the host ######
# Please execute the following two lines on the host BIG-IP,
# on which you plan to start this script from the BIG-IQ
#
# Enable bash script for admin on both bigips, additional change password of admin for UDF:
# (tmos) # modify auth user admin password admin shell bash
#
# UDF specific: Disabeling hostname update over UDF
# (tmos) # modify sys global-settings hostname bigip.local
# (tmos) # modify sys management-dhcp sys-mgmt-dhcp-config request-options delete { host-name }
# (tmos) # save sys config partitions all
#
# Authorize admin on host to access peer without password (Please replace <<peer_mgmt_ip>>):
# > ssh-copy-id -i /root/.ssh/identity.pub admin@<<peer_mgmt_ip>>


######## VARS ##########################
HOST_MGMT_IP="10.1.1.13"
PEER_MGMT_IP="10.1.1.14"

ADMIN_PASSWD="admin"

# System
HOSTNAME_a="rumpel.f5demo.com"
HOSTNAME_b="stilzchen.f5demo.com"
DEVICE_GROUP_NAME="bigip_cluster"
# DNS
DNS_SERVER="9.9.9.9 8.8.8.8"
DNS_SEARCH="localdomain f5demo.com"
# NTP
NTP_SERVER="0.de.pool.ntp.org 1.de.pool.ntp.org"
NTP_TIMEZONE="Europe/Berlin"

# Network
EXT_VLAN_INTERFACE="1.2"
EXT_SELF_IP_MASK="24"
EXT_SELF_IP="10.1.20.20"
EXT_SELF_IP_a="10.1.20.21"
EXT_SELF_IP_b="10.1.20.22"

HA_VLAN_INTERFACE="1.1"
HA_SELF_IP_MASK="24"
HA_SELF_IP_a="10.1.10.21"
HA_SELF_IP_b="10.1.10.22"

#######################################

# System
tmsh modify /sys global-settings hostname $HOSTNAME_a
ssh admin@$PEER_MGMT_IP tmsh modify /sys global-settings hostname $HOSTNAME_b

tmsh modify /sys db ui.system.preferences.recordsperscreen value 100
ssh admin@$PEER_MGMT_IP tmsh modify /sys db ui.system.preferences.recordsperscreen value 100

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
tmsh create /net self ha_self address $HA_SELF_IP_a/$HA_SELF_IP_MASK vlan ha
ssh admin@$PEER_MGMT_IP tmsh create /net vlan ha interfaces add { $HA_VLAN_INTERFACE { untagged } }  tag 10
ssh admin@$PEER_MGMT_IP tmsh create /net self ha_self address $HA_SELF_IP_b/$HA_SELF_IP_MASK vlan ha

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
# Initial Sync
tmsh run cm config-sync force-full-load-push to-group $DEVICE_GROUP_NAME
# wait until sync is finished
for i in {0..120..2}
do
  value=$( tmsh show cm sync-status | grep Color | grep -ic green )
  if [ $value -eq 1 ]
  then
    echo " - Sync is done - "
    break
  else
    echo "Wait $i seconds"
    if [ $i -eq 120 ]
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
