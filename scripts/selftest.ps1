# Apollo Multi-Screen Bridge - Sub-Second Health, Collision & Topology Self-Test
[CmdletBinding()]
param(
    [string]$ProfilesPath = "$PSScriptRoot\..\config\profiles.json"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $ProfilesPath)) {
    $ProfilesPath = "$PSScriptRoot\..\config\profiles.sample.json"
}
if (-not (Test-Path $ProfilesPath)) {
    Write-Error "Cannot locate profiles.json or profiles.sample.json."
    exit 1
}

$rawJson = Get-Content $ProfilesPath -Raw | ConvertFrom-Json
$sunshineDir = $rawJson.general.sunshine_dir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     APOLLO MULTI-SCREEN BRIDGE: SYSTEM SELF-TEST        " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# Test 1: Configuration & Profile Consistency
Write-Host "`n[TEST 1] Verifying Declarative Profiles..." -ForegroundColor Yellow
$seenPorts = @{}
$seenGuids = @{}
$configValid = $true

foreach ($prof in $rawJson.profiles) {
    $cfgDir = Join-Path $sunshineDir $prof.config_dir
    $statePath = Join-Path $cfgDir "sunshine_state.json"
    $confPath = Join-Path $cfgDir "sunshine.conf"

    if (-not (Test-Path $confPath)) {
        Write-Host "  [-] Missing sunshine.conf for $($prof.name) at $confPath" -ForegroundColor Red
        $configValid = $false
    }
    if (-not (Test-Path $statePath)) {
        Write-Host "  [-] Missing sunshine_state.json for $($prof.name) at $statePath" -ForegroundColor Red
        $configValid = $false
    } else {
        $stateObj = Get-Content $statePath -Raw | ConvertFrom-Json
        $uid = $stateObj.root.uniqueid
        if (-not $uid) {
            Write-Host "  [-] No UniqueID found in $statePath" -ForegroundColor Red
            $configValid = $false
        } elseif ($seenGuids.ContainsKey($uid)) {
            Write-Host "  [-] CRITICAL COLLISION: UniqueID $uid shared between $($prof.name) and $($seenGuids[$uid])!" -ForegroundColor Red
            $configValid = $false
        } else {
            $seenGuids[$uid] = $prof.name
        }
    }

    if ($seenPorts.ContainsKey($prof.port_base)) {
        Write-Host "  [-] CRITICAL COLLISION: Port $($prof.port_base) shared between $($prof.name) and $($seenPorts[$prof.port_base])!" -ForegroundColor Red
        $configValid = $false
    } else {
        $seenPorts[$prof.port_base] = $prof.name
    }
}

if ($configValid) {
    Write-Host "  [+] Profile definitions & UniqueIDs are 100% collision-free." -ForegroundColor Green
} else {
    Write-Host "  [!] Profile configuration issues detected. Run bootstrap.ps1 to heal." -ForegroundColor Red
}

# Test 2: Network Adapter Metrics
Write-Host "`n[TEST 2] Verifying Network Routing Priority..." -ForegroundColor Yellow
foreach ($prof in $rawJson.profiles) {
    if ($prof.network.interface_alias) {
        $ifAlias = $prof.network.interface_alias
        $targetMetric = $prof.network.priority_metric
        $actual = Get-NetIPInterface -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($actual) {
            $met = $actual.InterfaceMetric
            if ($met -eq $targetMetric) {
                Write-Host "  [+] Interface '$ifAlias': Metric is $met (matches target $targetMetric)" -ForegroundColor Green
            } else {
                Write-Host "  [!] Interface '$ifAlias': Metric is $met (expected $targetMetric)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [-] Interface '$ifAlias' not found on system." -ForegroundColor Gray
        }
    }
}

# Test 3: Active Process & Socket Health
Write-Host "`n[TEST 3] Querying Instance Sockets & ServerInfo..." -ForegroundColor Yellow
$report = @()

foreach ($prof in $rawJson.profiles) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $pBase = $prof.port_base
    $pWeb = $prof.webui_port
    
    # TCP Connection Test
    $tcpBase = Test-NetConnection -ComputerName "127.0.0.1" -Port $pBase -InformationLevel Quiet -WarningAction SilentlyContinue
    $tcpWeb = Test-NetConnection -ComputerName "127.0.0.1" -Port $pWeb -InformationLevel Quiet -WarningAction SilentlyContinue

    # ServerInfo Query
    $uniqueIdDiscovered = "N/A"
    $httpLatency = "N/A"
    
    if ($tcpBase) {
        try {
            $uri = "http://127.0.0.1:$pBase/serverinfo"
            $resp = Invoke-WebRequest -Uri $uri -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            $sw.Stop()
            $httpLatency = "$($sw.ElapsedMilliseconds)ms"
            
            if ($resp.Content -match "<uniqueid>(.*?)</uniqueid>") {
                $uniqueIdDiscovered = $matches[1]
            } elseif ($resp.Content -match '"uniqueid":\s*"([^"]+)"') {
                $uniqueIdDiscovered = $matches[1]
            } else {
                $uniqueIdDiscovered = "DETECTED"
            }
        } catch {
            $uniqueIdDiscovered = "HTTP-ERR"
        }
    }

    $stateColor = if ($tcpBase -and $tcpWeb) { "Green" } else { "Red" }
    $stateLabel = if ($tcpBase -and $tcpWeb) { "HEALTHY" } else { "DEGRADED" }

    $report += [PSCustomObject]@{
        Profile       = $prof.name
        BasePort      = $pBase
        WebUIPort     = $pWeb
        Status        = $stateLabel
        Latency       = $httpLatency
        DiscoveredUID = $uniqueIdDiscovered
        BoundDisplay  = $prof.display.output_name
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                 SYSTEM TOPOLOGY MATRIX                   " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
$report | Format-Table -AutoSize

$allHealthy = ($report | Where-Object { $_.Status -ne "HEALTHY" }).Count -eq 0
if ($allHealthy) {
    Write-Host "[SUCCESS] All Apollo bridge instances verified online and healthy!`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[WARNING] One or more instances are offline or degraded. Run launch_and_heal.ps1 to recover.`n" -ForegroundColor Yellow
    exit 2
}
