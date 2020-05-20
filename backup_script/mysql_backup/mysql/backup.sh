#!/bin/bash

#################################################################
# Brief: 1. 统一mysql的备份到一个脚本
#   2. 添加使用快照备份
#   3. 脚本改造符合linter
#   4. 各个版本使用软连接到此脚本，此脚本不直接调用
#   5. 使用尾部100M计算md5方法，对于大的备份文件计算md5对性能影响比较大
#   6. trick: /tmp/_udb_snapshot_backup_.list 列表中存在的dbid使用快照备份
# Author: xu.wu@ucloud.cn
# Date: 2018-12-27
#################################################################

mydir=$(dirname "${BASH_SOURCE[0]}")
common_dir="$mydir/../common"

# shellcheck source=/dev/null
source ${common_dir}/util.sh

# redirect all stderr to ulog
exec 2> >(ulog 3 -)

cleanup_commands=""
trap 'eval "${cleanup_commands}"' EXIT

log_args
function record_end() {
    ulog 1 SCRIPT END
}
cleanup_commands="record_end; ${cleanup_commands}"

function log_error() {
    if [[ $1 = '-' ]]; then
        shift
        echo "$@" >&2
    fi
    echo "$@" >> "${log_file}"
    ulog 3 "$@"
}

show_help() {
    echo "$0 programdir homedir dbid destbucket dbuser dbpassword backupfile backupdir backuprole [excludedbs] [excludetables] [is_forcedump]"
    echo "excludedbs like: db1|db2|db3"
    echo "exlucdetables like: db1.table1|db2.table2|db3.table3"
    echo "parameter not enough"
    exit 1
}

