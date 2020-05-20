[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()]
    [string]
    $UUID,
    [Parameter(Mandatory=$true, Position=0)]
    [String]
    $DestBucket,
    [Parameter(Mandatory=$true, Position=1)]
    [String]
    $DBId,
    [Parameter(Mandatory=$true, Position=2)]
    [String]
    $BackupFileName
)

[string]$BaseDir = "C:\SqlServerBackup"
[string]$LogDir = $BaseDir + "\Log"
. "$PSScriptRoot\ulog.ps1"

if (!$UUID) {
    $UUID = [System.Guid]::NewGuid().ToString()
}

Write-ULog -LogLevel Debug -UUID $UUID "$PSCommandPath -UUID $UUID -DestBucket $DestBucket -DBId $DBId -BackupFileName $BackupFileName"

try {
    [string]$BackupDir = "${BaseDir}\DataBak"

    if ( $(Test-Path -Path $BackupDir -PathType Container)) {
        Write-ULog -LogLevel Info -UUID $UUID "Backup directory ( ${BackupDir} ) exists.  Remove before backup"
        Remove-Item -Path $BackupDir -Recurse
    }
    Write-ULog -LogLevel Info -UUID $UUID "Create backup directory: ${BackupDir}"
    New-Item -Path $BackupDir -ItemType "Directory"
    if (! $?) {
        $errMsg = "Cannot create the directory: $BackupDir"
        Write-ULog -LogLevel Error -UUID $UUID $errMsg
        throw $errMsg
    }

    [string]$backupFileNamePrefix = [System.IO.Path]::GetFileNameWithoutExtension($BackupFileName)
    [string]$backupStateFile = "${LogDir}\${backupFileNamePrefix}.backup_state.txt"
    # By default redirection file encoding is UTF16-LE.  When the Golang reads the file, it cannot parse the string. So force to output it as ASCII
    "ON-GOING" | Out-File -Encoding "ASCII" $backupStateFile
    Write-ULog -LogLevel Info -UUID $UUID "Initialized the backup state file: ${backupStateFile}.  Initial state is ON-GOING"
    try {
        Write-ULog -LogLevel Info -UUID $UUID "Backup DB Instance [BEGIN]"
        try {
            Push-Location
            Import-Module SQLPS
            Pop-Location

            $instance = $(Get-ChildItem "SQLSERVER:\\SQL\${env:COMPUTERNAME}")[0]
            #$needBackupDatabases = $instance.Databases | Where-Object -FilterScript { $_.Name -notin @("master", "msdb", "tempdb", "model", "ReportServer", "ReportServerTempDB") }
            $needBackupDatabases = $instance.Databases | Where-Object -FilterScript { $_.Name -notin @("msdb", "tempdb", "model") }
            foreach ($database in $needBackupDatabases ) {
                Backup-SqlDatabase -DatabaseObject $database -BackupAction Database -BackupFile "$BackupDir\$($database.Name).bak" -CompressionOption On
            }
        } finally {
            Write-ULog -LogLevel Info -UUID $UUID "Backup DB Instance [END]"
        }

        Write-ULog -LogLevel Info -UUID $UUID "Compress Backup [BEGIN]"
        [string]$localBackupFile = "${BaseDir}\backup_tmp.rar"
        try {
            # 如果本地备份文件已经存在, compress backup当中会去先删�?
            &"$PSScriptRoot\compress_backup.ps1" -UUID $UUID -SrcDir $BackupDir -DestFile $localBackupFile
            if ( ! $? ) {
                $errMsg = "Compress backup file failed"
                Write-ULog -LogLevel Error -UUID $UUID $errMsg
                throw $errMsg
            }
            Write-ULog -LogLevel Info -UUID $UUID "Remove backup directory after archiving: ${BackupDir}"
            Remove-Item -Path $BackupDir -Recurse
        } finally {
            Write-ULog -LogLevel Info -UUID $UUID "Compress Backup [END]"
        }

        Write-ULog -LogLevel Info -UUID $UUID "Upload Backup [BEGIN]"
        [string]$remoteBackupFile = "${DBId}/${BackupFileName}"
        try {
            &"$PSScriptRoot\upload.ps1" -UUID $UUID -Bucket $DestBucket -LocalFile $localBackupFile -RemoteFile $remoteBackupFile
            if ( ! $? ) {
                $errMsg = "Upload backup file failed"
                Write-ULog -LogLevel Error -UUID $UUID $errMsg
                throw $errMsg
            }
        } finally {
            Write-ULog -LogLevel Info -UUID $UUID "Upload Backup [END]"
        }

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
