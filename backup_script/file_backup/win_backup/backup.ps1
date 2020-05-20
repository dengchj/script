[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()]
    [string]
    $UUID,

    [Parameter(Mandatory=$true, Position=0)]
    [String]
    $SourceDir,

    [Parameter(Position=1)]
    [String]
    $SourceFile, # 若不指定具体文件，则打包上传文件夹下所有文件

    [Parameter(Mandatory=$true, Position=2)]
    [String]
    $DestBucket,

    [Parameter(Mandatory=$true, Position=3)]
    [String]
    $BackupFileName
)

[string]$BaseDir = "C:\FileBackup"
[string]$LogDir = $BaseDir + "\Log"
. "$PSScriptRoot\ulog.ps1"

if (!$UUID) {
    $UUID = [System.Guid]::NewGuid().ToString()
}

Write-ULog -LogLevel Debug -UUID $UUID "$PSCommandPath -UUID $UUID -SourceDir $SourceDir -SourceFile $SourceFile -DestBucket $DestBucket -BackupFileName $BackupFileName"

Function CompressProcess
{
    param($SrcPath='',$DestFile='')
    try {
        # 如果本地备份文件已经存在, compress backup当中会去先删
        try {
            Write-ULog -LogLevel Info -UUID $UUID "Remove destination file first: $DestFile"
            Remove-Item -Path $DestFile

            # WinRAR版本, -m0表示不压缩, 因为SQLServer本身的备份已经压缩过了, 不需要再压缩; -r表示包含子目录
            # 详情请见winrar的online manual: http://acritum.com/software/manuals/winrar/ 
            Write-ULog -LogLevel Debug -UUID $UUID "C:\Program Files\WinRAR\Rar.exe a -r -m0 $DestFile $SrcPath"
            & "C:\Program Files\WinRAR\Rar.exe" a -r -m0 $DestFile $SrcPath

            # 用zip压缩版本, 先暂时注释
            #Add-Type -AssemblyName "System.IO.Compression.FileSystem"
            #[System.IO.Compression.ZipFile]::CreateFromDirectory($SrcPath, $DestFile, [System.IO.Compression.CompressionLevel]::NoCompression, $true);

        } finally {
            Write-ULog -LogLevel Debug -UUID $UUID "SCRIPT END"
        }
    } finally {
        Write-ULog -LogLevel Info -UUID $UUID "Compress Backup [END]"
    }
}

Function UploadProcess
{   
    param($DestBucket,$RemoteFile,$LocalFile)
    # 若是每天备份次数不多余一次，则可以建立基于日期的层级目录，格式如: BUCKET/2019/12/27/test.file
    [string]$Timestr = (Get-Date -Format 'yyyy/MM/dd/')
    [string]$DestObject = $Timestr+"win_file/"+$RemoteFile
    try {
        Write-ULog -LogLevel Debug -UUID $UUID "python $PSScriptRoot\upload_to_umstor.py $DestBucket $LocalFile $DestObject"
        python $PSScriptRoot\upload_to_umstor.py $DestBucket $LocalFile $DestObject
    } finally {
        Write-ULog -LogLevel Info -UUID $UUID "Upload Backup [END]"
    }
}

try {
    # 检查给出的文件目录是否存在
    if (! $(Test-Path -Path $SourceDir -PathType Container)) {
        Write-ULog -LogLevel Error -UUID $UUID "Source directory ( ${SourceDir} ) not exists"
        exit 1
    }
    [string]$SrcPath = "${SourceDir}\$SourceFile"
    if (! $SourceFile) { # 打包目录
        $SrcPath = "${SourceDir}"
        Write-ULog -LogLevel Debug -UUID $UUID "Pack directory"
    } else { # 打包文件
        if ($(Test-Path -Path $SrcPath -PathType Leaf)) {
            Write-ULog -LogLevel Debug -UUID $UUID "Pack file"
        }
        else {
            Write-ULog -LogLevel Error -UUID $UUID "Source file ( ${SrcPath} ) not exists"
        }
    }

    [string]$backupFileNamePrefix = [System.IO.Path]::GetFileNameWithoutExtension($BackupFileName)
    [string]$backupStateFile = "${LogDir}\${backupFileNamePrefix}.backup_state.txt"
    # By default redirection file encoding is UTF16-LE.  When the Golang reads the file, it cannot parse the string. So force to output it as ASCII
    "ON-GOING" | Out-File -Encoding "ASCII" $backupStateFile
    Write-ULog -LogLevel Info -UUID $UUID "Initialized the backup state file: ${backupStateFile}.  Initial state is ON-GOING"
    try {
        # 打包压缩
        Write-ULog -LogLevel Info -UUID $UUID "Compress Backup [BEGIN]"
        [string]$localBackupFile = "${BaseDir}\backup_tmp.rar"
        CompressProcess -SrcPath $SrcPath -DestFile $localBackupFile

        # 上传
        Write-ULog -LogLevel Info -UUID $UUID "Upload Backup [BEGIN]"
        UploadProcess -DestBucket $DestBucket -RemoteFile $BackupFileName -LocalFile $localBackupFile

        # By default redirection file encoding is UTF16-LE.  When the Golang reads the file, it cannot parse the string. So force to output it as ASCII
        "SUCCESS" | Out-File -Encoding "ASCII" $backupStateFile
        Write-ULog -LogLevel Info -UUID $UUID "Finalized the backup state file: ${backupStateFile}.  Final state is SUCCESS"
    } catch {
        # By default redirection file encoding is UTF16-LE.  When the Golang reads the file, it cannot parse the string. So force to output it as ASCII
        "FAILED" | Out-File -Encoding "ASCII" $backupStateFile
        Write-ULog -LogLevel Info -UUID $UUID "Finalized the backup state file: ${backupStateFile}.  Final state is FAILED"
        throw
    }
} finally {
    Write-ULog -LogLevel Debug -UUID $UUID "SCRIPT END"
}
