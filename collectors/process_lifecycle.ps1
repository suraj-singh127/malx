<#
Process Lifecycle Collector
Captures process start and stop events using WMI
Outputs JSONL telemetry
#>

# ==============================
# Configuration
# ==============================

$CollectorName = "process_lifecycle"
$LogPath = "$PSScriptRoot\process_lifecycle.jsonl"

$IgnoredImages = @(
    "powershell.exe",
    "cmd.exe",
    "conhost.exe"
)

# ==============================
# Initialize Log Writer
# ==============================

$LogWriter = New-Object System.IO.StreamWriter($LogPath, $true)
$LogWriter.AutoFlush = $true

function Write-Event {
    param (
        [hashtable]$Record
    )

    try {
        $json = $Record | ConvertTo-Json -Compress -Depth 5
        $LogWriter.WriteLine($json)
    } catch {
        # Collector must never crash
    }
}

# ==============================
# Process Start Handler
# ==============================

Register-WmiEvent -Class Win32_ProcessStartTrace -Action {

    $e = $Event.SourceEventArgs.NewEvent

    $procId        = $e.ProcessID
    $parentProcId  = $e.ParentProcessID
    $image         = $e.ProcessName

    if ($IgnoredImages -contains $image) {
        return
    }

    $imagePath = $null
    $cmdline   = $null
    $user      = $null
    $sessionId = $null

    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId"

        $imagePath = $proc.ExecutablePath
        $cmdline   = $proc.CommandLine
        $sessionId = $proc.SessionId

        try {
            $owner = $proc | Invoke-CimMethod -MethodName GetOwner
            $user = "$($owner.Domain)\$($owner.User)"
        } catch {
            $user = $null
        }
    } catch {
        # Process may have already exited
    }

    Write-Event @{
        ts          = (Get-Date).ToUniversalTime().ToString("o")
        collector  = $CollectorName
        event      = "process_start"
        pid        = $procId
        ppid       = $parentProcId
        image      = $image
        image_path = $imagePath
        cmdline    = $cmdline
        user       = $user
        session_id = $sessionId
    }
}

# ==============================
# Process Stop Handler
# ==============================

Register-WmiEvent -Class Win32_ProcessStopTrace -Action {

    $e = $Event.SourceEventArgs.NewEvent

    Write-Event @{
        ts         = (Get-Date).ToUniversalTime().ToString("o")
        collector = $CollectorName
        event     = "process_stop"
        pid       = $e.ProcessID
        exit_code = $e.ExitStatus
    }
}

# ==============================
# Main Loop
# ==============================

try {
    while ($true) {
        Wait-Event | Out-Null
    }
}
finally {
    $LogWriter.Close()
}
