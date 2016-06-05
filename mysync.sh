#!/bin/bash
#set -x
#
# TO ADD:
# Add/check network support: 
## defaults write com.apple.systempreferences TMShowUnsupportedNetworkVolumes 1
# Create sparsebundle to preserve permissions, links, etc...
## hdiutil create -size 600g -fs HFS+J -volname "MySync" MySync.sparsebundle
# Mount THAT instead of smb/afp share...
## hdiutil attach MySync.sparsebundle
#
# MySync script
# Last updated: March 2nd, 2016
# See readme.txt for details
#
################################################################################################
# Configuration. Edit values below:

# Backup path:
# What to backup? This script is designed with root access in mind, in order to backup the
# entire system ( / ). But you can still chose a specific base directory (and thus all its
# subdirs).
#hourlybackup="~/" TODO
#dailybackup="/" TODO
backup="/"
path="~/mysync"

# Prevent system from becoming idle and sleeping during backup?
# This is recommended if you're running on battery.
caffeinate=1


# Location:
# Location is detected by the IP address range. There is probably better ways to achieve this,
# but since my different locations have different IP ranges, this works well for me.
# Location is only used to mount the proper storage. If your storage is the same accross
# multiple locations, this is not needed.
#
# Define the locations 
# Example: location=(home work mom shop)
# Single location example: location=(home)
# Make sure to define IP ranges for each
location=(work home)


# Define the IP ranges for those locations. Do not put the last digits. 
# Leave ending dot (.)
# You need to add a new section like below for every location.
work="10.168.118."
home="192.168.0."


# Mounts. We use osascript to mount the volumes. Edit proper info
# Types supported are: afp, smb
# Share is the mount path. It's case sensitive
# Link is the IP address of the share to mount
# Sync is the name of the MySync sparsebundle to mount
# Syncpass is the password to mount the encrypted Sync. Leave commented if no pass.
worktype=afp
workuser=myuser
workpass=mypass
worklink=10.1.1.8
workshare=TimeMasheen
worksync=MySync
worksyncpass=mysyncpass

hometype=afp
homeuser=myworkuser
homepass=somepass
homelink=192.168.0.222
homeshare=TimeMachine
homesync=MySync
homesyncpass=mysyncpasshome


# Rsync arguments. If you don't know what these are, leave default!
# -a implies: -rlptgoD. See 'man rsync' for more details.
rsargs="-auHxS"


# Enable debug; this simply adds more output to commands and logs.
# Helpful for troubleshooting the scripts if something goes wrong.
DEBUG=0


###############################################################################################
################ DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING ################
###############################################################################################
#
#
cd "$path"
# Check if we can sudo; die if we can't. No point going further.
if [ "$(sudo whoami)" != "root" ]; then
	echo "Sorry, cannot sudo to root. See readme.txt."
	exit 1
fi

# Trap ctrl-c and call ctrl_c(), perform cleanup.
trap ctrl_c INT
function ctrl_c() {
    echo "** Trapped CTRL-C or script called ABORT**"
    echo "** Trapped CTRL-C or script called ABORD**" >> log/mysync.log
    echo "Cleaning up and aborting ..."
# Unmount MySync
if [ -z "$srdc" ]
    then
	echo "Unmounting $srdc ..." >> log/mysync.log
        /usr/bin/hdiutil detach -force "$srdc" >> log/mysync.log 2>&1
        echo "...done."  >> log/mysync.log
fi
# Umount afp/smb
if [ -z "$rdc" ]
    then
	echo "Unmounting $rdc ..." >> log/mysync.log
	/usr/bin/hdiutil unmount -force "$rdc" >> log/mysync.log 2>&1
	echo "...done."  >> log/mysync.log
fi
# Clean up...
sudo rm -rf /tmp/mysync.lock		
}


# Help
# Print the help menu
if [[ "$1" == "--help" ]] || [[ "$1" == "--h" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "help" ]] || [[ "$1" == "-help" ]] 
    then
	echo "Usage: ./`basename "$0"` [firstrun|hourly|daily|weekly|monthly|clearlog|cleanup|cron] [--force]"
	echo "Example: ./`basename "$0"` firstrun"
	echo "* Note: --force only works for clearlog and cleanup, see \"./`basename "$0"` clearlog|cleanup\" for details."
    exit
fi

# Cron
if [[ "$1" == "cron" ]]
    then
        echo "crontab help... peelist blah blah"
    exit
fi

# Clearlog
if [[ "$1" == "clearlog" ]]
    then
        if [[ "$2" == "--force" ]]
            then
                echo "Clearing log..."
                echo "" > log/mysync.log
                echo "... done!"
            exit
        fi
        echo CLEARLOG:
        echo "This will clear the log file. It is recommended you add this to /etc/newsyslog.d/"
        echo "You can also do this manually. This switch exists if you do not want to add to "
        echo "newsyslogd and are running this on a crontab. It will prevent the file from growing"
        echo "endlessly. Simply run this before your monthly cron."
        echo
        echo USAGE:
        echo "To proceed, add --force: ./mysync.sh clearlog --force"
        echo
    exit
