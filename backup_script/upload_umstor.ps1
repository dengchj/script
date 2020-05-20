[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()]
    [string]
    $UUID,
    [Parameter(Mandatory=$true, Position=0)]
    [String]
    $Bucket,
    [Parameter(Mandatory=$true, Position=1)]
    [String]
    $LocalFile,
    [Parameter(Mandatory=$true, Position=2)]
    [String]
    $RemoteFile
)

. "$PSScriptRoot\ulog.ps1"

if (!$UUID) {
    $UUID = [System.Guid]::NewGuid().ToString()
}

Write-ULog -LogLevel Debug -UUID $UUID "$PSCommandPath -UUID $UUID -Bucket $Bucket -LocalFile $LocalFile -RemoteFile $RemoteFile"
try {
    Write-ULog -LogLevel Debug -UUID $UUID "python $PSScriptRoot\backup_to_umstor.py $Bucket $LocalFile $RemoteFile"
    python $PSScriptRoot\backup_to_umstor.py $Bucket $LocalFile $RemoteFile
} finally {
    Write-ULog -LogLevel Debug -UUID $UUID "SCRIPT END"
}
