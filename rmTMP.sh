#!/bin/bash

# Removes user directories from /tmp for each available running node not currently in use by $USER in SLURM scheduler.
# ATTENTION!
# It is possible that not all nodes will be accessible, and thus not all temp directories will be removed. 
# User is advised to run this script frequently at different time periods.
# To run it from login node:
# bash rmTMP.sh

# Initial parameters
EmptyTmp=EmptyUserTmp34.sh
Output1=RemoveMe94.txt
AvailNodes=PartNode78.txt

# Remove produced files upon exit.
trap "rm -f $EmptyTmp $Output1 $AvailNodes" EXIT

# Create a new file to clean the temp directory on each node.
cat > ${EmptyTmp} <<"EOF"
#!/bin/bash
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} +
EOF


# We create a regex with all the nodes currently in use by the user. 
# We want to prevent deleting the temp directories in these nodes, because user is currently running a job on them!
UserNode=$(squeue | awk -v user="$USER" 'BEGIN {ORS = "|"} $4==user {print $8}' | sed 's/-/\\-/g;s/|$//')

# Check if user is currently running a job or not and export the available nodes.
if [[ -z ${UserNode} ]] 
then 
    sinfo --Node | awk '$4 ~ /mix|idle/ {print $1, $3}' | sed 's/*$//g' > $AvailNodes
else 
    sinfo --Node | awk -v node=${UserNode} '$1!~node && $4 ~ /mix|idle/ {print $1, $3}' 2> /dev/null | sed 's/*$//g' > $AvailNodes
fi

# Delete the user created dirs in /tmp in each available node.
while read -r node partition
do
   sbatch --immediate --partition=${partition} --nodelist=${node} --output=${Output} --ntasks=1 --mem-per-cpu=50  ${EmptyTmp} 
done < $AvailNodes


# Also empty temp in current node.
bash ${EmptyTmp}


sleep 1 # Needed, for trap to take effect!

exit 0




