#!/bin/bash

# Removes user directories from /tmp for each available node not currently in use by $USER in SLURM scheduler.
# ATTENTION!
# It is possible that not all nodes will be accessible, and thus not all user /tmp directories will be removed. 
# User is advised to run this script frequently at different time periods.
# To run it from login node:
# bash rmTMP.sh

# Initial parameters
EmptyTmp=EmptyUserTmp34.sh
AvailNodes=PartNode78.txt

# Parameters for sbatch
Output=DeleteMe82.txt
Ntasks=1
MemPerCpu=100

# Check for the existence of the produced files in the working directory. If they already exist, exit the script. 
[[ -f ${EmptyTmp} ]] && echo "${EmptyTmp} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2 && exit 1
[[ -f ${AvailNodes} ]] && echo "${AvailNodes} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2 && exit 1
[[ -f ${Output} ]] && echo "${Output} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2 && exit 1

# Remove produced files upon exit or interrupt.
trap "sleep 1; rm -f $EmptyTmp $AvailNodes $Output; exit 1;" SIGINT
trap "rm -f $EmptyTmp $AvailNodes $Output" EXIT

# Find all the nodes which do not have enough available memory.
FullMemNode=$(sinfo -O NodeAddr,Partition,AllocMem,Memory | sed 's/ \+/ /g;s/*//g' | awk -v mem=${MemPerCpu} 'NR>1 && ($4-$3)<mem {print $1}')

# Also, find all the nodes currently in use by the user. 
UserNode=$(squeue | awk -v user="$USER" 'BEGIN {ORS = "|"} $4==user {print $8}' | sed 's/|/ /g')

# Combine the two variables to a new one, containing all the unavailable nodes.
# The goal is to prevent running a job on any of these nodes.
UnavailNode=$(echo ${FullMemNode}" "${UserNode} | sed 's/ /\n/g' | sort -u | tr "\n" "|" | sed 's/|$//g;s/^|//g')

# Find all the available nodes and export them.
if [[ -z ${UnavailNode} ]] 
then 
    sinfo --Node | awk '$4 ~ /mix|idle/ {print $1, $3}' | sed 's/*$//g' > $AvailNodes
else 
    sinfo --Node | awk -v node=${UnavailNode} '$1!~node && $4 ~ /mix|idle/ {print $1, $3}' 2> /dev/null | sed 's/*$//g' > $AvailNodes
    echo
    echo "User directories in /tmp of ${UnavailNode//|/,} will NOT be deleted. Try again later when recources become available."
    echo
fi

# If there are no available nodes, exit the script
[[ -z ${AvailNodes} ]] && echo "There are no available nodes. No files were deleted. Please try again later." >&2 && exit 1

# Delete user's directories in /tmp by running an sbatch job on each available node.
while read -r node partition
do
cat > ${EmptyTmp} <<EOF
#!/bin/bash
#SBATCH --partition=${partition}
#SBATCH --nodelist=${node}
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
   echo "User directories in /tmp of ${partition} ${node} have been deleted"
   echo
   sleep 1
done < $AvailNodes


# Delete user /tmp directories in current node.
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + 
sleep 1

exit 0
