# ==============================
# Advanced Forensic Collector
# ==============================

$ErrorActionPreference = "Continue"

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$baseDir = "$env:USERPROFILE\Desktop\Forensic_Collection_$timestamp"

New-Item -ItemType Directory -Path $baseDir -Force | Out-Null

function Write-Log {
    param ($Message)
    $Message | Out-File -FilePath "$baseDir\collection_log.txt" -Append
}

Write-Log "=== Forensic Collection Started: $(Get-Date) ==="

# ------------------------------
# SYSTEM INFO
# ------------------------------

try {
    systeminfo | Out-File "$baseDir\systeminfo.txt"
    ipconfig /all | Out-File "$baseDir\network_info.txt"
    ipconfig /displaydns | Out-File "$baseDir\dns_cache.txt"
    tasklist | Out-File "$baseDir\running_processes.txt"
    Get-Service | Out-File "$baseDir\services.txt"
}
catch {
    Write-Log "Error collecting system info: $_"
}

# ------------------------------
# EVENT LOGS EXPORT
# ------------------------------

try {
    wevtutil epl Security "$baseDir\Security.evtx"
    wevtutil epl Application "$baseDir\Application.evtx"
    wevtutil epl System "$baseDir\System.evtx"
}
catch {
    Write-Log "Error exporting event logs: $_"
}

# ------------------------------
# INSTALLED PROGRAMS
# ------------------------------

try {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select DisplayName, DisplayVersion, Publisher |
    Out-File "$baseDir\installed_programs.txt"
}
catch {
    Write-Log "Error collecting installed programs: $_"
}

# ------------------------------
# CHROME ARTIFACT COLLECTION
# ------------------------------

$chromeBase = "$env:LOCALAPPDATA\Google\Chrome\User Data"

if (Test-Path $chromeBase) {
    Get-ChildItem $chromeBase -Directory | ForEach-Object {
        $profilePath = $_.FullName
        $profileName = $_.Name

        $dest = "$baseDir\Chrome_$profileName"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null

        $files = @("History","Cookies","Login Data","Web Data","Bookmarks","Preferences")

        foreach ($file in $files) {
            $sourceFile = Join-Path $profilePath $file
            if (Test-Path $sourceFile) {
                try {
                    Copy-Item $sourceFile -Destination $dest -Force
                }
                catch {
                    Write-Log "Failed copying $file from $profileName : $_"
                }
            }
        }
    }
}
else {
    Write-Log "Chrome not found."
}

# ------------------------------
# SLACK LOCAL DATA
# ------------------------------

$slackPaths = @(
    "$env:APPDATA\Slack",
    "$env:LOCALAPPDATA\slack"
)

foreach ($path in $slackPaths) {
    if (Test-Path $path) {
        try {
            Copy-Item $path -Destination "$baseDir\Slack_Data" -Recurse -Force
        }
        catch {
            Write-Log "Failed copying Slack data: $_"
        }
    }
}

# ------------------------------
# RECENT FILES
# ------------------------------

try {
    Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" |
    Select Name, LastWriteTime |
    Out-File "$baseDir\recent_files.txt"
}
catch {
    Write-Log "Error collecting recent files: $_"
}

# ------------------------------
# NETWORK CONNECTIONS
# ------------------------------

try {
    netstat -ano | Out-File "$baseDir\network_connections.txt"
}
catch {
    Write-Log "Error collecting network connections: $_"
}

Write-Log "=== Collection Completed: $(Get-Date) ==="

Write-Host "Forensic collection complete."
Write-Host "Saved to: $baseDir"