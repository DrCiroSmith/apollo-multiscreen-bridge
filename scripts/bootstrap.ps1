# Apollo Multi-Screen Bridge - Dynamic Bootstrap & Config Generator
[CmdletBinding()]
param(
    [string]$ProfilesPath = "$PSScriptRoot\..\config\profiles.json",
    [switch]$ForceRebuild = $false
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ProfilesPath)) {
    $samplePath = "$PSScriptRoot\..\config\profiles.sample.json"
    if (Test-Path $samplePath) {
        Write-Host "Profiles config not found. Generating from sample: $samplePath" -ForegroundColor Yellow
        Copy-Item $samplePath $ProfilesPath -Force
    } else {
        Write-Error "Cannot locate profiles.json or profiles.sample.json."
        exit 1
    }
}

$rawJson = Get-Content $ProfilesPath -Raw | ConvertFrom-Json
$sunshineDir = $rawJson.general.sunshine_dir

if (-not (Test-Path $sunshineDir)) {
    Write-Error "Sunshine/Apollo base directory not found at $sunshineDir. Please update profiles.json."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       APOLLO MULTI-SCREEN BRIDGE: BOOTSTRAP ENGINE        " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$usedPorts = @{}
$usedGuids = @{}

foreach ($prof in $rawJson.profiles) {
    Write-Host "`n>>> Processing Profile: $($prof.name) [$($prof.id)]" -ForegroundColor Green
    
    $targetDir = Join-Path $sunshineDir $prof.config_dir
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "  [+] Created directory: $targetDir"
    }

    # Port collision check
    if ($usedPorts.ContainsKey($prof.port_base)) {
        Write-Error "Port collision! Port $($prof.port_base) is already assigned to profile $($usedPorts[$prof.port_base])."
        exit 1
    }
    $usedPorts[$prof.port_base] = $prof.id

    # 1. State File & UniqueID Generation
    $statePath = Join-Path $targetDir "sunshine_state.json"
    $stateData = $null
    
    if (Test-Path $statePath) {
        try {
            $stateData = Get-Content $statePath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Existing state file invalid. Re-initializing: $statePath"
        }
    }

    if (-not $stateData -or $ForceRebuild -or (-not $stateData.root.uniqueid)) {
        $guid = [guid]::NewGuid().ToString().ToUpper()
        while ($usedGuids.ContainsKey($guid)) {
            $guid = [guid]::NewGuid().ToString().ToUpper()
        }
        $usedGuids[$guid] = $prof.id

        # Inherit WebUI credentials dynamically from base config if present
        $baseStatePath = Join-Path $sunshineDir "config\sunshine_state.json"
        $baseUsername = "admin"
        $basePassword = ""
        $baseSalt = ""
        if (Test-Path $baseStatePath) {
            try {
                $baseJson = Get-Content $baseStatePath -Raw | ConvertFrom-Json
                if ($baseJson.username) { $baseUsername = $baseJson.username }
                if ($baseJson.password) { $basePassword = $baseJson.password }
                if ($baseJson.salt) { $baseSalt = $baseJson.salt }
            } catch {}
        }

        $stateData = [PSCustomObject]@{
            username = $baseUsername
            password = $basePassword
            salt     = $baseSalt
            root     = [PSCustomObject]@{
                uniqueid      = $guid
                named_devices = @()
            }
        }
        Write-Host "  [+] Generated new Machine UniqueID: $guid"
    } else {
        $guid = $stateData.root.uniqueid
        $usedGuids[$guid] = $prof.id
        Write-Host "  [=] Retaining existing Machine UniqueID: $guid"
    }

    # Ensure named_devices JSON booleans and integers are strictly typed
    $stateJson = $stateData | ConvertTo-Json -Depth 10
    Set-Content -Path $statePath -Value $stateJson -Encoding utf8

    # 2. Base Apps & Credentials Setup
    $appsPath = Join-Path $targetDir "apps.json"
    if (-not (Test-Path $appsPath)) {
        $defaultAppsPath = Join-Path $sunshineDir "config\apps.json"
        if (Test-Path $defaultAppsPath) {
            Copy-Item $defaultAppsPath $appsPath -Force
        } else {
            @{ env = @{}; apps = @(@{ name = "Desktop"; output = ""; cmd = "" }) } | ConvertTo-Json | Set-Content $appsPath -Encoding utf8
        }
        Write-Host "  [+] Initialized apps list: $appsPath"
    }

    # 3. Generate sunshine.conf
    $confPath = Join-Path $targetDir "sunshine.conf"
    $lines = @(
        "always_use_virtual_display = $(if ($prof.display.virtual_display) { 'enabled' } else { 'disabled' })",
        "dd_manual_refresh_rate = $($prof.display.refresh_rate)",
        "dd_manual_resolution = $($prof.display.resolution)",
        "dd_refresh_rate_option = manual",
        "dd_resolution_option = manual",
        "double_refreshrate = $(if ($prof.display.double_refreshrate) { 'enabled' } else { 'disabled' })",
        "file_apps = $appsPath",
        "file_state = $statePath",
        "log_path = $(Join-Path $targetDir 'sunshine.log')",
        "output_name = $($prof.display.output_name)",
        "port = $($prof.port_base)",
        'server_cmd = [{"cmd":"bubbles.scr","elevated":false,"name":"Bubbles"}]',
        "stream_audio = disabled",
        "sunshine_name = $($prof.name)",
        "upnp = disabled"
    )
    Set-Content -Path $confPath -Value $lines -Encoding utf8
    Write-Host "  [+] Config written: $confPath"

    # 4. Firewall Automation
    if ($prof.network.enforce_wired_only -and $prof.network.block_on_interfaces) {
        foreach ($blockIf in $prof.network.block_on_interfaces) {
            $ruleNameTcp = "Block $($prof.name) on $blockIf TCP"
            $ruleNameUdp = "Block $($prof.name) on $blockIf UDP"
            Remove-NetFirewallRule -DisplayName "$ruleNameTcp*" -ErrorAction SilentlyContinue
            Remove-NetFirewallRule -DisplayName "$ruleNameUdp*" -ErrorAction SilentlyContinue

            $pBase = $prof.port_base
            $tcpPorts = "$($pBase - 5),$pBase,$($pBase + 1),$($pBase + 21)"
            $udpPorts = "$($pBase + 9),$($pBase + 10),$($pBase + 11),$($pBase + 13),$($pBase + 21)"

            New-NetFirewallRule -DisplayName $ruleNameTcp -Direction Inbound -Action Block -InterfaceAlias $blockIf -Protocol TCP -LocalPort ($tcpPorts -split ',') | Out-Null
            New-NetFirewallRule -DisplayName $ruleNameUdp -Direction Inbound -Action Block -InterfaceAlias $blockIf -Protocol UDP -LocalPort ($udpPorts -split ',') | Out-Null
            Write-Host "  [!] Firewall enforced: Blocked on $blockIf (Wired Exclusive)" -ForegroundColor Yellow
        }
    } else {
        $ruleNameAllow = "Apollo $($prof.name) Allow"
        Remove-NetFirewallRule -DisplayName "$ruleNameAllow*" -ErrorAction SilentlyContinue
        
        $pBase = $prof.port_base
        $tcpPorts = "$($pBase - 5),$pBase,$($pBase + 1),$($pBase + 21)"
        $udpPorts = "$($pBase + 9),$($pBase + 10),$($pBase + 11),$($pBase + 13),$($pBase + 21)"

        New-NetFirewallRule -DisplayName "$ruleNameAllow TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort ($tcpPorts -split ',') -Profile Any | Out-Null
        New-NetFirewallRule -DisplayName "$ruleNameAllow UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort ($udpPorts -split ',') -Profile Any | Out-Null
        Write-Host "  [+] Firewall enforced: Universal Inbound Allow ($pBase)" -ForegroundColor Cyan
    }
}

Write-Host "`n[SUCCESS] Bootstrap complete. All instances synthesized with distinct UniqueIDs." -ForegroundColor Green
