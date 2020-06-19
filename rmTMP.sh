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


# Parameters for sbatch
Output=Deleteme82.txt
Nnodes=1
Ntasks=1
MemPerCpu=100

# Check for the existence of the produced files. If they already exist, exit the script. 
[[ -f ${EmptyTmp} ]] && echo "${EmptyTmp} exists in ${PWD}! Please delete, rename or move the file to proceed." >&2 && exit 1
[[ -f ${AvailNodes} ]] && echo "${AvailNodes} exists in ${PWD}! Please delete, rename or move the file to proceed." >&2 && exit 1
[[ -f ${Output} ]] && echo "${Output} exists in ${PWD}! Please delete, rename or move the file to proceed." >&2 && exit 1


# Remove produced files upon exit.
trap "rm -f $EmptyTmp $AvailNodes $Output" EXIT

# We create a regex with all the nodes currently in use by the user. 
# We want to prevent deleting the temp directories in these nodes, because user is currently running a job on them!
UserNode=$(squeue | awk -v user="$USER" 'BEGIN {ORS = "|"} $4==user {print $8}' | sed 's/-/\\-/g;s/|$//')

# Check if user is currently running a job on a node or not and export the available nodes.
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
#SBATCH --nodes=${Nnodes}
#SBATCH --ntasks=${Ntasks}
#SBATCH --mem-per-cpu=${MemPerCpu}
#SBATCH --output=${Output}
EOF

cat >> ${EmptyTmp} <<"EOF"

find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + &
wait

exit 0
EOF
   sbatch ${EmptyTmp}
   sleep 1
done < $AvailNodes


# Also empty temp in current node.
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + 
sleep 1

exit 0




