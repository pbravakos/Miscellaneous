#!/bin/bash

# Removes user directories from /tmp for each available running node not currently in use by $USER in SLURM scheduler.
# ATTENTION!
# It is possible that not all nodes will be accessible, and thus not all temp directories will be removed. 
# User is advised to run this script frequently at different time periods.
# To run it from login node:
# bash rmTMP.sh

# Initial parameters
EmptyTmp=EmptyUserTmp34.sh
AvailNodes=PartNode78.txt

# Remove produced files upon exit.
#trap "rm -f $EmptyTmp $AvailNodes" EXIT

# Create a new file to remove directories in /tmp on each node.
#cat > ${EmptyTmp} <<EOF
##!/bin/bash

## find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} +
#echo "SLURM partition = " "$SLURM_JOB_PARTITION"
#echo "SLURM node list = " "$SLURM_JOB_NODELIST"
#cd /tmp 
#sleep 1 
##if [[ "$USER" == $(ls -la | grep "$USER" | awk '{ print $3 }' | uniq) ]]
##then
##     rm -rf `ls -la | grep "$USER" | awk '{ print $9 }'`
##fi

#exit 0
#EOF


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

# Delete the user created dirs in /tmp by running an sbatch job on each available node.
while read -r node partition
do
cat > ${EmptyTmp} <<EOF
#!/bin/bash
#SBATCH --partition=${partition}
#SBATCH --nodelist=${node}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
# #SBATCH --output=
EOF

cat >> ${EmptyTmp} <<"EOF"

echo "SLURM partition = " "$SLURM_JOB_PARTITION"
echo "SLURM node list = " "$SLURM_JOB_NODELIST"

sleep 1
echo panos
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + &
wait
sleep 1
exit 0
EOF
   echo $partition $node
   sbatch ${EmptyTmp} 
done < $AvailNodes


# Also empty temp in current node.
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + 


exit 0




