#!/bin/bash

destbucket=$1
backupfile_real_full_path=$2
backupfile=$3

python ./upload_to_umstor.py $destbucket $backupfile_real_full_path $backupfile

result=$?
if [[ ${result} -eq 0 ]]; then
    exit 0
else
    exit 1
fi