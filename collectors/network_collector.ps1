<#
Network Connection Collector
Uses netstat polling with delta detection
#>

$CollectorName = "network"
$LogPath = "$PSScriptRoot\network.jsonl"

$LogWriter = New-Object System.IO.StreamWriter($LogPath, $true)
$LogWriter.AutoFlush = $true

function Write-Event {
    param([hashtable]$Record)
    try {
        $LogWriter.WriteLine(($Record | ConvertTo-Json -Compress))
    } catch {}
}

$Seen = @{}

while ($true) {

    $lines = netstat -ano | Select-Object -Skip 4

    foreach ($line in $lines) {

        if ($line -match "\s+(TCP|UDP)\s+([\d\.\:]+)\s+([\d\.\:]+)\s+(\w+)\s+(\d+)") {

            $proto = $matches[1]
            $local = $matches[2]
            $remote = $matches[3]
            $state = $matches[4]
            $pid = $matches[5]

            $key = "$proto|$local|$remote|$pid"

            if (-not $Seen.ContainsKey($key)) {
                $Seen[$key] = $true

                Write-Event @{
                    ts         = (Get-Date).ToUniversalTime().ToString("o")
                    collector = $CollectorName
                    protocol  = $proto
                    local     = $local
                    remote    = $remote
                    state     = $state
                    pid       = $pid
                }
            }
        }
    }

    Start-Sleep -Seconds 2
}
