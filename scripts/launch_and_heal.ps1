# Apollo Multi-Screen Bridge - Self-Healing Process Supervisor & Launcher
[CmdletBinding()]
param(
    [string]$ProfilesPath = "$PSScriptRoot\..\config\profiles.json",
    [switch]$KillOnly = $false,
    [switch]$Heal = $false
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ProfilesPath)) {
    $ProfilesPath = "$PSScriptRoot\..\config\profiles.sample.json"
}
if (-not (Test-Path $ProfilesPath)) {
    Write-Error "Cannot locate profiles.json or profiles.sample.json."
    exit 1
}

$rawJson = Get-Content $ProfilesPath -Raw | ConvertFrom-Json
$sunshineDir = $rawJson.general.sunshine_dir
$sunshineBin = Join-Path $sunshineDir $rawJson.general.sunshine_bin
$staggerDelay = if ($rawJson.general.stagger_delay_ms) { $rawJson.general.stagger_delay_ms } else { 1500 }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    APOLLO MULTI-SCREEN BRIDGE: PROCESS SUPERVISOR       " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# Step 1: Enforce Network Interface Metrics
Write-Host "`n>>> [1/4] Enforcing Network Interface Metrics..." -ForegroundColor Yellow
foreach ($prof in $rawJson.profiles) {
    if ($prof.network.interface_alias -and $prof.network.priority_metric) {
        try {
            $ifAlias = $prof.network.interface_alias
            $metric = $prof.network.priority_metric
            $current = Get-NetIPInterface -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($current -and $current.InterfaceMetric -ne $metric) {
                Set-NetIPInterface -InterfaceAlias $ifAlias -InterfaceMetric $metric -ErrorAction SilentlyContinue
                Write-Host "  [+] Set metric for '$ifAlias' -> $metric (Priority Enforced)" -ForegroundColor Green
            } elseif ($current) {
                Write-Host "  [=] Interface '$ifAlias' already at target metric $metric" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "  [!] Could not adjust metric for $($prof.network.interface_alias): $_"
        }
    }
}

# Step 2: Gracefully Terminate Existing Instances & Flush Sockets
Write-Host "`n>>> [2/4] Terminating Running Sunshine/Apollo Instances..." -ForegroundColor Yellow
$killedCount = 0
Get-Process -Name "sunshine" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $killedCount++
    } catch {}
}
if ($killedCount -gt 0) {
    Write-Host "  [+] Terminated $killedCount existing sunshine process(es)." -ForegroundColor Green
    Start-Sleep -Milliseconds 750
} else {
    Write-Host "  [=] No active sunshine processes found." -ForegroundColor Gray
}

# Socket cooldown & port verification
$allPorts = @()
foreach ($prof in $rawJson.profiles) {
    $allPorts += $prof.port_base
    $allPorts += $prof.webui_port
}

$waitMax = 10
while ($waitMax -gt 0) {
    $activeSockets = Get-NetTCPConnection -State Listen -LocalPort $allPorts -ErrorAction SilentlyContinue
    if (-not $activeSockets) { break }
    Write-Host "  [*] Waiting for socket cleanup on ports ($($activeSockets.LocalPort -join ', '))..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
    $waitMax--
}

if ($KillOnly) {
    Write-Host "`n[COMPLETED] All instances stopped. Exiting per -KillOnly flag." -ForegroundColor Cyan
    exit 0
}

# Step 3: Launch Profiles with Staggered Delays
Write-Host "`n>>> [3/4] Launching Isolated Apollo Profiles..." -ForegroundColor Yellow
$launched = @()

foreach ($prof in $rawJson.profiles) {
    $targetDir = Join-Path $sunshineDir $prof.config_dir
    $confFile = Join-Path $targetDir "sunshine.conf"
    
    if (-not (Test-Path $confFile)) {
        Write-Warning "Configuration not found for $($prof.name) at $confFile. Run bootstrap.ps1 first."
        continue
    }

    Write-Host "  [>] Launching $($prof.name) (Port: $($prof.port_base), Dir: $($prof.config_dir))..." -ForegroundColor Cyan
    
    $proc = Start-Process -FilePath $sunshineBin -ArgumentList "`"$confFile`"" -WorkingDirectory $targetDir -PassThru -WindowStyle Hidden
    
    if ($proc -and -not $proc.HasExited) {
        $launched += [PSCustomObject]@{
            Profile = $prof.name
            PID     = $proc.Id
            Port    = $prof.port_base
            WebUI   = $prof.webui_port
            Display = $prof.display.output_name
        }
        Write-Host "      Process started: PID $($proc.Id)" -ForegroundColor Green
    } else {
        Write-Error "Failed to launch process for $($prof.name)!"
    }

    Start-Sleep -Milliseconds $staggerDelay
}

# Step 4: Health Check & Verification
Write-Host "`n>>> [4/4] Verifying Instance Listeners..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 1000

$summary = @()
foreach ($item in $launched) {
    $listen = Get-NetTCPConnection -State Listen -LocalPort $item.Port -ErrorAction SilentlyContinue
    $status = if ($listen) { "ONLINE" } else { "STARTING/OFFLINE" }
    $color = if ($listen) { "Green" } else { "Red" }
    
    Write-Host "  [$status] $($item.Profile) -> Listening on Port $($item.Port) (PID: $($item.PID))" -ForegroundColor $color
    
    $summary += [PSCustomObject]@{
        Name    = $item.Profile
        PID     = $item.PID
        Port    = $item.Port
        WebUI   = "https://127.0.0.1:$($item.WebUI)"
        Display = $item.Display
        Status  = $status
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "           ALL PROFILES DISPATCHED SUCCESSFULLY           " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
$summary | Format-Table -AutoSize
