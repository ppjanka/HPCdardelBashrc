#!/usr/bin/env bash

echo "Processing bash_profile.."

# find which machine we are running on
if [ "${HOSTNAME::3}" == 'uan' ]; then
    machine='dardel'
elif [ "${HOSTNAME::9}" == 'tetralith' ]; then
    machine='tetralith'
else
    machine='unknown'
fi
echo " - running on machine: $machine"

. ~/.secret_pars # defines variables that should not be shared openly here, e.g., the project name MY_PROJECT

# simple everyday aliases
alias ls='ls --color'
alias la='ls -a'
alias ll='ls -l'
ghis () {
    local pattern=$(printf '|%s' $@)
    pattern=${pattern:1}
    history | grep -E "$pattern" | tail
}

# location shortcuts
case $machine in
    'dardel')    alias cdp='cd /cfs/klemming/projects/snic/${MY_PROJECT}/$USER'; \
                 alias cds='cd /cfs/klemming/scratch/${USER:0:1}/$USER'; \
                 alias cdn='cd /cfs/klemming/nobackup/${USER:0:1}/$USER';;
    'tetralith') alias cdp='cd /proj/${MY_PROJECT}/users/$USER';;
esac

# check available quota
if [ $machine == 'dardel' ]; then
    checkquota () {
        echo -e "\nProject quota for ${MY_PROJECT}:"
        lfs quota -hp `stat -c "%g" /cfs/klemming/projects/snic/${MY_PROJECT}` /cfs/klemming
        echo -e "\nUser quota for ${USER} (id $UID):"
        lfs quota -hp $UID /cfs/klemming
        echo
    }
elif [ $machine == 'tetralith' ]; then
    alias checkquota='snicquota'
fi

# slurm commands
# show the current user's slurm queue
alias sq='squeue -u $USER -o "%.9i %.4P %.13j %.4t %.21S %.10M %.10l %.6D %R"'
# clear the queue of jobs with (DependencyNeverSatisfied)
sclear () {
    sq | awk '{if ($9 == "(DependencyNeverSatisfied)") print "scancel "$1}' | bash
}
# show final lines of the slurm output files in the current directory
sl () {
    # parse arguments
    declare -i tail_lines=10 # number of tail lines to display
    declare -i file_from_last=0 # will read nth file from the most recent
    local sort_arg='-tr' # arguments to be passed to ls *slurm*.out, default: chronological
    local view_command='tail'
    for (( i=1; i<=$#; i++ )); do
        case ${!i} in
            '-n') tail_lines=${@:$((i+1)):1}; ((i++));;
            '-nf') file_from_last=${@:$((i+1)):1}; ((i++));;
            '-h') view_command='head';;
            *) echo "[$FUNCNAME] Command line option unrecognised: \"${!i}\", ignored."
        esac
    done
    # search for the desired slurm*.out file
    declare -a filenames=($(ls ${sort_arg} slurm*.out 2> /dev/null))
    if [ ${#filenames[@]} -eq 0 ]; then
        echo "[$FUNCNAME] No slurm*.out files available."
    elif [ ${#filenames[@]} -lt ${file_from_last} ]; then
        echo "[$FUNCNAME] Not enough slurm*.out files to satisfy the -n parameter (no. of file from last)."
    else
        local filename=${filenames[${#filenames[@]}-${file_from_last}-1]}
        # print out the desired output
        less $filename | ${view_command} -n ${tail_lines}
    fi
}
# display job details (memory, CPUtime, etc.) for a selected slurm*.out file
sf () {
    # parse arguments
    declare -i file_from_last=0 # will read nth file from the most recent
    declare show_sacct=false # show additional data while job is running
    for (( i=1; i<=$#; i++ )); do
        case ${!i} in
            '-nf') file_from_last=${@:$((i+1)):1}; ((i++));;
            '-a') show_sacct=true;;
            *) echo "[$FUNCNAME] Command line option unrecognised: \"${!i}\", ignored."
        esac
    done
    # search for the desired slurm*.out file
    declare -a filenames=($(ls ${sort_arg} slurm*.out 2> /dev/null))
    if [ ${#filenames[@]} -eq 0 ]; then
        echo "[$FUNCNAME] No slurm*.out files available."
    elif [ ${#filenames[@]} -lt ${file_from_last} ]; then
        echo "[$FUNCNAME] Not enough slurm*.out files to satisfy the -n parameter (no. of file from last)."
    else
        local filename=${filenames[${#filenames[@]}-${file_from_last}-1]}
        local jobid=$(basename -s .out $filename)
        jobid=${jobid:6}
        # print out the desired output
        seff $jobid
        if [ $show_sacct ]; then
            scontrol show jobid -dd $jobid
        fi
    fi
}

# Start the SSH agent and prompt user to provide the passphrase to the Git key
#  - note: only processes RSA keys here (easy to adjust if you need other algorithms)
start_ssh () {
    eval $(ssh-agent -s)
    for key in $@; do
        { # try: prompt user for passphrase
            ssh-add $key
            # clean the clipboard to avoid re-pasting the passphrase by mistake
            #echo | xclip -selection c # no xclip on Dardel
        } || { # catch: aborted
            echo " - ssh-key \"${key}\" init aborted."
        }
    done
}
start_ssh $(ls ~/.ssh/*rsa* 2> /dev/null | grep -v '.pub')

echo "bash_profile processing done."
