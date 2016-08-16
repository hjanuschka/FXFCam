#!/bin/sh

#reset USB ports
# only works on linux
una=$(uname)

while ( true ); 
do 
	if [ "$una" = "Linux" ]
	then
        	for i in  $(ls /sys/bus/pci/drivers/ehci-pci/|grep :); do echo $i > /sys/bus/pci/drivers/ehci-pci/unbind; echo $i > /sys/bus/pci/drivers/ehci-pci/bind; done
	fi
	bundle exec ruby server.rb ;
	sleep 2;
done

