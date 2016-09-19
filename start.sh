#!/bin/sh

#reset USB ports
# only works on linux
una=$(uname)

while ( true ); 
do 
	bundle exec ruby server.rb ;
	sleep 2;
done

