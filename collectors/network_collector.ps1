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

# Track already-seen connections
$Seen = @{}

while ($true) {

    $lines = netstat -ano | Select-Object -Skip 4

    foreach ($line in $lines) {

        if ($line -match "\s+(TCP|UDP)\s+([\d\.\:]+)\s+([\d\.\:]+)\s+(\w+)\s+(\d+)") {

            $protocol = $matches[1]
            $local    = $matches[2]
            $remote   = $matches[3]
            $state    = $matches[4]
            $procId   = $matches[5]

            $key = "$protocol|$local|$remote|$procId"

            if (-not $Seen.ContainsKey($key)) {
                $Seen[$key] = $true

                Write-Event @{
                    ts         = (Get-Date).ToUniversalTime().ToString("o")
                    collector = $CollectorName
                    protocol  = $protocol
                    local     = $local
                    remote    = $remote
                    state     = $state
                    pid       = $procId
                }
            }
        }
    }

    Start-Sleep -Seconds 2
}
