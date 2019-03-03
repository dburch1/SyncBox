#!/bin/bash

################################################################################
##                                                                            ##
## ***** SyncBox *****                                                        ##
##                                                                            ##
## Sync data and files between hard drives on two different machines          ##
## This runs on machine A                                                     ##
##                                                                            ##
## May need to edit iptables.                                                 ##
##                                                                            ##
## Does not backup or sync hidden directories/files!!                         ##
##                                                                            ##
################################################################################

# Box B should already have started sshd

# Error handling of sorts
# e: exit, u: unset variables, o pipefail: errors from any command in pipeline, not just last command 
set -euo pipefail

IFS="
"

# Verify at least one argument has been passed
if [ -z $1 ]
then
	echo "There must be at least one argument"
	exit 0
fi

# Declare variables
mainDir=$1
flagFiles=$mainDir/../SyncBox/flag-files
report=$mainDir/../SyncBox/sync-reports/$(date "+%m-%d-%y__%H:%M")
boxA='192.168.0.101'
boxB='192.168.0.102'
counter=0
counterUpdateA=0
counterUpdateB=0


# Edit file with pathnames and add a \ before spaces in pathnames
escape() {
	sed 's/\([^\\]\) /\1\\ /g' "$1" > temp
	mv temp "$1"
}

echo "****************************************************************" >> "$report"
echo "****************  SyncBox Report for $(date "+%D")  ****************" >> "$report"
echo "****************************************************************" >> "$report"
echo >> "$report"

# Set start flags
# IMPORTANT - Need to reset end flags if last script run doesn't complete
date > "$flagFiles/start-A"
date > "$flagFiles/start-B"
scp "$flagFiles/start-B" "$boxB":"'$flagFiles/start-B'"

# Turn on sshd for Box A
sudo systemctl start sshd

# Backup Box A
echo "----- Backup Box A -----" >> "$report"
rsync -avz --exclude ".*" "$mainDir" "$mainDir/../SyncBox/backup" >> "$report"
echo >> "$report"
echo "----- Backup Box B -----" >> "$report"
ssh $boxB "rsync -avz --exclude '.*' '$mainDir' '$mainDir/../SyncBox/backup' > $mainDir/../SyncBox/backup/backup-report-B"
ssh $boxB "scp $mainDir/../SyncBox/backup/backup-report-B $boxA:$mainDir/../SyncBox/backup/backup-report-B"
cat "$mainDir/../SyncBox/backup/backup-report-B" >> "$report"
echo >> "$report"
echo "<<<<<  Copies & Deletions  >>>>>" >> "$report"
echo >> "$report"


# Check every directory in Box A
find "$mainDir" -type d ! -path '*\/.*' -newer "$flagFiles/end-A" > "$flagFiles/dir-mod-A"
find "$mainDir" -type d ! -path '*\/.*' ! -newer "$flagFiles/end-A" > "$flagFiles/dir-old-A"

# Check every file in Box A
find "$mainDir" -type f ! -path '*\/.*' -newer "$flagFiles/end-A" > "$flagFiles/file-mod-A"
find "$mainDir" -type f ! -path '*\/.*' ! -newer "$flagFiles/end-A" > "$flagFiles/file-old-A"

# Check every directory in Box B
ssh $boxB "find '$mainDir' -type d ! -path '*\/.*' -newer '$flagFiles/end-B' > '$flagFiles/dir-mod-B'"
ssh $boxB "find '$mainDir' -type d ! -path '*\/.*' ! -newer '$flagFiles/end-B' > '$flagFiles/dir-old-B'"

# Check every file in Box B
ssh $boxB "find '$mainDir' -type f ! -path '*\/.*' -newer '$flagFiles/end-B' > '$flagFiles/file-mod-B'"
ssh $boxB "find '$mainDir' -type f ! -path '*\/.*' ! -newer '$flagFiles/end-B' > '$flagFiles/file-old-B'"

