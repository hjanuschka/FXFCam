#!/bin/sh

#reset USB ports
# only works on linux
una=$(uname)

while ( true ); 
do 
	if [ "$una" = "Linux" ]
	then
        	lsusb |grep Canon|awk  '{split($6,dev, ":"); print "usb_modeswitch -v 0x"dev[1]" -p 0x"dev[2]" --reset-usb" }'|bash
	fi
	bundle exec ruby server.rb ;
	sleep 2;
done

