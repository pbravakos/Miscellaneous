#!/usr/bin/env bash

<<EOF

IMPORTANT NOTE:

This script relies on some assumptions which were all true during testing.
1) Each node (on every partition) should have a unique name.
2) Bash version should be 4.4.12.
3) Slurm version should be 16.05.9.

A change to any of the above assumptions could cause the script to collapse.

Also, Backfill was set as the scheduler type during testing. 
A change to the scheduler type does not break the code but, 
could cause the exclusion of some nodes. 
Moreover, Basic was set as the priority type during testing. 
Change of the priority type to a more sophisticated one (i.e. multifactor) 
could also potentially cause the exclusion of some or all the nodes.

Minor note:
The --immediate sbatch directive was not functioning as expected during testing and decided not to use it.
Had it been used, the script could have been slightly less complex (and milliseconds faster!).

EOF

# Create a help function.
show_help () {
    cat <<END
    
Usage: bash ${0##*/} [-h] [-s <string>] [-m <integer>] [-t <integer>]
   	
Submit an sbatch job to each available compute node not currently in use by $USER, to remove user directories from /tmp.

 -h	Display this help and exit
 -s	SLURM script file name. Default is "RmUserTmp.sh".This file is created in the working directory and deleted automatically.
 -m	Memory limit in MB for each sbatch job submitted to SLURM. Integer values should be between 10-1000. Default is 100.
 -t	Time limit in minutes for each sbatch job submitted to SLURM. Integer values should be between 1-100. Default is 10.
    
ATTENTION!
It is possible that not all nodes will be accessible, and thus not all user /tmp directories will be removed. 
For that reason, it is recommended to run this script frequently at different time periods.

END
}

# Use getopts to create some options that users can set.
# OPTIND Holds the index to the next argument to be processed.
# It is initially set to 1, and needs to be re-set to 1 if we want to parse anything again with getopts.
OPTIND=1 
# getopts sets an exit status of FALSE when there's nothing left to parse.
# It parses the positional parameters of the current shell or function by default (which means it parses "$@").
# OPTARG is set to any argument for an option found by getopts.
while getopts ':m:t:s:h' OPTION
do
    case $OPTION in
    	m) 
    	   JobMem=$OPTARG
    	   if [[ $JobMem =~ ^[0-9]+$  && $JobMem -le 1000 && $JobMem -ge 10 ]]; then
    	       echo "SLURM Job Memory was set to ${JobMem}MB"
    	       echo
    	   else
    	       echo "Memory (-m) should be given as an integer between 10 and 1000" >&2
    	       show_help >&2
    	       exit 1
    	    fi
           ;;
           
        t) 
           Time="$OPTARG"
           if [[ $Time =~ ^[0-9]+$  && $Time -le 100 && $Time -ge 1 ]]; then
    	       echo "SLURM Time Limit was set to ${Time}min"
    	       echo
    	   else
    	       echo "Time limit (-t) should be given as an integer between 1 and 100" >&2
    	       show_help >&2
    	       exit 1
    	   fi
           ;;
        
        s) 
           EmptyTmp="$OPTARG"
           echo "SLURM bash script file name was set to be \"${EmptyTmp}\""
           echo
           ;;
           
        h) 
           show_help >&2
           exit 0
           ;;
           
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            echo "To check valid options use -h" >&2
            echo >&2
           ;;
           
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help >&2
            exit 1
            ;;
      		
    esac
done

# If getopts exits with a return value greater than zero. OPTIND is set to the index of the first non-option argument
# Shift command removes all the options that have been parsed by getopts from the parameters list, and so after that point, $1 will refer to the first non-option argument passed to the script. 
# In our case we ignore all these arguments.
shift "$(($OPTIND - 1))"

# INITIAL PARAMETERS
# SLURM bash script file 
EmptyTmp=${EmptyTmp:-RmUserTmp.sh}
# Parameters for sbatch
Ntasks=1
JobMem=${JobMem:-100} # memory requirement in MB.
Time=${Time:-10} # in minutes. Set a limit on the total run time of each submitted job.
JobName="RmUserTmp"

# Check whether SLURM manager is installed on the system.
command -v sinfo &>/dev/null \
|| { echo "SLURM is required to run this script, but is not currently installed. Please ask the administrator for help." >&2; exit 1; }

