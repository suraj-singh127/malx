<#
Registry Persistence Collector
Monitors common autorun locations
#>

$CollectorName = "registry"
$LogPath = "$PSScriptRoot\registry.jsonl"

$Keys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\System\CurrentControlSet\Services"
)

$LogWriter = New-Object System.IO.StreamWriter($LogPath, $true)
$LogWriter.AutoFlush = $true

function Write-Event {
    param([hashtable]$Record)
    try {
        $LogWriter.WriteLine(($Record | ConvertTo-Json -Compress))
    } catch {}
}

$Baseline = @{}

foreach ($key in $Keys) {
    try {
        $Baseline[$key] = Get-ItemProperty $key
    } catch {}
}

while ($true) {
    foreach ($key in $Keys) {
        try {
            $current = Get-ItemProperty $key

            foreach ($prop in $current.PSObject.Properties) {
                if (-not $Baseline[$key].PSObject.Properties.Name.Contains($prop.Name)) {

                    Write-Event @{
                        ts         = (Get-Date).ToUniversalTime().ToString("o")
                        collector = $CollectorName
                        key        = $key
                        value_name= $prop.Name
                        data       = $prop.Value
                        action     = "added"
                    }
                }
            }

            $Baseline[$key] = $current
        } catch {}
    }

    Start-Sleep -Seconds 5
}
