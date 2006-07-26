#!/bin/sh
#
# /etc/rc.d/rc.S:  System initialization script.
#
# Mostly written by:  Patrick J. Volkerding, <volkerdi@ftp.cdrom.com>
#


umask 022
export PATH=/sbin:/bin:/usr/sbin:/usr/bin

# enable swapping
/sbin/swapon -a

# initialize LCD
if [ ! -x /bin/lcdwrite ] ; then alias lcdwrite=/bin/true ; fi 
if [ ! -x /bin/lcdtee ] ; then alias lcdtee=/bin/cat ; fi 
echo | lcdwrite 

if [ ! -e /proc/mounts ] ; then
  # mounting /proc device
  mount -vnt proc /proc /proc
fi

# be careful, we suppose that /dev was created by preinit program
# to be read-write

if [ ! -d /dev/pts -a -w /dev/ ] ; then 
  # create /dev/pts
  mkdir /dev/pts
fi

# Création du /dev/root s'il n'existe pas
if [ ! -e /dev/root ] ; then
  if grep -q " root=" /proc/cmdline ; then
    set `sed -e "s/^.* root=\([^ ]\+\).*/\1/" < /proc/cmdline`
    ln -s $1 /dev/root
  fi
fi

# Check the integrity of / filesystem except if it's a ramdisk
# major=`ls -l /dev/root|sed -e 's/^\(.*\)\([0-9]\+\)\(, .*\)$/\2/'`
# if [ "$major" != "1" ]; then
#	/sbin/e2fsck -n /dev/root
# fi

# Création du /dev/boot s'il n'existe pas
if [ ! -e /dev/boot ] ; then
  if grep -q " boot=" /proc/cmdline ; then
    set `sed -e "s/^.* boot=\([^ ]\+\).*/\1/" < /proc/cmdline`
    ln -s $1 /dev/boot
  elif grep -q '[ 	]/boot[ 	]' /etc/fstab ; then
    set `grep '[ 	]/boot[ 	]' /etc/fstab`
    ln -s $1 /dev/boot
  fi
fi

# Check the integrity of all filesystems
/sbin/fsck -a -A -C -R

if [ $? -gt 1 ] ; then
  echo "Error with fsck, run 'fsck -y -a'"
  PS1="(Repair filesystem) \#"; export PS1
  sulogin
  echo "Unmounting file systems..."
  umount -a
  mount -n -o remount,ro /
  sync
  echo "Rebooting system..."
  sleep 2
  reboot
  /bin/sh
fi

# mount file systems in fstab (and create an entry for /)
# but not NFS because TCP/IP is not yet configured
mount -nat nonfs,noproc

if [ ! -w /var ] ; then
  echo "Mounting /var as tmpfs"
  umount /var >/dev/null 2>&1
  mount -o mode=755 -t tmpfs /var /var
fi

# Creat /var directories if they don't exist
if [ ! -d /var/tmp ] ; then mkdir -m 1777 /var/tmp ; fi
if [ ! -d /var/run ] ; then mkdir /var/run ; fi
if [ ! -d /var/lib ] ; then mkdir /var/lib ; fi
if [ ! -d /var/spool ] ; then mkdir /var/spool ; fi
if [ ! -d /var/log ] ; then mkdir /var/log ; fi
if [ ! -d /var/cache ] ; then mkdir /var/cache ; fi
if [ ! -d /var/empty ] ; then mkdir /var/empty ; fi
if [ ! -d /var/adm/. ] ; then ln -s log /var/adm ; fi

sync

if [ ! -w /tmp ] ; then
  echo "Mounting /tmp as tmpfs"
  umount /tmp >/dev/null 2>&1
  mount -o mode=1777 -t tmpfs /tmp /tmp
fi

/bin/rm -rf /tmp/* /tmp/.[^.]* /tmp/..?*
touch /var/log/wtmp /var/log/lastlog

if mkdir /tmp/.$BOOTID ; then 
  dmesg > /tmp/.$BOOTID/dmesg
fi

# Clean up temporary files on the /var volume:
/bin/rm -f /var/run/utmp /var/run/*.pid

# Looks like we have to create this.
cat /dev/null > /var/run/utmp

# Writing Status
for dir in / /dev /tmp /var /etc /boot ; do
  s=""
  if [ -L $dir ] ; then s=$s"a symbolic-link " ; t=L ; fi
  if [ -w $dir ] ; then s=$s"read-write "; t=RW ; else 
                        s=$s"read-only " ; t=RO ; fi
  echo "$dir is $s"
done

echo "Base system done." | lcdtee