# Move lists of paths to Box A
ssh $boxB "scp $flagFiles/dir-mod-B $boxA:$flagFiles/"
ssh $boxB "scp $flagFiles/dir-old-B $boxA:$flagFiles/"
ssh $boxB "scp $flagFiles/file-mod-B $boxA:$flagFiles/"
ssh $boxB "scp $flagFiles/file-old-B $boxA:$flagFiles/"

# Find differences between mod-A and mod-B
# Need to sort files for comm
sort "$flagFiles/dir-mod-A" -o "$flagFiles/dir-mod-A"
sort "$flagFiles/dir-mod-B" -o "$flagFiles/dir-mod-B"
sort "$flagFiles/dir-old-A" -o "$flagFiles/dir-old-A"
sort "$flagFiles/dir-old-B" -o "$flagFiles/dir-old-B"
sort "$flagFiles/file-mod-A" -o "$flagFiles/file-mod-A"
sort "$flagFiles/file-mod-B" -o "$flagFiles/file-mod-B"
sort "$flagFiles/file-old-A" -o "$flagFiles/file-old-A"
sort "$flagFiles/file-old-B" -o "$flagFiles/file-old-B"


# Filter directories to copy
comm -32 "$flagFiles/dir-mod-A" "$flagFiles/dir-mod-B" > "$flagFiles/dir-mod-A-not-B"  # A->B
comm -32 "$flagFiles/dir-mod-A-not-B" "$flagFiles/dir-old-B" > "$flagFiles/dir-A-to-B"  # A->B
comm -32 "$flagFiles/dir-mod-B" "$flagFiles/dir-mod-A" > "$flagFiles/dir-mod-B-not-A"  # A->B
comm -32 "$flagFiles/dir-mod-B-not-A" "$flagFiles/dir-old-A" > "$flagFiles/dir-B-to-A"  # A->B

# Filter directories to be deleted
comm -32 "$flagFiles/dir-old-A" "$flagFiles/dir-old-B" > "$flagFiles/dir-old-A-but-not-old-B"
comm -32 "$flagFiles/dir-old-A-but-not-old-B" "$flagFiles/dir-mod-B" > "$flagFiles/dir-delete-from-A"
comm -32 "$flagFiles/dir-old-B" "$flagFiles/dir-old-A" > "$flagFiles/dir-old-B-but-not-old-A"
comm -32 "$flagFiles/dir-old-B-but-not-old-A" "$flagFiles/dir-mod-A" > "$flagFiles/dir-delete-from-B"

# Filter files to copy
comm -32 "$flagFiles/file-mod-A" "$flagFiles/file-mod-B" > "$flagFiles/file-A-to-B"  # A->B
comm -32 "$flagFiles/file-mod-B" "$flagFiles/file-mod-A" > "$flagFiles/file-B-to-A"  # B->A

# Filter to update (new on both machines)
comm -21 "$flagFiles/file-mod-A" "$flagFiles/file-mod-B" > "$flagFiles/file-Both"  # B->A

# Filter files to be deleted
comm -32 "$flagFiles/file-old-A" "$flagFiles/file-old-B" > "$flagFiles/file-old-A-but-not-old-B"
comm -32 "$flagFiles/file-old-A-but-not-old-B" "$flagFiles/file-mod-B" > "$flagFiles/file-delete-from-A"
comm -32 "$flagFiles/file-old-B" "$flagFiles/file-old-A" > "$flagFiles/file-old-B-but-not-old-A"
comm -32 "$flagFiles/file-old-B-but-not-old-A" "$flagFiles/file-mod-A" > "$flagFiles/file-delete-from-B"

# Need to sort directories to be deleted to get nested directories first
sort -r "$flagFiles/dir-delete-from-A" -o "$flagFiles/dir-delete-from-A"
sort -r "$flagFiles/dir-delete-from-B" -o "$flagFiles/dir-delete-from-B"


# Make directories on A
for path in $(cat $flagFiles/dir-B-to-A)
do
	 mkdir "$path"	
	 counter=`expr $counter + 1`
done
echo "Created directories on Box A: $counter" >> "$report"
counter=0

