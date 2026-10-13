# Apollo Multi-Screen Bridge - Self-Healing Process Supervisor & Link-Aware Watchdog
[CmdletBinding()]
param(
    [string]$ProfilesPath = "$PSScriptRoot\..\config\profiles.json",
    [switch]$KillOnly = $false,
    [switch]$Heal = $false,
    [switch]$Watchdog = $false,
    [switch]$NoGui = $false
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

# Function: Synchronize Wired Priority & Dynamic Roam Gating
function Sync-WiredPriorityAndGating {
    param(
        [object]$Config,
        [switch]$Silent = $false
    )

    $wiredProfile = $Config.profiles | Where-Object { $_.network.enforce_wired_only -eq $true } | Select-Object -First 1
    $roamProfile  = $Config.profiles | Where-Object { $_.id -match "roam" -or $_.name -match "Roam" } | Select-Object -First 1

    if (-not $wiredProfile) { return }

    $wiredAlias = $wiredProfile.network.interface_alias
    $wiredNic = Get-NetAdapter -InterfaceAlias $wiredAlias -ErrorAction SilentlyContinue

    $roamTcpRule = "Apollo Roam Gating (Wired Active Block TCP)"
    $roamUdpRule = "Apollo Roam Gating (Wired Active Block UDP)"

    if ($wiredNic -and $wiredNic.Status -eq "Up") {
        # 1. Enforce lowest metric on direct link (Priority 2)
        $targetMetric = if ($wiredProfile.network.priority_metric) { $wiredProfile.network.priority_metric } else { 2 }
        $currentWired = Get-NetIPInterface -InterfaceAlias $wiredAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($currentWired -and $currentWired.InterfaceMetric -ne $targetMetric) {
            Set-NetIPInterface -InterfaceAlias $wiredAlias -InterfaceMetric $targetMetric -ErrorAction SilentlyContinue
            if (-not $Silent) { Write-Host "  [+] Direct link detected: Set '$wiredAlias' metric -> $targetMetric (Priority Enforced)" -ForegroundColor Green }
        }

        # 2. Deprioritize Wi-Fi interface metric to guarantee routing precedence
        $currentWifi = Get-NetIPInterface -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($currentWifi -and $currentWifi.InterfaceMetric -ne 50) {
            Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 50 -ErrorAction SilentlyContinue
            if (-not $Silent) { Write-Host "  [+] Deprioritized 'Wi-Fi' interface metric -> 50 (Routing Precedence Enforced)" -ForegroundColor Green }
        }

        # 3. Ensure Route Metric 1 for direct link subnet
        $ipObj = Get-NetIPAddress -InterfaceAlias $wiredAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ipObj) {
            $prefix = "$($ipObj.IPAddress.Substring(0, $ipObj.IPAddress.LastIndexOf('.'))).0/$($ipObj.PrefixLength)"
            $routeObj = Get-NetRoute -DestinationPrefix $prefix -InterfaceAlias $wiredAlias -ErrorAction SilentlyContinue
            if ($routeObj -and $routeObj.RouteMetric -ne 1) {
                Set-NetRoute -DestinationPrefix $prefix -InterfaceAlias $wiredAlias -RouteMetric 1 -ErrorAction SilentlyContinue
                if (-not $Silent) { Write-Host "  [+] Route metric for $prefix set to 1 on '$wiredAlias'" -ForegroundColor Green }
            }
        }

        # 4. Roam Gating: Block Roam instance on Wi-Fi while direct cable is docked
        if ($roamProfile) {
            $existingRule = Get-NetFirewallRule -DisplayName $roamTcpRule -ErrorAction SilentlyContinue
            if (-not $existingRule) {
                $pBase = $roamProfile.port_base
                $pWeb  = $roamProfile.webui_port
                $tcpPorts = "$($pBase - 5),$pBase,$pWeb,$($pBase + 21)"
                $udpPorts = "$($pBase + 9),$($pBase + 10),$($pBase + 11),$($pBase + 13),$($pBase + 21)"

                New-NetFirewallRule -DisplayName $roamTcpRule -Direction Inbound -Action Block -InterfaceAlias "Wi-Fi" -Protocol TCP -LocalPort ($tcpPorts -split ',') | Out-Null
                New-NetFirewallRule -DisplayName $roamUdpRule -Direction Inbound -Action Block -InterfaceAlias "Wi-Fi" -Protocol UDP -LocalPort ($udpPorts -split ',') | Out-Null
                if (-not $Silent) { Write-Host "  [!] Roam Gating Active: Blocked Roam ports on Wi-Fi while direct link is docked." -ForegroundColor Yellow }
            }
        }
    } else {
        # Direct link is down/unplugged -> restore wireless roaming
        $currentWifi = Get-NetIPInterface -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($currentWifi -and $currentWifi.InterfaceMetric -ne 30) {
            Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 30 -ErrorAction SilentlyContinue
            if (-not $Silent) { Write-Host "  [=] Direct link unplugged: Restored 'Wi-Fi' interface metric -> 30" -ForegroundColor Cyan }
        }

        # Remove Roam gating block so wireless roaming works seamlessly
        Remove-NetFirewallRule -DisplayName $roamTcpRule -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName $roamUdpRule -ErrorAction SilentlyContinue
        if (-not $Silent) { Write-Host "  [=] Roam Gating Released: Wireless roaming enabled for iPad." -ForegroundColor Cyan }
    }
}

