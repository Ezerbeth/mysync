Example cronjob:
Hourly: @hourly /full/path/to/mysync.sh hourly
Daily: @daily /full/path/to/mysync.sh daily
Weekly: @weekly /full/path/to/mysync.sh weekly
Monthly: @monthly /full/path/to/mysync.sh monthly

Note that Apple claims crontab is not recommended and deprecated, replaced by launchd. 
Example plist are included. To load them, copy them to ~/Library/LaunchAgents/
and load them: launchctl load ~/Library/LaunchAgents/com.mysync.hourly, etc
