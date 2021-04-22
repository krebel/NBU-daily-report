#!/bin/bash
#
# SCRIPT: BackupsReport.sh
# VERSION: 1
# AUTHOR: Kurt Rebel
# DATE: 04/22/2021
# PLATFORM: Linux
# PURPOSE: Provide various reports on last 24 hours of backups to save over time and some NBU enviro status
# Make executable
# Add crontab entry:
# 0 07 * * * /root/thereport.sh >> /dev/null 2>&1
# Change hostname in mail line at bottom to actual mail server
#

# Variables, and files:
last24=`date -d "yesterday 13:00" '+%m/%d/%y'`

outf=/usr/openv/tmp/report_`date -d "yesterday 13:00" '+%m-%d-%y'`.txt

ADMINCMD=/usr/openv/netbackup/bin/admincmd


# Commands

# get all jobs to file:
$ADMINCMD/bpdbjobs -report -all_columns -fast > /usr/openv/tmp/jobs_`date -d "yesterday 13:00" '+%m-%d-%y'`.txt

# compress jobs out:
/usr/bin/gzip /usr/openv/tmp/jobs_`date -d "yesterday 13:00" '+%m-%d-%y'`.txt


# report on any Accelerator that lost prior full/incr:

echo "Following Accelerator incr backups switched to Full:" >> $outf
echo "" >> $outf

grep "There is no complete backup image match with track journal" /usr/openv/tmp/jobs_* | cut -f 1-8 -d ',' >> $outf

echo "" >> $outf
echo "" >> $outf


echo "Backup Status report:" >> $outf
echo "" >> $outf

$ADMINCMD/bperror -U -backstat -hoursago 24 >> $outf

echo "" >> $outf
echo "" >> $outf


echo "Client Backups report:" >> $outf

$ADMINCMD/bpimagelist -U -d $last24 >> $outf

echo "" >> $outf
echo "" >> $outf


LASTHOTCAT="/usr/openv/netbackup/bin/admincmd/bpimagelist -U -hoursago 240 -pt NBU-Catalog"
CATPOLNAME=`/usr/openv/netbackup/bin/admincmd/bppllist -allpolicies -U | grep -B2 '  Policy Type:         NBU-Catalog' | grep 'Policy Name:' | awk '{print $3}'`

echo "Last hot catalog backup was:" >> $outf
$LASTHOTCAT >> $outf

echo "" >> $outf
echo "" >> $outf

#echo "Hot catalog backup DR path is: "
/usr/openv/netbackup/bin/admincmd/bppllist $CATPOLNAME | grep DR_PATH >> $outf

echo "" >> $outf
echo "" >> $outf


echo "Problems report:" >> $outf

$ADMINCMD/bperror -problems -hoursago 24 -U >> $outf

echo "" >> $outf
echo "" >> $outf


echo "Storage server status:" >> $outf
#nbdevquery -liststs -stype PureDisk -U | egrep 'Storage Server      :|Storage Server Type|State' >> $outf

$ADMINCMD/nbdevquery -liststs | awk '{print "nbdevquery -liststs -storage_server " $2,"-stype "$3 " -U"}' > /root/liststs1

chmod 550 /root/liststs1

/bin/bash /root/liststs1 | egrep 'Storage Server      :|Storage Server Type|State' |  awk '{ORS=NR % 3? " ": "\n"; print}' | column -t | sed 's/  :/:/g' | sed 's/  / /g' | sed 's/ Storage Server Type/    Storage Server Type /g' | sed 's/State:/   State:/g' >> $outf

echo "" >> $outf
echo "" >> $outf


echo "Disk Pool status:" >> $outf
$ADMINCMD/nbdevquery -listdp -U | egrep 'Disk Pool Name|Status|Admin|Internal|Storage Server' |  awk '{ORS=NR % 5? " ": "\n"; print}' | sed 's/  :/:/g' | sed 's/  / /g' | sed 's/Disk Pool Name :/Disk Pool Name:/g' | sed 's/Status     :/   Status:/g' | sed 's/Flag      :/   /g' | sed 's/Storage Server :/   Storage Server:/g' >> $outf

echo "" >> $outf
echo "" >> $outf

echo "Disk volume status (details):" >> $outf
$ADMINCMD/nbdevquery -liststs | awk '{print "nbdevquery -listdv -stype "$3 " -U"}' > /root/dvstypes

chmod 550 /root/dvstypes

/bin/bash /root/dvstypes | egrep 'Disk Pool Name|Disk Type|Total|Free|Status|Admin|Internal' | sed 's/Disk Pool Name/\nDisk Pool Name/g' >> $outf

echo "" >> $outf
echo "" >> $outf



echo "Top 15 worst dedup rates with the most stored in MSDP" >> $outf
$ADMINCMD/bperror -l -disk -dt 6 -d 01/01/2020 | grep bptm | grep dedup > /usr/openv/tmp/dsklogdedup.txt
echo "     Date/time                   |    Client   |   MSDP storagesvr  | JobI  | scanned \(KB\) | CR sent \(KB\) | dedup rate" >> $outf
echo "____________________________________________________________________________________________________________" >> $outf
awk '{printf("%30s%15s%20s%5s%15s%12s%10s\n", $1=strftime("%c ", $1), $9, $15, $7, $17, $21, $30)}' /usr/openv/tmp/dsklogdedup.txt | sort -nrk11 | sed 's/(//g' | sed 's/)//g' | head -n 15 >> $outf


# mail report (change the particulars as this is sent to root@localhost)
cat $outf | mailx -s 'DailyReport' -r root@nb82mstrprod -v root@nb82mstrprod


/usr/bin/gzip $outf

rm -f /root/liststs1
rm -f /root/dvstypes

exit 0
