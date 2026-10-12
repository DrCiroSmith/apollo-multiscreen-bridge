# Apollo Multi-Screen Bridge - 1-Click Installation & Deployment Engine
# Requires Administrator privileges for firewall rules and interface metrics.
[CmdletBinding()]
param(
    [string]$ApolloDir = "C:\Program Files\Apollo",
    [switch]$NoAutoStart = $false,
    [switch]$SkipLaunch = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    APOLLO MULTI-SCREEN BRIDGE: 1-CLICK INSTALLER         " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# Check Admin Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrator privileges to configure firewall policies and interface metrics."
    Write-Host "Relaunching in elevated PowerShell prompt..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit 0
}

# Check Apollo/Sunshine directory
if (-not (Test-Path $ApolloDir)) {
    Write-Host "Apollo directory not found at $ApolloDir. Searching common locations..." -ForegroundColor Yellow
    $candidate = Get-Command "sunshine.exe" -ErrorAction SilentlyContinue
    if ($candidate) {
        $ApolloDir = Split-Path $candidate.Source -Parent
        Write-Host "Found Sunshine at: $ApolloDir" -ForegroundColor Green
    } else {
        Write-Error "Cannot locate Apollo / Sunshine installation. Please install Apollo or specify -ApolloDir."
        exit 1
    }
}

$repoRoot = $PSScriptRoot
$configDir = Join-Path $repoRoot "config"
$scriptsDir = Join-Path $repoRoot "scripts"
$profilesFile = Join-Path $configDir "profiles.json"
$sampleProfiles = Join-Path $configDir "profiles.sample.json"

# 1. Initialize profiles.json
if (-not (Test-Path $profilesFile)) {
    Write-Host "`n>>> [1/5] Initializing profiles configuration..." -ForegroundColor Yellow
    Copy-Item $sampleProfiles $profilesFile -Force
    Write-Host "  [+] Created config\profiles.json from sample." -ForegroundColor Green
} else {
    Write-Host "`n>>> [1/5] Using existing profiles.json configuration." -ForegroundColor Gray
}

# 2. Backup existing Apollo configurations
Write-Host "`n>>> [2/5] Creating safety snapshot of existing configurations..." -ForegroundColor Yellow
try {
    & (Join-Path $scriptsDir "restore_backup.ps1") -CreateBackupOnly -ProfilesPath $profilesFile
} catch {
    Write-Warning "Snapshot creation failed: $_"
}

# 3. Execute Bootstrap
Write-Host "`n>>> [3/5] Executing Bootstrap Generator..." -ForegroundColor Yellow
& (Join-Path $scriptsDir "bootstrap.ps1") -ProfilesPath $profilesFile

# 4. Create Desktop & Startup Shortcuts
Write-Host "`n>>> [4/5] Creating Windows Shortcuts..." -ForegroundColor Yellow
$wsh = New-Object -ComObject WScript.Shell
$vbsPath = Join-Path $scriptsDir "start_apollo_hidden.vbs"
$sunshineExe = Join-Path $ApolloDir "sunshine.exe"

# Desktop Shortcut
$desktopPath = [Environment]::GetFolderPath('Desktop')
$desktopLnk = Join-Path $desktopPath "Start Apollo Instances.lnk"
$shortcut = $wsh.CreateShortcut($desktopLnk)
$shortcut.TargetPath = "C:\Windows\System32\wscript.exe"
$shortcut.Arguments = "`"$vbsPath`""
$shortcut.WorkingDirectory = $scriptsDir
$shortcut.Description = "Start Dual/Multi-Screen Apollo Instances"
if (Test-Path $sunshineExe) {
    $shortcut.IconLocation = "$sunshineExe,0"
}
$shortcut.Save()
Write-Host "  [+] Desktop shortcut created: $desktopLnk" -ForegroundColor Green

# Startup Folder Shortcut
if (-not $NoAutoStart) {
    $startupPath = [Environment]::GetFolderPath('Startup')
    $startupLnk = Join-Path $startupPath "Start Apollo Instances.lnk"
    $startShortcut = $wsh.CreateShortcut($startupLnk)
    $startShortcut.TargetPath = "C:\Windows\System32\wscript.exe"
    $startShortcut.Arguments = "`"$vbsPath`""
    $startShortcut.WorkingDirectory = $scriptsDir
    $startShortcut.Description = "Auto-start Apollo Multi-Screen Instances on Login"
    if (Test-Path $sunshineExe) {
        $startShortcut.IconLocation = "$sunshineExe,0"
    }
    $startShortcut.Save()
    Write-Host "  [+] Startup shortcut enabled: $startupLnk" -ForegroundColor Green
}

# 5. Launch & Verify
if (-not $SkipLaunch) {
    Write-Host "`n>>> [5/5] Launching Supervisor & Verifying Instances..." -ForegroundColor Yellow
    & (Join-Path $scriptsDir "launch_and_heal.ps1") -ProfilesPath $profilesFile
    Start-Sleep -Seconds 2
    & (Join-Path $scriptsDir "selftest.ps1") -ProfilesPath $profilesFile
} else {
    Write-Host "`n>>> [5/5] Skipping launch per -SkipLaunch flag." -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "       APOLLO MULTI-SCREEN BRIDGE INSTALLED SUCCESSFULLY  " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "You can manage instances at any time using:" -ForegroundColor Cyan
Write-Host "  - Scripts:        $scriptsDir" -ForegroundColor Gray
Write-Host "  - Supervisor:     .\scripts\launch_and_heal.ps1" -ForegroundColor Gray
Write-Host "  - Health Test:    .\scripts\selftest.ps1" -ForegroundColor Gray
Write-Host "  - WebUIs:" -ForegroundColor Cyan
Write-Host "    * Instance 1 (iPad Wired):  https://127.0.0.1:47990" -ForegroundColor Gray
Write-Host "    * Instance 2 (iMac Direct): https://127.0.0.1:48090" -ForegroundColor Gray
Write-Host "    * Instance 3 (iPad Roam):   https://127.0.0.1:48190`n" -ForegroundColor Gray
