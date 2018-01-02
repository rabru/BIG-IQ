######## Manual Tasks on the host ######
# Please execute the following two lines on the host BIG-IP,
# on which you plan to start this script from the BIG-IQ
#
# Authorize root on host to access peer without password (Please replace <<host_mgmt_ip>>):
# ssh-copy-id -i /root/.ssh/identity.pub root@<<host_mgmt_ip>>
#
# Enable bash script for admin:
# tmsh modify /auth user admin bash

######## VARS ##########################
PEER_MGMT_IP="10.1.1.12"

# System
HOSTNAME_a="bigip_a.f5demo.com"
HOSTNAME_b="bigip_b.f5demo.com"

# Network
EXT_VLAN_INTERFACE="1.1"
EXT_SELF_IP="10.1.10.20/24"
EXT_SELF_IP_a="10.1.10.21/24"
EXT_SELF_IP_b="10.1.10.22/24"

INT_VLAN_INTERFACE="1.2"
INT_SELF_IP="10.1.20.20/24"
INT_SELF_IP_a="10.1.20.21/24"
INT_SELF_IP_b="10.1.20.22/24"

HA_VLAN_INTERFACE="1.3"
HA_SELF_IP_a="10.1.30.21/24"
HA_SELF_IP_b="10.1.30.22/24"

#######################################

# System
tmsh modify /sys global-settings hostname $HOSTNAME_a
ssh root@$PEER_MGMT_IP 'tmsh modify /sys global-settings hostname $HOSTNAME_b'

tmsh modify /sys db ui.system.preferences.recordsperscreen value 100
tmsh modify /sys global-settings gui-setup disabled

# Network
tmsh create /net vlan external interfaces add { $EXT_VLAN_INTERFACE { untagged } }  tag 10
tmsh create /net self ext_self address $EXT_SELF_IP vlan external

tmsh create /net vlan internal interfaces add { $INT_VLAN_INTERFACE { untagged } }  tag 20
tmsh create /net self int_self address $INT_SELF_IP vlan internal

tmsh create /net vlan ha interfaces add { $HA_VLAN_INTERFACE { untagged } }  tag 30
tmsh create /net self ha_self address $HA_SELF_IP vlan ha

# save changes
tmsh save /sys config
