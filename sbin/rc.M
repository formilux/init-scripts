#!/bin/sh

if [ ! -x /bin/lcdwrite ] ; then function lcdwrite { /bin/true; } ; fi 
if [ ! -x /bin/lcdtee ] ; then function lcdtee { /bin/cat; } ; fi 

LOG=/var/log/bootlog

function start {
  for service in $* ; do
    echo -n "Starting $service ... " 
    echo -n "$service ... " | lcdwrite
    echo "----- Starting $service with /sbin/init.d/$service -----" >> $LOG
    if [ -x /sbin/init.d/$service ] ; then
      /sbin/init.d/$service start >> $LOG 2>&1 
      if [ $? -eq 0 ] ; then 
        echo "done" | lcdtee
        echo "----- Done -----" >> $LOG
      else 
        echo "failed" | lcdtee
        echo "----- Failed -----" >> $LOG
      fi
    else 
      echo "failed" | lcdtee
      echo "----- Failed -----" >> $LOG
    fi
  done
}


# Reinit /var/log/bootlog file
/bin/rm -rf /var/log/bootlog

# Running multiuser part
echo "Starting Multi-user (`date`)" | tee -a $LOG

# Cron should be moved to a proper service script

# Starting 'crond' if exist
#if [ -x /usr/sbin/crond ] ; then
#  if [ ! -d /var/spool/cron/crontabs ] ; then mkdir -p /var/spool/cron/crontabs ; fi
#  crond
#fi

# Starting 'atd' if exist
#if [ -x /usr/sbin/atd ] ; then
#  atd
#fi

# Sourcing base configuration
if [ -x /etc/startup.rc ] ; then
  /etc/startup.rc | tee -a $LOG
elif [ -d /etc/startup.rc ] ; then
  for i in /etc/startup.rc/S* ; do
    $i
  done
else
  echo "No /etc/startup.rc file" | lcdwrite | tee -a $LOG
  echo "No configuration file (/etc/startup.rc)" | tee -a $LOG
fi

# Starting SystemV like daemon
if [ -d /etc/rc$RUNLEVEL.d -a -x /sbin/init.d/sysvinit ] ; then
  /sbin/init.d/sysvinit start | tee -a $LOG
fi

# OK
