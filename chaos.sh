#!/bin/bash

if [ "$#" -eq 0 ]
then
    echo "chaos.sh <pod-name-prefix> [-t seconds] [-e]"
    echo "    pod-name-prefix is the beginning of the name of the pods to terminate"
    echo "    -t interval in seconds"
    echo "    -e execute pod termination"
    exit 1
fi

time_sec=60
execute=0

# Get the name of the pods to delete

if [[ "$#" -gt 0 ]]
then
    pod_name_prefix=$1
    shift
fi

# Parse the optional parameters

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t) time_sec="$2"; shift ;;
        -e) execute=1; ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check that a numerical value has been provided for the cycle time

if [[ ! $time_sec =~ ^[0-9]+$ ]]
then
    echo "chaos.sh <pod-name-prefix> [-t seconds] [-e]"
    echo "    pod-name-prefix is the beginning of the name of the pods to terminate"
    echo "    -t interval in seconds (non-negative number)"
    echo "    -e execute pod termination"
    exit 1
fi

echo "Terminate pods beginning with '"$pod_name_prefix"', every "$time_sec" seconds. Execute termination: "$execute""

#  Choose one pod out of the running pods

while true; do
    pod_to_delete=`kubectl get pods \
      --field-selector=status.phase=Running \
      -o  'jsonpath={.items[*].metadata.name}' \
    | tr " " "\n"  \
    | grep "^$pod_name_prefix*" \
    | shuf\
    | head -n 1`

    if [ -z "$pod_to_delete" ]
    then
        echo "Unable to find any pods beginning with '$pod_name_prefix'"
        exit 1
    fi

# Delete the pod, or issue a notice if it is dry run

    if  [ $execute -eq 1 ]
    then
        echo "Will terminate '"$pod_to_delete"'"
        kubectl delete pod $pod_to_delete
    else
        echo "Would have terminated pod '"$pod_to_delete"', except this is a dry run. Include -e flag to actually perform termination."
    fi

    sleep "$time_sec"
done