# Make directories on B
for path in $(cat $flagFiles/dir-A-to-B)
do
 	escPath=$(echo "$path" | sed -e 's/\([^\\]\) /\1\\ /g')
	ssh $boxB "mkdir $escPath"
	counter=`expr $counter + 1`
done
echo "Created directories on Box B: $counter" >> "$report"
counter=0

# Copy files to B
for path in $(cat $flagFiles/file-A-to-B)
do
	escPath=$(echo "$path" | sed -e 's/\([^\\]\) /\1\\ /g')
	scp -p "$path" $boxB:"$escPath"
	counter=`expr $counter + 1`
done
echo "Copied files to Box B: $counter" >> "$report"
counter=0

# Copy files to A
for path in $(cat $flagFiles/file-B-to-A)
do
	escPath=$(echo "$path" | sed -e 's/\([^\\]\) /\1\\ /g')
	rsync -a $boxB:"$escPath" "$path"
	counter=`expr $counter + 1`
done
echo "Copied files to Box A: $counter" >> "$report"
counter=0

# Update files on both
for path in $(cat $flagFiles/file-Both)
do
	escPath=$(echo "$path" | sed -e 's/\([^\\]\) /\1\\ /g')
	timeA=$(stat -c %Y "$path")
	ssh $boxB "stat -c %Y $escPath > $flagFiles/stats-B"
	rsync -a $boxB:"$flagFiles/stats-B" "$flagFiles/stats-B"
	if [ $timeA -ge $(cat "$flagFiles/stats-B") ]
	then
		# is newer on A
		scp -p "$path" $boxB:"$escPath"
		counterUpdateB=`expr $counterUpdateB + 1`
	else
		# is newer on B
		rsync -a $boxB:"$escPath" "$path"
		counterUpdateA=`expr $counterUpdateA + 1`
	fi
done
echo "Updated files on Box A: $counterUpdateA" >> "$report"
echo "Updated files on Box B: $counterUpdateB" >> "$report"

# Delete files from A
for path in $(cat $flagFiles/file-delete-from-A)
do
	counter=`expr $counter + 1`
	rm "$path"
	echo "Deleted $path from Box A" >> "$report"
done
echo "Deleted files from Box A: $counter" >> "$report"
counter=0

# Delete files from B
for path in $(cat $flagFiles/file-delete-from-B)
do
	counter=`expr $counter + 1`
	ssh $boxB "rm '$path'"
	echo "Deleted $path from Box B" >> "$report"
done
echo "Deleted files from Box B: $counter" >> "$report"
echo "$report"
counter=0

# Delete directories from A
for path in $(cat $flagFiles/dir-delete-from-A)
do
	counter=`expr $counter + 1`
	rmdir "$path"
	echo "Deleted $path from Box A" >> "$report"
done
echo "Deleted directories from Box A: $counter" >> "$report"
counter=0

# Delete directories from B
for path in $(cat $flagFiles/dir-delete-from-B)
do
	counter=`expr $counter + 1`
	ssh $boxB "rmdir '$path'"
	echo "Deleted $path from Box B" >> "$report"
done
echo "Deleted directories from Box B: $counter" >> "$report"
echo "$report"
counter=0


# Clean up a few files
rm $flagFiles/file-delete-from-A
rm $flagFiles/file-delete-from-B
rm $flagFiles/dir-delete-from-A
rm $flagFiles/dir-delete-from-B

# Set end flags
date > "$flagFiles/end-A"
date > "$flagFiles/end-B"
scp "$flagFiles/end-B" "$boxB":"'$flagFiles/end-B'"
echo "End flags set"

# Final report
start=`stat -c %Y "$flagFiles/start-A"`
end=`stat -c %Y "$flagFiles/end-A"`
echo "Time elapsed: `expr "$end" \- "$start"` seconds" >> "$report"
echo >> "$report"
echo "**************  SyncBox run completed on `date`  **************" >> "$report"
echo >> "$report"
echo >> "$report" 

ssh $boxB "sudo systemctl stop sshd"

