[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()]
    [string]
    $UUID,
    [Parameter(Mandatory=$true, Position=0)]
    [String]
    $SrcDir,
    [Parameter(Mandatory=$true, Position=1)]
    [String]
    $DestFile
)

. "$PSScriptRoot\ulog.ps1"
if (!$UUID) {
    $UUID = [System.Guid]::NewGuid().ToString()
}

Write-ULog -LogLevel Debug -UUID $UUID "$PSCommandPath -UUID $UUID -SrcDir $SrcDir -DestFile $DestFile"

try {
    Write-ULog -LogLevel Info -UUID $UUID "Remove destination file first: $DestFile"
    Remove-Item -Path $DestFile

    # WinRAR版本, -m0表示不压缩, 因为SQLServer本身的备份已经压缩过了, 不需要再压缩; -r表示包含子目录
    # 详情请见winrar的online manual: http://acritum.com/software/manuals/winrar/ 
    Write-ULog -LogLevel Debug -UUID $UUID "C:\Program Files\WinRAR\Rar.exe a -r -m0 $DestFile $SrcDir"
    & "C:\Program Files\WinRAR\Rar.exe" a -r -m0 $DestFile $SrcDir

    # 用zip压缩版本, 先暂时注释
    #Add-Type -AssemblyName "System.IO.Compression.FileSystem"
    #[System.IO.Compression.ZipFile]::CreateFromDirectory($SrcDir, $DestFile, [System.IO.Compression.CompressionLevel]::NoCompression, $true);

} finally {
    Write-ULog -LogLevel Debug -UUID $UUID "SCRIPT END"
}