# Check for the existence of any file with the same name as the produced bash script. If such a file exists, exit the script. 
[[ -f ${EmptyTmp} ]] && { echo "${EmptyTmp} exists in ${PWD}. Please either rename the existing file or set the -s option to a different file name." >&2; exit 1; }

# Remove the produced bash script upon exit or any other interrupt.
cleanup="rm -f $EmptyTmp"
trap 'echo; echo Terminating. Please wait; $cleanup; scancel --quiet ${AllJobIDs} 2>/dev/null; exit;' ABRT INT QUIT
trap '$cleanup' EXIT HUP

# Create a new variable with all the nodes which do not have enough available memory.
FullMemNode=$(sinfo -O NodeAddr,Partition,AllocMem,Memory | sed 's/ \+/ /g;s/*//g' \
| awk -v mem=${JobMem} 'NR>1 && ($4-$3)<mem {print "^"$1"$"}')

# Also, create another variable with all the nodes currently in use by the user.
UserNode=$(squeue -o "%.u %N %.t" | awk -v user="$USER" '$1==user && $3~"^R$|^CG$" {print "^"$2"$"}')

# Combine the two variables to a new one, containing all the unavailable nodes.
# The goal is to prevent running a job on any of these nodes.
NewLine=$'\n'
UnavailNode=$(echo "${FullMemNode}${NewLine}${UserNode}" | sort -u \
| tr "\n" "|" | sed 's/|$//g;s/^|//g')

# Find all the available nodes and export them to an array.
# Each element of the array will have the name of the node and the name of the partition.
if [[ -z ${UnavailNode} ]] 
then 
    mapfile -t AvailNodes < <(sinfo --Node | awk '$4 ~ /mix|idle/ {print $1, $3}' | sed 's/*$//g')
else 
    mapfile -t AvailNodes < <(sinfo --Node \
    | awk -v node=${UnavailNode} '$1!~node && $4 ~ /mix|idle/ {print $1, $3}' 2> /dev/null \
    | sed 's/*$//g')
    echo
    echo "User directories in /tmp of ${UnavailNode//|/,} will NOT be deleted." | sed -E 's/\^|\$//g'
    echo
fi

# If there are no available nodes, exit the script
[[ -z ${AvailNodes} ]] \
&& { echo "There are no available nodes. No files were deleted. Please try again later." >&2; exit 1; }

# Create the SLURM bash input file. 
cat > ${EmptyTmp} <<"EOF"
#!/bin/bash
#find /tmp -maxdepth 1 -user "$USER" -exec sh -c "rm -fr {} || exit 1" \;
find /tmp -maxdepth 1 -mmin +1 -user "$USER" -exec rm -fr {} + &
wait 
exit 0
EOF

# Remove user's directories in /tmp by running an sbatch job on each available node.
AllJobIDs=""
while read -r node partition
do
    NewJobID=$(sbatch --partition="${partition}" \
                      --nodelist="${node}" \
                      --ntasks="${Ntasks}" \
                      --mem="${JobMem}M" \
                      --output=/dev/null \
                      --time="${Time}" \
                      --job-name="${JobName}" \
                      "${EmptyTmp}" 2> /dev/null)
    if [[ $? -eq 0 ]]; then
        NewJobID=$(echo ${NewJobID} | grep -Eo "[0-9]+$")
        AllJobIDs=${AllJobIDs}${NewJobID}" "
        echo "User directories in /tmp of ${partition} ${node} have been deleted."
    else
        echo "User directories in /tmp of ${partition} ${node} have NOT been deleted. Please try again later."
    fi
    echo
done < <(for i in "${AvailNodes[@]}"; do echo $i; done)

# Remove user /tmp directories in current node.
find /tmp -maxdepth 1 -mmin +15 -user "$USER" -exec rm -fr {} + 

echo
echo "Please wait"
echo
sleep 2

# Find all the jobs submitted by this script which do NOT currently have a runnning status and cancel those jobs.
JobsPattern=$(echo ${AllJobIDs// /|} | sed 's/|$//')
AllJobIDs=$(squeue -o'%.i %.u %.t' | awk -v job="${JobsPattern}" 'BEGIN {ORS=" "} $2=="${USER}" && $3!="R" && $1~job {print $1}')
scancel --quiet ${AllJobIDs} 2> /dev/null

exit 0
