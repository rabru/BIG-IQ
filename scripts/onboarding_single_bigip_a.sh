######## VARS ##########################

# System
HOSTNAME="bigip_one_a.f5demo.com"


# Network
INT_VLAN_INTERFACE="1.1"
INT_SELF_IP="10.1.10.21/24"
EXT_VLAN_INTERFACE="1.2"
EXT_SELF_IP="10.1.20.21/24"

#######################################
# System
tmsh modify /sys global-settings hostname $HOSTNAME

# Network
tmsh create /net vlan internal interfaces add { $INT_VLAN_INTERFACE { untagged } }  tag 10
tmsh create /net self int_self address $INT_SELF_IP vlan internal
tmsh create /net vlan external interfaces add { $EXT_VLAN_INTERFACE { untagged } }  tag 20
tmsh create /net self ext_self address $EXT_SELF_IP vlan external

# save changes
tmsh save /sys config
