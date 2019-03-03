# SyncBox

Linux shell script for syncing two machines on the same network.  This is more than just a backup script, it will also delete files that have been deleted from one machine since the last script run.  The idea is to keep both machines synced with each other.

Needs the following folders created in the same directory as the script is in:
1. backup - Holds a backup of the machines directory to be synced, just in case.
2. flag-files - Text files will be placed here for coordinating the movement of files between machines.  Kind of a gross implementation but it works.
3. sync-reports - Contains a report for each time SyncBox is run.

Set up instructions:
First note that this is only meant to sync two machines, let's call them A and B.

On machine A:
1. Place syncbox.sh in it's own directory called "SyncBox" at the root or top of the directory structure you want to work in.  For example /home/SyncBox should be the directory that contains everything.
2. Create the 3 directories mentioned above.
3. Make sure correct permissions are set on syncbox.sh.  Run ls -l and then sudo chmod to change if need be.

On machine B:
1. Create the same "SyncBox" directory as before, in the same location.
2. Create back-up and flag-files directories in the SyncBox folder (no need for the reports here).
3. Start sshd.  The command in OpenSuse Leap is sudo systemctl start sshd (could set up a simple script on machine B to start sshd before SyncBox runs so it's not on all the time).

How to run:
1. Back up both machines!
2. From SyncBox directory run ./syncbox.sh <path of directory to be synced>  (note that machine B must have the same directory structure for this to work).
3. Check both machines and the generated sync report.
  
This can also be run as a cronjob, just use crontab -e and add the command plus the times to be run.

Caveats:
- Only works when both machines are connected to a router via ethernet cables.
- Both machines must have the same directory structure, ESPECIALLY when running for the first time!!  SyncBox copies and deletes according to file/directory timestamps so if machine A has a file that is older than the the flag of the last run and B does not have that file then it will be deleted!
- This has only been lightly tested on OpenSuse Leap.  Some commands in the script may or may not work on other distributions.

Have fun!
