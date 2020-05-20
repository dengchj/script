#!/bin/bash

#初始化全局变量
if [[ -z ${__ULOG_UUID__} ]]; then
    __ULOG_UUID__=$(uuidgen -r)
    export __ULOG_UUID__
fi

current_dir=`dirname ${BASH_SOURCE[0]}`

#脚本log函数
#可以通过管道使用!
#例子:
# echo "Hello world from stdin" | ulog 3 -
# echo "Hello world from stdin to stderr" | ulog - 3 -
# ulog - 3 "Hello World to stderr"
# ulog 3 "Hello World normal"

function ulog () {
    if [[ -z ${__ULOG_UUID__} ]]; then
        __ULOG_UUID__=$(uuidgen -r)
        export __ULOG_UUID__
    fi
    local uLogPath='/var/log/wiwo'
    #确保log目录存在
    [[ ! -d $uLogPath ]] && mkdir -p $uLogPath
    local uLogFilename="${uLogPath}/UDB-script.log"
    local program_name=$(basename $0)

    local std_err=0
    [[ $1 = '-' ]] && shift && std_err=1
    if [[ $# -lt 2 ]] ; then
        echo "Usage : ${FUNCNAME[0]} [send_to_stderr '-' for yes] loglevel[1-DEBUG 2-WARNING 3-ERROR] logmessage" >&2
        echo "Eg : ${FUNCNAME[0]} - 2 \"debug message\"" >&2
        return 0
    fi
    local log_level
    case $1 in
    1)
        log_level=DEBUG
        ;;
    2)
        log_level=WARNING
        ;;
    3)
        log_level=ERROR
        ;;
    *)
        echo "loglevel map is 1-DEBUG 2-WARNING 3-ERROR other values is invalid" >&2
        return 0
        ;;
    esac
    local ppid=$(ps -o ppid= $$)
    local log_component="${program_name}($$)"
    local read_from_stdin=0
    if [[ $# -eq 2 && $2 == "-" ]]; then
        read_from_stdin=1
    fi
    (
        if [[ ${read_from_stdin} -eq 1 ]]; then
            cat
        else
            echo "${@:2}"
        fi
    ) | \
    (
        echo -n "${log_component}: "
        if [[ ${std_err} -eq 1 ]]; then
            tee /dev/stderr
        else
            cat
        fi
    ) | \
    ${current_dir}/logger.sh ${log_level} ${__ULOG_UUID__} >> ${uLogFilename}
    return 0
}

function log_args() {
    local args_str=""
    for arg in "${BASH_ARGV[@]}"; do
        args_str="'${arg}' ${args_str}"
    done
    ulog 1 "'$0'" "${args_str}"
}

function get_log_uuid() {
    if [[ -z ${__ULOG_UUID__} ]]; then
        __ULOG_UUID__=$(uuidgen -r)
        export __ULOG_UUID__
    fi
    echo "${__ULOG_UUID__}"
}

# run command with ulog all outputs
function ulog_warn_run() {
    "$@" >> >(ulog 2 -) 2>&1
}

function ulog_error_run() {
    "$@" >> >(ulog 3 -) 2>&1
}

# 检查本地登陆是否需要密码的，暂时用于mysql-5.7
# 如果后续版本不需要密码的，直接修改这里
# 提供一个参数，脚本目录或者实例目录
# return 0 需要密码, non-0不需要密码
function need_login_password() {
    [[ ! "$1" = *5.7* ]]
}

# 采样校验和方法, 更好的方法是再取中间一段100M
# 取头部100M ， 尾部100M 数据计算 md5
# 对于小于200M 的直接计算
function udb_checksum() {
    local f=$1
    if [[ ! -f "$f" ]] ; then
        exit 10
    fi
    local size
    # get blocks, by default 512 byte
    size=$(stat -c %b "$f")
    # 如果小于200M， 400*1024 blocks
    if [[ "$size" -lt 409600 ]] ;then
        md5sum "$f" | awk '{print $1}'
        return 0
    fi
    # 分段数据计算
    ( head -c 100M "$f" && tail -c 100M "$f" ) | md5sum | awk '{print $1}'
}

# 校验使用 udb_checksum 计算的 md5 值是否正确
# 匹配退出0，否则退出非0
function check_udb_checksum() {
    if [[ $# -lt 2 ]] || [[ ! -f $1 ]]; then
        exit 1
    fi
    local f=$1
    local sum=$2
    local size md5
    size=$(stat -c %b "$f")
    if [[ "$size" -lt 409600 ]] ;then
        md5=$(md5sum "$f" | awk '{print $1}')
    else
        # 分段数据计算
        md5=$(head -c 100M "$f" && tail -c 100M "$f" | md5sum | awk '{print $1}')
    fi
    [[ "$md5" = "$sum" ]]
}

# 将内容打入标准错误流
function elog() {
    echo "$@" >&2
}

