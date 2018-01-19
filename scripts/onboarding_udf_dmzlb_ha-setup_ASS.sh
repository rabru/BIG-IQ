# HA Setup for an active/standby/standby deployment
#
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

######## VARS ##########################
PEER1_MGMT_IP="10.1.1.15"
PEER2_MGMT_IP="10.1.1.16"

ADMIN_PASSWD="admin"

# System
HOSTNAME="dmzlb1.f5demo.com"
HOSTNAME_PEER1="dmzlb2.f5demo.com"
HOSTNAME_PEER2="dmzlb3.f5demo.com"
DEVICE_GROUP_NAME="dmzlb_cluster"
# DNS


# Network
EXT_SELF_IP_MASK="24"
EXT_SELF_IP="10.1.10.20"

#######################################
# Network
tmsh create /net self ext_floating_self address $EXT_SELF_IP/$EXT_SELF_IP_MASK vlan external traffic-group traffic-group-1

######################
# HA Setup

# setup trust
tmsh modify cm trust-domain Root ca-devices add { $PEER1_MGMT_IP } name $HOSTNAME_PEER1 username admin password $ADMIN_PASSWD
tmsh modify cm trust-domain Root ca-devices add { $PEER2_MGMT_IP } name $HOSTNAME_PEER2 username admin password $ADMIN_PASSWD
# Create Device Group
tmsh create cm device-group $DEVICE_GROUP_NAME  devices add { $HOSTNAME $HOSTNAME_PEER1 $HOSTNAME_PEER2 } type sync-failover network-failover enabled
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

# save changes
tmsh save /sys config