check_param() {
    if [ $# -lt 8 ]; then
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


check_param "$@"
programdir=$1 # $programdir/bin/mysqldump
homedir=$2 # dbdir="$homedir/$dbid", $dbdir/mysqld.sock, $dbdir/conf/my.cnf
dbid=$3
destbucket=$4 # 目标存储桶
user=$5
password=$6
backupfile=$7
backuprole=${8} # master端或slave端dump
excludedbs=${9}
excludetables=${10}
is_forcedump=${11:-0}

dbdir="$homedir/$dbid"

log_file=/tmp/${dbid}.backupinfo
backupfile_prefix=${backupfile%%.*}
meta_file="/tmp/${backupfile_prefix}.meta"

sockfile="$dbdir/mysqld.sock"
if [[ ! -S "$sockfile" ]] ; then
    log_error "Sock file $sockfile not exists."
    exit 5
fi
sqldump="${mydir}/generate_backup_data_stream_mysqldump.sh"

function get_backup_file_real_name() {
    if [[ -f ${meta_file} ]]; then
        local suffix
        # 使用 tr -d 会把中间的空格也去掉，xargs去掉两边的空格 (默认echo)
        suffix=$(grep -m 1 'suffix' "${meta_file}" | awk -F: '{print $2}' | xargs)
        if [[ -n ${suffix} ]]; then
            echo "${backupfile_prefix}.${suffix}"
            return 0
        fi
    fi
    echo "${backupfile}"
}

echo "Start Backup: $(date)" > "${log_file}"

function log_info() {
    echo "$@" >> "$log_file"
}

#导出表前先删除错误日志记录表
dump_error_log="/tmp/${dbid}_dump_error"
upload_error_log="/tmp/${dbid}.upload_error"
:>"${dump_error_log}"
:>"${upload_error_log}"

# 是否已经存在备份了
has_backup_file_existed=0
if [[ -f ${meta_file} ]]; then
    backupfile_real_name=$(get_backup_file_real_name)
    backupfile_real_full_path="/tmp/${backupfile_real_name}"
    if [[ -e "${backupfile_real_full_path}" ]]; then
        has_backup_file_existed=1
    fi
fi

common_opt=("${programdir}" "${homedir}" "${dbid}" "${user}" "${password}")

md5file="/tmp/${backupfile_prefix}.md5"
sizefile="/tmp/${backupfile_prefix}.size"

if [[ ${has_backup_file_existed} -eq 0 ]]; then
    # 清理先前留下的冷备文件, 节省备份空间
    find /tmp/ -name "${dbid}_backup*" -delete
    find /tmp/ -name "${dbid}_routine_backup*" -delete  # 现在不再存在这种文件
    find /tmp/ -name "${dbid}*.backupinfo*" -mtime +3 -delete

    stage_file="/tmp/${backupfile_prefix}.dump_data"
    function remove_stage_file() {
        [[ -f "${stage_file}" ]] && rm "${stage_file}"
    }
    cleanup_commands="remove_stage_file; ${cleanup_commands}"

    ulog 1 "Start backup for $dbid"
    # 准备数据阶段，可能是sqldump 也可能是 snapshot
    # 使用pv进行限速，如果pv不存在则使用cat
    limit_rate='pv -q -L 60m'
    if ! type pv >/dev/null 2>&2 ; then
        limit_rate='cat'
    fi
    {
        bash "$sqldump" "${common_opt[@]}" "${backuprole}" "${excludedbs}" "${excludetables}" "${is_forcedump}"
    } 2> >(tee -a "$log_file" | cat >&2 ) | $limit_rate | \
        tee >(md5sum | awk '{print $1}' >"$md5file") | \
        pigz -c -p 4 > "${stage_file}"

    # 对于sqldump 不再判断 Dump completed 是否出现在文件的最后
    # 只根据脚本返回值判断
    dump_exit_code=${PIPESTATUS[0]}
    compress_exit_code=${PIPESTATUS[1]}

    if [[ ${dump_exit_code} -ne 0 ]] || [[ ${compress_exit_code} -ne 0 ]] ; then
        log_error "Generate backup data stream error. dump: $dump_exit_code , compress: $compress_exit_code."
        #写下面这句话，是因为check slow backup要搜索这个字符串作为dump error的标准。。。
        log_error "!!DUMP DATA ERROR!!"
        # 对于dump失败的需要清理文件
        ulog 1 "remove $stage_file for imcomplete backup."
        rm "$stage_file"
        exit "${dump_exit_code}"
    fi
    #TODO: 以后suffix由generate_backup_data_stream入口文件生成,
    #然后这里就要从文件中读取, snapshot和mysqldump的后缀是不一样的, 现在暂时写死
    echo "suffix: sql.gz" > "${meta_file}"
    backupfile_real_name=$(get_backup_file_real_name)
    backupfile_real_full_path="/tmp/${backupfile_real_name}"
    #这步执行完说明dump数据已经成功了
    mv "${stage_file}" "${backupfile_real_full_path}"
fi

#开始做上传
# 使用通用的上传脚本
upload="$common_dir/upload_backup.sh"
if [[ ! -f "$upload" ]] ; then
    ulog 3 "upload tool: $upload not found."
    exit 4
fi

# 后面使用通用的upload_backup 替换
obj_name="$(date +%Y/%m/%d)/mysql_linux/$backupfile.sql.gz"
bash "$upload" "$destbucket" "$backupfile_real_full_path" "$obj_name"
upload_exit_code=$?
if [[ ${upload_exit_code} -ne 0 ]]; then
    # OLD: 写下面这句话，是因为check slow backup要搜索这个字符串作为upload error的标准。。。
    # 新的备份慢检查脚本不再依赖这句话
    log_error "!!UPLOAD ERROR!!"
    exit ${upload_exit_code}
fi

log_info "backup file success"

# 计算md5值, 取最后100M计算
if [[ ! -s "$md5file" ]] ; then
    ulog 1 "re-calc md5sum..."
    md5sum "${backupfile_real_full_path}" | awk '{print $1}' > "$md5file"
fi
md5_value=$(< "$md5file" )

stat -c %s "${backupfile_real_full_path}" > "$sizefile"
filesize=$(< "$sizefile" )

# 实际上这里的输出并不会被使用
echo "${filesize},${md5_value}"
exit 0
