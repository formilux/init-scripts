#!/bin/sh

umask 022
export PATH=/sbin:/bin:/usr/sbin:/usr/bin

# enable swapping
/sbin/swapon -a

# initialize LCD if present
if [ ! -x /bin/lcdwrite ] ; then function lcdwrite { /bin/true; } ; fi
if [ ! -x /bin/lcdtee ] ; then function lcdtee { /bin/cat; } ; fi
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

# Create /dev/root if it doesn't exist
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

# Create /dev/boot if it doesn't exist
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
  #echo "Error with fsck, run 'fsck -y -a'"
  #PS1="(Repair filesystem) \#"; export PS1
  #sulogin
  #echo "Unmounting file systems..."
  #umount -a
  #mount -n -o remount,ro /
  #sync
  #echo "Rebooting system..."
  #sleep 2
  #reboot
  #/bin/sh
  echo "Error with fsck, run 'fsck -y -a'."
  echo "  => remounting ALL filesystems READ-ONLY !!!"
  # mount file systems in fstab (and create an entry for /)
  # but not NFS because TCP/IP is not yet configured
  mount -rnat nonfs,noproc,notmpfs
  mount -nat tmpfs
else
  # mount file systems in fstab (and create an entry for /)
  # but not NFS because TCP/IP is not yet configured
  mount -nat nonfs,noproc
fi


# check whether /var is already mounted read-write. If not, we'll do
# it because it's unacceptable to work in read-only mode !
if touch /var/.$BOOTID >/dev/null 2>&1; then
    rm -f /var/.$BOOTID >/dev/null 2>&1
else
    echo "WARNING: Mounting /var as tmpfs !"
    umount /var >/dev/null 2>&1
    mount -o mode=755 -t tmpfs /var /var
fi

# Create /var directories if they don't exist
if [ ! -d /var/tmp ] ; then mkdir -m 1777 /var/tmp ; fi
if [ ! -d /var/run ] ; then mkdir /var/run ; fi
if [ ! -d /var/state ] ; then mkdir /var/state ; fi
if [ ! -d /var/lib ] ; then mkdir /var/lib ; fi
if [ ! -d /var/spool ] ; then mkdir /var/spool ; fi
if [ ! -d /var/log ] ; then mkdir /var/log ; chown root:log /var/log; chmod 2750 /var/log; fi
if [ ! -d /var/cache ] ; then mkdir /var/cache ; fi
if [ ! -d /var/empty ] ; then mkdir /var/empty ; chmod 500 /var/empty; fi
if [ ! -d /var/adm/. ] ; then ln -s log /var/adm ; fi

sync

# check whether /tmp is already mounted read-write. If not, we'll do
# it because it's unacceptable to work in read-only mode !
if touch /tmp/.$BOOTID >/dev/null 2>&1; then
    rm -f /tmp/.$BOOTID >/dev/null 2>&1
else
    echo "Mounting /tmp as tmpfs"
    umount /tmp >/dev/null 2>&1
    mount -o mode=1777,nosuid,nodev -t tmpfs /tmp /tmp
    if [ $? != 0 ]; then
       echo "WARNING: could not mount /tmp as tmpfs."
       if [ -L /tmp ]; then
          echo "  /tmp is a symlink to nowhere. Trying to fix its destination :"
          (cd / && mkdir -vp `readlink /tmp`)
          if [ $? -eq 0 ]; then
	     echo "    => Success ! Now trying to mount /tmp again :"
          else
             echo "    => Failed ! Trying to make /tmp a directory :"
             (mv -v /tmp /tmp.old || rm -vf /tmp) && mkdir -v /tmp
             if [ $? -eq 0 ]; then
	         echo "    => Success ! Now trying to mount /tmp again :"
             else
                 echo "    => Failed ! Trying again by remounting / RW :"
                 mount -vwo remount / && (mv -v /tmp /tmp.old || rm -vf /tmp) && mkdir -v /tmp
		 mount -vo remount /
		 if [ ! -d /tmp ]; then
		    echo "    => Failed ! The system may be unstable !!!"
                 else
                    echo "    => Success ! you were lucky, but check if / has been correctly remounted !"
		    echo "    => Now trying to mount /tmp again :"
                 fi
             fi
          fi
       elif [ ! -d /tmp ]; then
          echo "  Trying to make /tmp a directory :"
          (mv -v /tmp /tmp.old || rm -vf /tmp) && mkdir -v /tmp
          if [ $? -eq 0 ]; then
             echo "    => Success ! Now trying to mount /tmp again :"
          else
             echo "    => Failed ! Trying again by remounting / RW :"
             mount -vwo remount / && (mv -v /tmp /tmp.old || rm -vf /tmp) && mkdir -v /tmp
	     mount -vo remount /
             if [ ! -d /tmp ]; then
                echo "    => FAILED ! The system may be unstable !!!"
             else
                echo "    => Success ! you were lucky, but check if / has been correctly remounted !"
		echo "    => Now trying to mount /tmp again :"
             fi
          fi
       fi

       # either it was a directory, or it now is.
       if [ -d /tmp ]; then
          mount -o mode=1777,nosuid,nodev -t tmpfs /tmp /tmp && echo "  => Success !" || echo "  => FAILED ! /tmp is a directory but is unmountable !!! The system may be unstable"
       fi
    fi
fi

/bin/rm -f /var/run/utmp /var/run/*.pid >/dev/null 2>&1
/bin/rm -rf /tmp/* /tmp/.[^.]* /tmp/..?* >/dev/null 2>&1
touch /var/log/wtmp /var/log/lastlog

#if mkdir /tmp/.$BOOTID ; then 
#  dmesg > /tmp/.$BOOTID/dmesg
#fi

# Writing Status
#for dir in / /dev /tmp /var /etc /boot ; do
#  s=""
#  if [ -L $dir ] ; then s=$s"a symbolic-link " ; t=L ; fi
#  if [ -w $dir ] ; then s=$s"read-write "; t=RW ; else 
#                        s=$s"read-only " ; t=RO ; fi
#  echo "$dir is $s"
#done

echo "Base system done." | lcdtee