fi

# Cleanup
if [[ "$1" == "cleanup" ]]
    then
        if [[ "$2" == "--force" ]]
            then
                echo "Cleaning up..."
                sudo rm -rf /tmp/mysync.lock
                for x in `ps auxwww |grep -v grep|grep -v "$ppid" |egrep 'mysync.sh|hourly|daily|weekly|monthly' |egrep -vi 'nano|vi|emacs|edit' | awk '{print $2}'`; do kill -9 $x; done >> /dev/null 2>&1
                echo "... done!"
            exit
        fi
        echo CLEANUP:
        echo "This will clean up temp files left by the script in case it says it's already running"
        echo "This should never happen but if the script errors out or fails to complete, it might"
        echo "Note: This will also try to kill any running processes."
        echo
        echo USAGE:
        echo "To proceed, add --force: ./`basename "$0"` cleanup --force"
        echo
    exit
fi


# Start new log session
touch log/mysync.log; echo >> log/mysync.log; echo >> log/mysync.log; echo >> log/mysync.log
echo "`date`" >> log/mysync.log

# Make sure firstrun is ran. If it's not, die.
if [[ "$1" == "firstrun" ]]
    then
        mkdir .firstrun
fi
if [ ! -d "./.firstrun" ]
    then
        echo "Please run ./`basename "$0"` firstrun. See readme.txt"
        echo "Firstrun not ran, exiting." >> log/mysync.log
        exit 1
fi

# Are we already running? Die if we are.
if ! sudo mkdir /tmp/mysync.lock 2>/dev/null; then
    echo "MySync is already running; or we can't sudo!" >> log/mysync.log
    exit 1
fi

# Die if not a valid option
if [[ "$1" != "--help" ]] && [[ "$1" != "--h" ]] && [[ "$1" != "-h" ]] && [[ "$1" != "help" ]] && [[ "$1" != "-help" ]] && [[ "$1" != "furstrun" ]] && [[ "$1" != "hourly" ]] && [[ "$1" != "daily" ]] && [[ "$1" != "weekly" ]] && [[ "$1" != "monthly" ]] && [[ "$1" != "clearlog" ]] && [[ "$1" != "cleanup" ]] && [[ "$1" != "cron" ]] && [[ "$1" != "firstrun" ]]
    then
       echo ERROR
       echo "Unknown option: $@"
       echo
       ./`basename "$0"` --help
      ctrl_c;
   exit 
fi

# Make sure this script doesn't overlap itself. If we're running monthly, don't hourly, etc...
#mdate=`date "+%d"` # 1
#wdate=`date '+%A'` # Monday
#ddate=`date +"%H:%M"` # 00:00
#if [[ "$mdate" == "1" ]]
#    then
#	$1 = "monthly"
#elif [[ "$wdate" == "Monday" ]]
#    then
#	$1 = "weekly"
#elif [[ "$ddate" == "00:00" ]]
#    then
#        $1 = "daily"
#fi
#if [ $DEBUG == "1" ]
#    then
#        echo "MDATE = $mdate" >> log/mysync.log
#        echo "WDATE = $wdate" >> log/mysync.log
#        echo "DDATE = $ddate" >> log/mysync.log
#	echo "DOLLAR-1 = $1" >> log/mysync.log
#fi

# Detect location
for x in ${location[@]}; do
figrp="$(eval echo \$${x})"
igrp=`ifconfig |egrep "$figrp" -c`
    if [[ "$igrp" -gt "0" ]]
        then
            rl=$x
    fi
done

if [[ $DEBUG == "1" ]] ;then
	echo "Real Location = $rl" >> log/mysync.log
fi

# Now, we mount that location's mount
/usr/bin/osascript -e "mount volume \"$(eval echo \$${rl}type)://$(eval echo \$${rl}user):$(eval echo \$${rl}pass)@$(eval echo \$${rl}link)/$(eval echo \$${rl}share)\""  >> log/mysync.log 2>&1

if [[ $DEBUG = "1" ]]
    then
	echo "/usr/bin/osascript -e mount volume $(eval echo \$${rl}type)://$(eval echo \$${rl}user):$(eval echo \$${rl}pass)@$(eval echo \$${rl}link)/$(eval echo \$${rl}share)"  >> log/mysync.log
fi

# Make sure it exists, exit if it fails:
grp=$(eval echo \$${rl}share)
dc=`df |grep "$grp" -c`
rdc=`df |grep "$grp" | awk '{print $NF}'`
if [[ $DEBUG = "1" ]]
    then
	echo "GREP = $grp"  >> log/mysync.log
	echo "DC = $dc" >> log/mysync.log
	echo "RDC = $rdc" >> log/mysync.log
fi
if [[ $dc == "" ]]
    then
	echo Mount appears to have failed... exiting!. 
		if [[ $DEBUG = "1" ]]
		    then
			echo You requested to mount $(eval echo \$${rl}share) but it appears to not be mounted: >> log/mysync.log
			df | awk '{print $NF}' | grep -v 'on' >> log/mysync.log
			echo "df |grep $(eval echo \$${rl}share)" >> log/mysync.log
		fi
	exit