# Watchdog Mode (Background Link State Polling)
if ($Watchdog) {
    Write-Host "[WATCHDOG] Starting background link-sensing loop for Apollo Multi-Screen Bridge..." -ForegroundColor Cyan
    $lastState = $null
    $wiredProfile = $rawJson.profiles | Where-Object { $_.network.enforce_wired_only -eq $true } | Select-Object -First 1
    $wiredAlias = if ($wiredProfile) { $wiredProfile.network.interface_alias } else { "Ethernet 4" }

    while ($true) {
        $nic = Get-NetAdapter -InterfaceAlias $wiredAlias -ErrorAction SilentlyContinue
        $currentState = if ($nic) { $nic.Status } else { "Down" }

        if ($currentState -ne $lastState) {
            Write-Host "[WATCHDOG] Adapter '$wiredAlias' link state changed: $currentState" -ForegroundColor Yellow
            Sync-WiredPriorityAndGating -Config $rawJson
            $lastState = $currentState
        }
        Start-Sleep -Seconds 3
    }
    exit 0
}

# Standard Launcher Workflow
if (-not $NoGui) {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "    APOLLO MULTI-SCREEN BRIDGE: PROCESS SUPERVISOR       " -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
}

# Step 1: Link-Aware Adapter Sensing & Routing Precedence
if (-not $NoGui) { Write-Host "`n>>> [1/4] Enforcing Link-Aware Adapter Sensing & Routing..." -ForegroundColor Yellow }
Sync-WiredPriorityAndGating -Config $rawJson -Silent:$NoGui

# Step 2: Gracefully Terminate Existing Instances & Flush Sockets
if (-not $NoGui) { Write-Host "`n>>> [2/4] Terminating Running Sunshine/Apollo Instances..." -ForegroundColor Yellow }
$killedCount = 0
Get-Process -Name "sunshine" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $killedCount++
    } catch {}
}
if ($killedCount -gt 0 -and (-not $NoGui)) {
    Write-Host "  [+] Terminated $killedCount existing sunshine process(es)." -ForegroundColor Green
    Start-Sleep -Milliseconds 750
} elseif (-not $NoGui) {
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
    if (-not $NoGui) { Write-Host "  [*] Waiting for socket cleanup on ports ($($activeSockets.LocalPort -join ', '))..." -ForegroundColor Gray }
    Start-Sleep -Milliseconds 500
    $waitMax--
}

if ($KillOnly) {
    if (-not $NoGui) { Write-Host "`n[COMPLETED] All instances stopped. Exiting per -KillOnly flag." -ForegroundColor Cyan }
    exit 0
}

# Step 3: Launch Profiles with Staggered Delays
if (-not $NoGui) { Write-Host "`n>>> [3/4] Launching Isolated Apollo Profiles..." -ForegroundColor Yellow }
$launched = @()

foreach ($prof in $rawJson.profiles) {
    $targetDir = Join-Path $sunshineDir $prof.config_dir
    $confFile = Join-Path $targetDir "sunshine.conf"
    
    if (-not (Test-Path $confFile)) {
        if (-not $NoGui) { Write-Warning "Configuration not found for $($prof.name) at $confFile. Run bootstrap.ps1 first." }
        continue
    }

    if (-not $NoGui) { Write-Host "  [>] Launching $($prof.name) (Port: $($prof.port_base), Dir: $($prof.config_dir))..." -ForegroundColor Cyan }
    
    $proc = Start-Process -FilePath $sunshineBin -ArgumentList "`"$confFile`"" -WorkingDirectory $targetDir -PassThru -WindowStyle Hidden
    
    if ($proc -and -not $proc.HasExited) {
        $launched += [PSCustomObject]@{
            Profile = $prof.name
            PID     = $proc.Id
            Port    = $prof.port_base
            WebUI   = $prof.webui_port
            Display = $prof.display.output_name
        }
        if (-not $NoGui) { Write-Host "      Process started: PID $($proc.Id)" -ForegroundColor Green }
    } else {
        Write-Error "Failed to launch process for $($prof.name)!"
    }

    Start-Sleep -Milliseconds $staggerDelay
}

# Step 4: Health Check & Verification
if (-not $NoGui) { Write-Host "`n>>> [4/4] Verifying Instance Listeners..." -ForegroundColor Yellow }
Start-Sleep -Milliseconds 1000

$summary = @()
foreach ($item in $launched) {
    $listen = Get-NetTCPConnection -State Listen -LocalPort $item.Port -ErrorAction SilentlyContinue
    $status = if ($listen) { "ONLINE" } else { "STARTING/OFFLINE" }
    $color = if ($listen) { "Green" } else { "Red" }
    
    if (-not $NoGui) {
        Write-Host "  [$status] $($item.Profile) -> Listening on Port $($item.Port) (PID: $($item.PID))" -ForegroundColor $color
    }
    
    $summary += [PSCustomObject]@{
        Name    = $item.Profile
        PID     = $item.PID
        Port    = $item.Port
        WebUI   = "https://127.0.0.1:$($item.WebUI)"
        Display = $item.Display
        Status  = $status
    }
}

if (-not $NoGui) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "           ALL PROFILES DISPATCHED SUCCESSFULLY           " -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
    $summary | Format-Table -AutoSize
}
