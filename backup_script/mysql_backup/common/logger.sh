#!/bin/bash

log_level=$1
log_uuid=$2

log_level_postprocess=$(echo "${log_level}" | tr "[:lower:]" "[:upper:]")

case ${log_level_postprocess} in
ERROR)
    log_level_code=0
    ;;
WARNING)
    log_level_code=1
    ;;
INFO)
    log_level_code=2
    ;;
DEBUG)
    log_level_code=3
    ;;
*)
    log_level_postprocess="INFO"
    log_level_code=2
    ;;
esac

if [[ -z ${log_uuid} ]]; then
    log_uuid=$(uuidgen -r)
fi

#这里是为了防止截断行里面的空格, 所以设置IFS为空
while IFS= read -r line; do
    log_time=$(date +"%FT%T.%2N%:z")
    echo -e "[${log_time}][${log_level_postprocess}] [${log_uuid}] ${line}"
done