fi

# Mount MySync sparsebundle
echo "Attaching $rdc/$(eval echo \$${rl}sync).sparsebundle ..." >> log/mysync.log
# Do we have to set a password?
if [ ! "$(eval echo \$${rl}syncpass)" ]
    then
	/usr/bin/hdiutil attach $rdc/$(eval echo \$${rl}sync).sparsebundle  >> log/mysync.log 2>&1
    else
	echo "Running: printf '%s\0' \"$(eval echo \$${rl}syncpass)\" | /usr/bin/hdiutil attach $rdc/$(eval echo \$${rl}sync).sparsebundle -stdinpass"  >> log/mysync.log
	printf '%s\0' "$(eval echo \$${rl}syncpass)" | /usr/bin/hdiutil attach $rdc/$(eval echo \$${rl}sync).sparsebundle -stdinpass  >> log/mysync.log 2>&1
fi
sgrp=$(eval echo \$${rl}sync)
sdc=`df |grep "$sgrp" -c`
srdc=`df |grep "$sgrp" | awk '{print $NF}'`
if [[ $sdc == "" ]]
    then
        echo Attaching appears to have failed... exiting!.
                if [[ $DEBUG = "1" ]]
                    then
                        echo You requested to mount $(eval echo \$${rl}sync) but it appears to not be mounted: >> log/mysync.log
                        df | awk '{print $NF}' | grep -v 'on' >> log/mysync.log
                        echo "df |grep $(eval echo \$${rl}sync)" >> log/mysync.log
                fi
        exit
echo "done!"  >> log/mysync.log
fi

# Call appropriate script
if [[ "$1" == "firstrun" ]]
    then
        echo "Running firstrun script..." >> log/mysync.log
        echo "Please wait... first run can take a long time..."
	if [[ "$caffeinate" = "1" ]]; then
            sudo /usr/bin/caffeinate -i /usr/bin/nice -n 19 ./scripts/firstrun $srdc $backup $DEBUG $rsargs
	else
	    sudo /usr/bin/nice -n 19 ./scripts/firstrun $srdc $backup $DEBUG $rsargs
	fi
        echo "... firstrun done!" >> log/mysync.log
# Now let's print some help for the user.
    echo
    echo "Here's some tips..."
    ./`basename "$0"` --help
    echo
    ./`basename "$0"` crontab
    echo 
fi
if [[ "$1" == "hourly" ]]
    then
        echo "Running hourly script..." >> log/mysync.log
        if [[ "$caffeinate" = "1" ]]
	    then	
	        sudo /usr/bin/caffeinate -i /usr/bin/nice -n 19 ./scripts/hourly $srdc $backup $DEBUG $rsargs
#echo sudo /usr/bin/caffeinate -i /usr/bin/nice -n 19 ./scripts/hourly $srdc $backup $DEBUG $rsargs
            else
	        sudo /usr/bin/nice -n 19 ./scripts/hourly $srdc $backup $DEBUG $rsargs
#echo sudo ./scripts/hourly $srdc $backup $DEBUG $rsargs
        fi
        echo "... hourly script done!" >> log/mysync.log
fi
if [[ "$1" == "daily" ]]
    then
        echo "Running daily script..." >> log/mysync.log
        if [[ "$caffeinate" = "1" ]]; then
            sudo /usr/bin/caffeinate -i /usr/bin/nice -n 19 ./scripts/daily $srdc $backup $DEBUG $rsargs
        else
	    sudo /usr/bin/nice -n 19 ./scripts/daily $srdc $backup $DEBUG $rsargs
        fi
        echo "... daily script done!" >> log/mysync.log
fi
if [[ "$1" == "weekly" ]]
    then
        echo "Running weekly script..." >> log/mysync.log
        if [[ "$caffeinate" = "1" ]]; then
            sudo /usr/bin/caffeinate -i /usr/bin/nice -n 19 ./scripts/weekly $srdc $backup $DEBUG $rsargs
        else
	    sudo /usr/bin/nice -n 19 ./scripts/weekly $srdc $backup $DEBUG $rsargs
        fi
        echo "... weekly script done!" >> log/mysync.log
fi
if [[ "$1" == "monthly" ]]
    then
        echo "Running monthly script..." >> log/mysync.log
        if [[ "$caffeinate" = "1" ]]; then
            sudo /usr/bin/caffeinate -i ./scripts/monthly $srdc $backup $DEBUG $rsargs
        else
	    sudo ./scripts/monthly $srdc $backup $DEBUG $rsargs
        fi
        echo "... monthly script done!" >> log/mysync.log
fi


# And finally, unmount the share. This is done for multiple reasons; namely prevent
# a 5 minute shutdown procedure when you power off your Mac.....
echo "Unmounting $rdc and $srdc ..." >> log/mysync.log
/usr/bin/hdiutil detach -force $srdc >> log/mysync.log 2>&1
/usr/bin/hdiutil unmount -force $rdc >> log/mysync.log 2>&1
echo "...done."  >> log/mysync.log

# Clean up...
sudo rm -rf /tmp/mysync.lock
