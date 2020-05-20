#！/bin/sh

src_dir=$1
destbucket=$2 # 目标存储桶

mydir=$(dirname "${BASH_SOURCE[0]}")

tmp_dir="/tmp/file_backup"
log_dir="/var/log/file_backup"
if [ ! -d "$tmp_dir" ]; then
    mkdir ${tmp_dir}
fi
if [ ! -d "$log_dir" ]; then
    mkdir ${log_dir}
fi

# 打包压缩
backupfile_real_full_path="${tmp_dir}/backup${(date +%Y%m%d)}.tar.gz"
tar -zcPvf ${backupfile_real_full_path} ${src_dir}

upload="$mydir/upload_backup.sh"
if [[ ! -f "$upload" ]] ; then
    exit 4
fi

# 上传
bash "$upload" "$destbucket" "$backupfile_real_full_path" "$(date +%Y/%m/%d)/linux_file/backup.tar.gz" 2>${log_dir}/err.log
upload_exit_code=$?
if [[ ${upload_exit_code} -ne 0 ]]; then
    exit ${upload_exit_code}
fi

# 删除超过10天的备份压缩文件
find ${tmp_dir}/ -mtime +10 -name "*.tar.gz" -exec rm -rf {} \;
