<#
Filesystem Collector
Monitors executable file creation
#>

$CollectorName = "filesystem"
$LogPath = "$PSScriptRoot\filesystem.jsonl"

$Paths = @(
    "$env:TEMP",
    "C:\Users",
    "C:\ProgramData"
)

$LogWriter = New-Object System.IO.StreamWriter($LogPath, $true)
$LogWriter.AutoFlush = $true

$Filters = "*.exe","*.dll","*.ps1","*.bat"

foreach ($path in $Paths) {

    foreach ($filter in $Filters) {

        Register-ObjectEvent `
            (New-Object IO.FileSystemWatcher $path,$filter) `
            Created `
            -Action {

                Write-Event @{
                    ts         = (Get-Date).ToUniversalTime().ToString("o")
                    collector = $CollectorName
                    path       = $Event.SourceEventArgs.FullPath
                    action     = "created"
                }
            }
    }
}

while ($true) { Start-Sleep 1 }
