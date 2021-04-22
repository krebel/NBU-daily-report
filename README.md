# NBU-daily-report
# PLATFORM: Linux
# PURPOSE: Provide various reports on last 24 hours of backups to save over time
# Place in /root on the NBU Master server, make executable
# Add crontab entry:
# 0 07 * * * /root/thereport.sh >> /dev/null 2>&1
# Change hostname in mail line at bottom to actual mail server
# Or just view the report at /usr/openv/tmp/report_MM-DD-YY.txt.gz
