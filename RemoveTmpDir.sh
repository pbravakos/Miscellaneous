#!/usr/bin/env bash

show_help () {
    cat <<END
    
Usage: bash ${0##*/} [-h] [-m <integer>] [-t <integer>] [-o <string>] [-s <string>]
   	
Removes user directories from /tmp for each available node not currently in use by $USER.
 -h	Display this help and exit
 -m	Memory limit in MB for each sbatch job submitted to SLURM. Values should be between 10-1000. Default is 100.
 -t	Time limit in minutes for each sbatch job submitted to SLURM. Values should be between 1-100. Default is 10.
 -o	SLURM job output file name. Default is "RmUserTmp.out".This file is created in working directory and deleted automatically.
 -s	SLURM script file name. Default is "RmUserTmp.sh".This file is created in working directory and deleted automatically.
    
ATTENTION!
It is possible that not all nodes will be accessible, and thus not all user /tmp directories will be removed. 
It is recommended to run this script frequently at different time periods.

END
}


# OPTIND Holds the index to the next argument to be processed.
# It is initially set to 1, and needs to be re-set to 1 if we want to parse anything again with getopts.
OPTIND=1 
# getopts sets an exit status of FALSE when there's nothing left to parse.
# It parses the positional parameters of the current shell or function by default (which means it parses "$@").
# OPTARG is set to any argument for an option found by getopts.
while getopts ':m:t:o:s:h' OPTION
do
    case $OPTION in
    	m) 
    	   JobMem=$OPTARG
    	   if [[ $JobMem -le 1000 && $JobMem -ge 10 ]]; then
    	       echo "SLURM Job Memory was set to ${JobMem}MB" >&2
    	       echo >&2
    	   else
    	       echo "Memory (-m) should be given as an integer between 10 and 1000" >&2
    	       show_help >&2
    	       exit 1
    	    fi
           ;;
           
        t) 
           Time="$OPTARG"
           if [[ $Time -le 100 && $Time -ge 1 ]]; then
    	       echo "SLURM Time Limit was set to ${Time}min" >&2
    	       echo >&2
    	   else
    	       echo "Time limit (-t) should be given as an integer between 1 and 100" >&2
    	       show_help >&2
    	       exit 1
    	   fi
           ;;
           
        o) 
           JobOut="$OPTARG"
           echo "SLURM output file name was set to be \"${JobOut}\"" >&2
           echo >&2
           ;;
           
        s) 
           EmptyTmp="$OPTARG"
           echo "SLURM bash script file name was set to be \"${EmptyTmp}\"" >&2
           echo >&2
           ;;
           
        h) 
           show_help >&2
           exit 0
           ;;
           
        \?) 
            echo "Invalid option: -$OPTARG" >&2
            echo "To check valid options try -h" >&2
            echo "Script will run with set options" >&2
            echo >&2
           ;;
           
        :)
      		echo "Option -$OPTARG requires an argument." >&2
      		show_help >&2
      		exit 1
      		;;
      		
    esac
done

shift $(($OPTIND - 1))

# INITIAL PARAMETERS
# SLURM bash script file 
EmptyTmp=${EmptyTmp:-RmUserTmp.sh}
# Parameters for sbatch
JobOut=${JobOut:-RmUserTmp.out}
Ntasks=1
JobMem=${JobMem:-100} # memory requirement in MB.
Time=${Time:-10} # in minutes. Set a limit on the total run time of the job.
JobName="RmUserTmp${RANDOM}${RANDOM}"


# Check for the existence of the produced files in the working directory. If they already exist, exit the script. 
[[ -f ${EmptyTmp} ]] && { echo "${EmptyTmp} exists in ${PWD}. Please delete, rename or move the file." >&2; exit 1; }
[[ -f ${JobOut} ]] && { echo "${JobOut} exists in ${PWD}. Please delete, rename or move the file." >&2; exit 1; }


# Check whether SLURM manager is installed on the system.
command -v sinfo &>/dev/null \
|| { echo "SLURM is required to run this script, but is not currently installed. Please ask the administrator for help." >&2; exit 1; }

# Remove produced files upon exit or any other interrupt.
cleanup="rm -f $EmptyTmp $JobOut"
trap 'echo; echo Terminating. Please wait; sleep 2; $cleanup;' ABRT INT QUIT
trap '$cleanup' EXIT HUP

# Create a new variable with all the nodes which do not have enough available memory.
FullMemNode=$(sinfo -O NodeAddr,Partition,AllocMem,Memory | sed 's/ \+/ /g;s/*//g' \
| awk -v mem=${JobMem} 'NR>1 && ($4-$3)<mem {print "^"$1"$"}')

# Also, create another variable with all the nodes currently in use by the user. 
UserNode=$(squeue | awk -v user="$USER" '$4==user {print "^"$8"$"}')

# Combine the two variables to a new one, containing all the unavailable nodes.
# The goal is to prevent running a job on any of these nodes.
UnavailNode=$(echo ${FullMemNode}" "${UserNode} | sed 's/ /\n/g' | sort -u \
| tr "\n" "|" | sed 's/|$//g;s/^|//g')

# Find all the available nodes and export them.
if [[ -z ${UnavailNode} ]] 
then 
    AvailNodes=$(sinfo --Node | awk '$4 ~ /mix|idle/ {print $1, $3}' | sed 's/*$//g')
else 
    AvailNodes=$(sinfo --Node | awk -v node=${UnavailNode} '$1!~node && $4 ~ /mix|idle/ {print $1, $3}' 2> /dev/null \
    | sed 's/*$//g')
    echo
    echo "User directories in /tmp of ${UnavailNode//|/,} will NOT be deleted." | sed -E 's/\^|\$//g'
    echo
fi

# If there are no available nodes, exit the script
[[ -z ${AvailNodes} ]] \
&& { echo "There are no available nodes. No files were deleted. Please try again later." >&2; exit 1; }

# Remove user's directories in /tmp by running an sbatch job on each available node.
while read -r node partition
do
cat > ${EmptyTmp} <<EOF
#!/bin/bash
#SBATCH --partition=${partition}
#SBATCH --nodelist=${node}
#SBATCH --ntasks=${Ntasks}
#SBATCH --mem=${JobMem}M
#SBATCH --output=${JobOut}
#SBATCH --time=${Time}
#SBATCH --job-name="${JobName}"
EOF

cat >> ${EmptyTmp} <<"EOF"

find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + &
wait

exit
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
done < <(echo -e "${AvailNodes[0]}")


# Remove user /tmp directories in current node.
find /tmp -maxdepth 1 -user "$USER" -exec rm -fr {} + 

# Cancel any remaining jobs.
scancel --jobname ${JobName}

sleep 1

<<EOF
FINAL NOTE:
This script relies on some assumptions which were all true during testing.
1) Each node (from all partitions) should have a unique name.
2) Node names should have only one non alphanumeric character, the dash (-).
3) Slurm version should be 16.05.9 and bash version 4.
4) Backfill should be the scheduler type used.

A change to any of the above assumptions could cause the script to collapse.

EOF

exit 0
