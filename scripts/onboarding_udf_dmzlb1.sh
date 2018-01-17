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
MGMT_IP="10.1.1.14"

# System
HOSTNAME="dmzlb1.f5demo.com"

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
EXT_SELF_IP="10.1.10.21"

HA_VLAN_INTERFACE="1.2"
HA_SELF_IP_MASK="24"
HA_SELF_IP="10.1.20.21"

#######################################

# System
tmsh modify /sys global-settings hostname $HOSTNAME

tmsh modify /sys db ui.system.preferences.recordsperscreen value 100
tmsh modify sys httpd auth-pam-idle-timeout $IDLE_TIMEOUT
tmsh modify /sys db ui.system.preferences.startscreen value network_map

tmsh modify /sys global-settings gui-setup disabled

# DNS
tmsh modify /sys dns name-servers add { $DNS_SERVER } search add { $DNS_SEARCH }
# NTP
tmsh modify /sys ntp servers add { $NTP_SERVER } timezone $NTP_TIMEZONE

# Network
tmsh create /net vlan external interfaces add { $EXT_VLAN_INTERFACE { untagged } }  tag 20
tmsh create /net self ext_self address $EXT_SELF_IP/$EXT_SELF_IP_MASK vlan external

tmsh create /net vlan ha interfaces add { $HA_VLAN_INTERFACE { untagged } }  tag 10
tmsh create /net self ha_self address $HA_SELF_IP/$HA_SELF_IP_MASK vlan ha allow-service default

######################
# HA Setup preparation

# set device name
tmsh mv /cm device bigip1 $HOSTNAME
# set configsync ip
tmsh modify cm device $HOSTNAME configsync-ip $EXT_SELF_IP
# set heartbeat ip
tmsh modify /cm device $HOSTNAME unicast-address { { ip $HA_SELF_IP } { ip $MGMT_IP } }
# set mirroring ip
tmsh modify cm device $HOSTNAME mirror-ip $EXT_SELF_IP
