#!/bin/bash

# Removes user directories from /tmp for each available running node not currently in use by $USER in SLURM scheduler.
# ATTENTION!
# It is possible that not all nodes will be accessible, and thus not all temp directories will be removed. 
# User is advised to run this script frequently at different time periods.
# To run it from login node:
# bash rmTMP.sh

# Initial parameters
EmptyTmp=EmptyUserTmp.sh
Output=RemoveMe94.txt

# We create a regex with all the nodes currently in use by the user. 
# We want to prevent deleting the temp directories in these nodes, because user is currently running a job on them!
UserNode=$(squeue | awk -v user="$USER" 'BEGIN {ORS = "|"} $4==user {print $8}' | sed 's/-/\\-/g;s/|$//')

# Remove produced files upon exit.
trap "rm -f $EmptyTmp $Output" EXIT

# Create a new file to clean the temp directory on each node.
cat > ${EmptyTmp} <<"EOF"
#!/bin/bash
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} +
EOF

# Next, we will run the file we created on each node, not currently being used by user.
while read -r partition
do
    while read -r node
    do
        sbatch --immediate --partition=${partition} --nodelist=${node} --output=${Output} ${EmptyTmp}     
    done < <(sinfo --Node | awk -v part=$partition -v node=${UserNode} 'part==$3 && $1!=node && $4 ~ /mix|idle/ {print $1}')
done < <(sinfo --Node | awk 'NR>1 && !a[$3]++ {print $3}' | sed 's/*$//g') 2> /dev/null


# Also empty temp in current node.
bash ${EmptyTmp}

exit 0




