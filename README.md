# MySync

MySync is a custom rsync incremental backup script for OSX. I wrote this for myself,
due to the special requirements I have, and no good alternatives being around. Written
as a time machine replacement due to how incredibly unreliable TM is. This is meant
as a "run and forget" script, unless there are issues. Everything is logged to
mysync.log. This backs up the entire system ( / ) and requires sudo passwordless access
in order to run unattended. If you do not wish to grant that access, you can still run
the script manually as root.

REQUIREMENTS:
- Writable remote backup system
- Access through sbm or afp
- A sparsebundle file on the smb or afp share
- rsync (from macports or brew)
- bash
- crontab

INSTALLATION:
- Add sudoers access: Myuser ALL = (root) NOPASSWD: /full/path/to/mysync.sh
- Edit mysync.sh, the top few lines explain everything.
- Edit backup_excludes.txt and add your personalized exclusion paths.
- Create encrypted sparsebundle image on your "share" mount (see mysync.sh):
hdiutil create -size 1024g -volname "MySync" -encryption AES-256 -stdinpass -type SPARSEBUNDLE -fs "HFS+J" MySync.sparsebundle

USAGE:
- IMPORTANT!!! Do the first run manually and wait for it to complete!
This can take a long time...
- Add to crontab:
Hourly: @hourly /full/path/to/mysync.sh hourly
Daily: @daily /full/path/to/mysync.sh daily
Weekly: @weekly /full/path/to/mysync.sh weekly
Monthly: @monthly /full/path/to/mysync.sh monthly

KNOWN PROBLEMS:
- pax will throw socket errors in logs. This is expected, sockets cannot be linked and will be created when the original app starts.
- ctrl-c unmounts may print weird errors. It should still unmount.


CAVEATS:
- This will print your password in plain text to mount the drive. If you're using encrypted backup disks, then it is
strongly suggested you also encrypt this disk (the disk you are backing up, or the location where this script runs
if it's not on the same disk) so the password is not accessible without first decrypting the drive.
