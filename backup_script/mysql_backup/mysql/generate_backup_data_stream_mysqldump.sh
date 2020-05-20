#!/bin/bash

############################################3
# Brief: mysql 各个版本兼容
# Author: xu.wu@ucloud.cn
# Date: 2018-12-27
############################################3

show_help() {
    echo "$0 programdir homedir dbid dbuser dbpassword backuprole [excludedbs] [excludetables] [is_forcedump]" >&2
    echo "excludedbs like: db1|db2|db3" >&2
    echo "exlucdetables like: db1.table1|db2.table2|db3.table3" >&2
    exit 1
}

check_param() {
    if [ $# -lt 6 ]; then
        show_help
    fi
    if [ ! -d "$1" ]; then
        echo "programdir $1 does not exists" >&2
        show_help
    fi
    if [ ! -f "$2/$3/conf/my.cnf" ]; then
        echo "config file $2/$3/conf/my.cnf does not exists" >&2
        show_help
    fi
}

function is_mariadb() {
     grep -q -i 'mariadb' <<< "$programdir"
}

check_param "$@"
programdir=$1
homedir=$2
dbid=$3
user=$4
password=$5
backuprole=$6
sockfile=$homedir/$dbid/mysqld.sock

excludedbs=${7}
excludetables=${8}
is_forcedump=${9:-0}
if [[ $is_forcedump -gt 0 ]]; then
    force_dump="--force"
fi

# 检查进程是否在运行

_mydir=$(dirname "${BASH_SOURCE[0]}")

# shellcheck source=/dev/null
source "$_mydir/../common/util.sh"

cleanup_commands=""
trap 'eval "${cleanup_commands}"' EXIT

conn_opt=("-u${user}" "-S$sockfile" )
if need_login_password "$_mydir" ; then
    conn_opt+=("-p${password}")
fi

conn=("$programdir/bin/mysql" "-A" "-N" "-s" "${conn_opt[@]}" "--connect-timeout=1")

# 判断slowlog是否关闭，如果是关闭的保持现在的状态，如果没有关闭先关闭，备份完之后再打开
slow_log_open=$( "${conn[@]}"  -e "show global variables like 'slow_query_log'")
if [ "$slow_log_open" = 'ON' ];then
    # 暂时关闭slowlog
    "${conn[@]}" -e "SET GLOBAL slow_query_log = 0"
    function reset_slow_query_log() {
        "${conn[@]}" -e 'SET GLOBAL slow_query_log = 1'
    }
    cleanup_commands="reset_slow_query_log; ${cleanup_commands}"
fi

# 获取net_write_timeout值,并暂时设置为3600s
net_write_timeout=$( "${conn[@]}" -e "select @@net_write_timeout")
#reset net_write_timeout的值

if [[ -n "$net_write_timeout" ]] && [[ "$net_write_timeout" -lt 600 ]] ; then
    "${conn[@]}" -e "SET GLOBAL net_write_timeout=600"
    function reset_net_write_timeout() {
        "${conn[@]}" -e "SET GLOBAL net_write_timeout=${net_write_timeout}"
    }
    cleanup_commands="reset_net_write_timeout; ${cleanup_commands}"
fi

# 过滤被排除的database(确保不导出information_schema和performance_schema)
# FIXME 数据库名或者表名存在 | 会有问题, 比如有 a a|b 两个库，排除 a|b 会把a也排除掉
if [ -n "$excludedbs" ];then
    excludedbs="$excludedbs|information_schema|performance_schema"
else
    excludedbs="information_schema|performance_schema"
fi

dblist=$( "${conn[@]}" -e "SHOW DATABASES" | awk '{ print $0}' | grep -E -vw ${excludedbs} | tr '\n' " ")

if [ -z "$dblist" ];then
    echo "empty dblist" >&2
    exit 1
fi

dblist="--databases $dblist"

read -r -a db_arr <<< "$dblist"

read -r -a ignore_tables < <(tr '\|' ' ' <<< "$excludetables")
ignore_tables+=("mysql.slow_log" "mysql.innodb_index_stats" "mysql.innodb_table_stats" "mysql.slave_master_info" "mysql.slave_relay_log_info" "mysql.gtid_executed" "mysql.slave_worker_info")
# 拼接被排除的table
ignore_arr=()
for t in "${ignore_tables[@]}" ; do
    ignore_arr+=("--ignore-table=$t")
done

dump_opt=("--default-character-set=utf8mb4" "--max-allowed-packet=1G" )

# set gtid mode
v=$(dirname "$0" | xargs basename | cut -d'-' -f2 | sed 's/_lxc_lvm//g')
if [[ x"$v" > x"5.5" ]] && is_mariadb ; then
    gtid_mode_result=$( "${conn[@]}" -e "SELECT @@GLOBAL.gtid_mode")
    echo "GTID mode result: ${gtid_mode_result}" >&2
    if [[ $gtid_mode_result = "ON" ]]; then
        dump_opt+=( "--set-gtid-purged=ON" )
    else
        dump_opt+=("--set-gtid-purged=OFF")
    fi
fi

if [ "$backuprole" = slave ];then
    dump_opt+=("--dump-slave=2")
else
    dump_opt+=("--master-data=2")
fi

dump_opt+=("--single-transaction" "--quick" "-R" "--events")
if [[ -n "${force_dump}" ]] ; then
    dump_opt+=("${force_dump}")
fi

if ! "$programdir/bin/mysqldump" "${db_arr[@]}" "${ignore_arr[@]}" "${dump_opt[@]}" "${conn_opt[@]}" ; then
    echo "dump data for ${dbid} failed: force dump: $is_forcedump" >&2
    exit 11
fi
exit 0
