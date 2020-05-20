# 检查日志文件夹是否存在，若不存在则新建
if (! $(Test-Path -Path $LogDir -PathType Container)) {
    New-Item -Path $LogDir -ItemType "Directory"
    if (! $?) {
        $errMsg = "Cannot create the directory: $LogDir"
        throw "Cannot create log directory"
    }
}

function Write-ULog {
    [CmdletBinding(PositionalBinding=$false)]
    param (
        [Parameter()]
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]
        $LogLevel = "Info",
        [Parameter()]
        [string]
        $UUID,
        [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string[]]
        $Messages
    )
    begin {
        switch ($LogLevel) {
            "Debug" {
                $writeAction = "Write-Debug"
                $tag = "DEBUG"
                $levelValue = 0
                break
            }
            "Info" {
                $writeAction = "Write-Verbose"
                $tag = "INFO"
                $levelValue = 1
                break
            }
            "Warning" {
                $writeAction = "Write-Warning"
                $tag = "WARNING"
                $levelValue = 2
                break
            }
            "Error" {
                $writeAction = "Write-Error"
                $tag = "ERROR"
                $levelValue = 3
                break
            }
            default {
                throw "Unsupported log level: $LogLevel"
            }
        }
        if (!$UUID) {
            $UUID = [System.Guid]::NewGuid().ToString()
        }
        [string[]]$allMessages = $Messages
    }
    process {
        if ($_) {
            $allMessages += $_
        }
    }
    end {
        $currentTimestamp = Get-Date -UFormat "%Y-%m-%dT%H:%M:%S%Z"
        foreach ($msg in $allMessages) {
            "[{0}] [{1,7}] [{2}] [{3}] {4}" -f $currentTimestamp, $tag, $UUID, $MyInvocation.PSCommandPath, $msg | Tee-Object -FilePath "${LogDir}\backup-script.log" -Append | & $writeAction
        }
    }
}
