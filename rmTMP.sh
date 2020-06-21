#!/bin/bash

# Removes user directories from /tmp for each available node not currently in use by $USER in SLURM scheduler.

# ATTENTION!
# It is possible that not all nodes will be accessible, and thus not all user /tmp directories will be removed. 
# It is recommended to run this script frequently at different time periods.

# Run the script from login node as follows:
# bash rmTMP.sh

# Initial parameters
EmptyTmp=EmptyUserTmp.sh
AvailNodes=PartNode.txt

# Parameters for sbatch
Output=DeleteMe.txt
Ntasks=1
MemPerCpu=100 # memory requirement in MB.
Time=10  # in minutes. Set a limit on the total run time of the job.
JobName="RmUserTmp${RANDOM}${RANDOM}"

# Check for the existence of the produced files in the working directory. If they already exist, exit the script. 
[[ -f ${EmptyTmp} ]] && { echo "${EmptyTmp} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2; exit 1; }
[[ -f ${AvailNodes} ]] && { echo "${AvailNodes} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2; exit 1; }
[[ -f ${Output} ]] && { echo "${Output} exists in ${PWD}. Please delete, rename or move the file to proceed." >&2; exit 1; }


# Check whether SLURM manager is installed on the system.
command -v sinfo &>/dev/null || { echo "SLURM is required to run this script, but is not currently installed. Please ask the administrator for help." >&2; exit 1; }

# Remove produced files upon exit or interrupt.
trap "sleep 2; rm -f $EmptyTmp $AvailNodes $Output; exit 1;" SIGINT
trap "rm -f $EmptyTmp $AvailNodes $Output" EXIT

# Find all the nodes which do not have enough available memory.
FullMemNode=$(sinfo -O NodeAddr,Partition,AllocMem,Memory | sed 's/ \+/ /g;s/*//g' | awk -v mem=${MemPerCpu} 'NR>1 && ($4-$3)<mem {print $1}')

# Also, find all the nodes currently in use by the user. 
UserNode=$(squeue | awk -v user="$USER" '$4==user {print $8}')

# Combine the two variables to a new one, containing all the unavailable nodes.
# The goal is to prevent running a job on any of these nodes.
UnavailNode=$(echo ${FullMemNode}" "${UserNode} | sed 's/ /\n/g' | sort -u | tr "\n" "|" | sed 's/|$//g;s/^|//g')

# Find all the available nodes and export them.
if [[ -z ${UnavailNode} ]] 
then 
    sinfo --Node | awk '$4 ~ /mix|idle/ {print $1, $3}' | sed 's/*$//g' > $AvailNodes
else 
    sinfo --Node | awk -v node=${UnavailNode} '$1!=node && $4 ~ /mix|idle/ {print $1, $3}' 2> /dev/null | sed 's/*$//g' > $AvailNodes
    echo
    echo "User directories in /tmp of ${UnavailNode//|/,} will NOT be deleted."
    echo
fi

# If there are no available nodes, exit the script
[[ ! -s ${AvailNodes} ]] && { echo "There are no available nodes. No files were deleted. Please try again later." >&2; exit 1; }

# Delete user's directories in /tmp by running an sbatch job on each available node.
while read -r node partition
do
cat > ${EmptyTmp} <<EOF
#!/bin/bash
#SBATCH --partition=${partition}
#SBATCH --nodelist=${node}
#SBATCH --ntasks=${Ntasks}
#SBATCH --mem=${MemPerCpu}M
#SBATCH --output=${Output}
#SBATCH --time=${Time}
#SBATCH --job-name="${JobName}"
EOF

cat >> ${EmptyTmp} <<"EOF"

find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + &
wait

exit 0
EOF
   sbatch ${EmptyTmp}
   # For sbatch jobs, the exit code that is captured is the output of the batch script. 
   if [ $? -eq 0 ]
   then
       echo "User directories in /tmp of ${partition} ${node} have been succesfully deleted."
   else
       echo "User directories in /tmp of ${partition} ${node} have NOT been deleted. Please try again later."
   fi
   echo
   sleep 1
done < $AvailNodes


# Delete user /tmp directories in current node.
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + 

# Cancel any remaining jobs.
scancel --jobname ${JobName}

sleep 1

<<EOF
FINAL NOTE:
This script relies on some assumptions which were all true during testing.
1) Each node (from all partitions) should have a unique name.
2) Node names should have only one non alphanumeric character, the dash (-).
3) Slurm version should be 16.05.9.
4) Backfill should be the scheduler type used.

A change to any of the above assumptions could cause the script to collapse.

EOF

exit 0
