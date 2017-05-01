#!/bin/bash

PXELINUX_PATH="/var/lib/tftpboot/pxelinux.cfg/*"
EFI_PATH="/var/lib/tftpboot/pxelinux/"

# remove unrequired lines from dhcpd.leases
# supersede server.filename = "pxelinux.0";
if grep 'supersede server.filename = "pxelinux.0";' /var/lib/dhcpd/dhcpd.leases ; then
	rm -rf /var/lib/dhcpd/dhcpd.leases~
	sed "/supersede server.filename = \"pxelinux.0\"\;/d" < /var/lib/dhcpd/dhcpd.leases > /var/lib/dhcpd/dhcpd.leases.corrected
	mv /var/lib/dhcpd/dhcpd.leases.corrected /var/lib/dhcpd/dhcpd.leases
	wait
	systemctl restart dhcpd
fi

# copy boot images, replace if newer 
cp -u /var/lib/tftpboot/boot/RedHat* /var/lib/tftpboot/pxelinux

for pxelinuxcfg in $PXELINUX_PATH
do
	echo "Processing $pxelinuxcfg"
	MAC=$(basename $pxelinuxcfg)
	MAC_UPPERCASE=$(echo $MAC | awk '{print toupper($0)}')
	MAC_COLON_SHORT=$(echo $MAC | sed 's/-/:/g')
	INITRD_IMAGE=$(grep "initrd=boot/" $pxelinuxcfg | sed 's/APPEND initrd=boot\///g' | sed -r 's/(\.img).*/\1/' | tr -d '[:space:]')
	VMLINUZ_IMAGE=$(grep "KERNEL boot/" $pxelinuxcfg | sed 's/KERNEL boot\///g' | tr -d '[:space:]')
	KICKSTART_URL=$(grep "ks=" $pxelinuxcfg | sed 's/^.*http/http/' | cut -d " " -f1)
	
	# note that the UEFI interfaces have an extra set of digits in the mac
        # I.E 01-14-02-ec-6e-c9-f0 instead of 14-02-ec-6e-c9-f0, we fix this
	if [ $(echo $MAC_COMMAS_SHORT | tr -d -c ':' | awk '{ print length;}') = 6 ]; then
		MAC_COLON_SHORT=${MAC_COLON_SHORT:3}
		echo "Detected large mac address, shortening: $MAC_COMMAS_SHORT"
	fi
	
	# write tftp boot file in old format 
	echo "Creating EFI Boot File: $EFI_PATH$MAC_UPPERCASE"	
	# Create new efi boot file
	echo """default=0
			timeout=5
			title 'Boot $MAC_UPPERCASE'
				root (nd)
				kernel /$VMLINUZ_IMAGE ks=$KICKSTART_URL ksdevice=$MAC_COMMAS_SHORT kssendmac text
				initrd /$INITRD_IMAGE
		 """ > $EFI_PATH$MAC_UPPERCASE
		
	# Todo: put host out of build mode once built 
	# Todo: capsule host override with ip (if DNS has issues during boot) for DMZ hosts.  
done