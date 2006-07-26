#! /bin/sh
#
# rc.K 		This file is executed by init when it goes into runlevel
#		1, which is the administrative state. It kills all
#		deamons and then puts the system into single user mode.
#		Note that the file systems are kept mounted.
#
# Version:	@(#)/etc/rc.d/rc.K	1.50	1994-01-18
# Version:	@(#)/etc/rc.d/rc.K	1.60	1995-10-02 (PV)
#
# Author:	Miquel van Smoorenburg <miquels@drinkel.nl.mugnet.org>
# Modified by:  Patrick J. Volkerding <volkerdi@ftp.cdrom.com>
# Modified by:  Benoit Dolez <bdolez@meta-x.org>
#

function loop {
	echo 
	for i in 0 1 2 3 4 5 ; do echo -n . ; done
	echo
}

# Set the path.
PATH=/sbin:/etc:/bin:/usr/bin

# If there are SystemV init scripts for this runlevel, run them.
if [ -x /sbin/init.d/sysvinit ]; then
	/sbin/init.d/sysvinit start
fi

# Kill all processes.
killall5 -1
loop 
killall5 -15
loop 
killall5 -9
loop 

# Now go to the single user level
echo "Going to single user mode..."
telinit -t 1 1

