#!/bin/bash

# The script used to generate provisioning server based on CentOS 7.3 for 
# creating private cloud or managing private owned network and server hardware.

# Maintaner: Adrian Zhang, adrian@favap.com
# version 1.0

# check if the IP is legal
function check_ip() {
    local IP=$PRO_IP
    VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
         echo "IP $IP  available!"
            return 0
        else
            echo "IP $IP is illegal!"
            return 1
        fi
    else
        echo "IP format error!"
        return 1
    fi
}

# Initial Provisioning server IP
while true; do
    read -p "Please enter provisioning server IP: " PRO_IP
    check_ip $PRO_IP
    [ $? -eq 0 ] && break
done


ISO_FOLDER="/opt/isos"
CentOS_ISO="CentOS-7-x86_64-DVD-1611.iso"
CentOS_ISO_LINK=http://mirrors.163.com/centos/7.3.1611/isos/x86_64/$CentOS_ISO

TFTP_CONFIG="/etc/xinetd.d/tftp"

# Install necessary 
/usr/bin/yum install -y httpd tftp-server dhcp syslinux xinetd

# Prepare ISO, it can be changed to other Linux distribution
if [ ! -d $ISO_FOLDER ]; then
    /usr/bin/mkdir -p $ISO_FOLDER
cd $ISO_FOLDER

if [ ! -f $CentOS_ISO ]; then
    #wget CentOS ISO or other ISO
    wget $CentOS_ISO_LINK &


# Config TFTP Service
sed -i '/disable/c disable = no' $TFTP_CONFIG
# Start TFTP service
/etc/init.d/xinetd restart

# Config HTTP service
sed -i "277i ServerName 127.0.0.1:80" /etc/httpd/conf/httpd.conf
# Prepare web repo
/usr/bin/mkdir -p /var/www/html/iso
mount -t iso9660 -o loop $ISO_FOLDER/$CentOS_ISO /var/www/html/iso
# Start HTTP service
systemctl restart httpd

# Prepare PXE environment
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp -a /var/www/html/iso/isolinux/* /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cp /var/www/html/iso/isolinux/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default
# Config PXE
cat /var/lib/tftpboot/pxelinux.cfg/default < EOF 
default ks
prompt 0
label ks
  kernel vmlinuz
  append initrd=initrd.img ks=http://$PRO_IP/pm.ks.cfg
EOF

# Generate kickstart file
cat /var/www/html/pm.ks.cfg < EOF

EOF

cat /var/www/html/vm.ks.cfg < EOF

EOF

# Config DHCP service
cat /etc/dhcp/dhcp.conf < EOF
subnet 10.0.0.0 netmask 255.255.255.0 {
        range 10.0.0.100 10.0.0.200;
        option subnet-mask 255.255.255.0;
        default-lease-time 21600;
        max-lease-time 43200;
        next-server $IP;
        filename "/pxelinux.0";
}
EOF
