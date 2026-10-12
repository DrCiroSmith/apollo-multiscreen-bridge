# Apollo Multi-Screen Bridge - Snapshot Backup & Restore Engine
[CmdletBinding()]
param(
    [string]$ProfilesPath = "$PSScriptRoot\..\config\profiles.json",
    [string]$SnapshotName = "",
    [switch]$List = $false,
    [switch]$CreateBackupOnly = $false
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ProfilesPath)) {
    $ProfilesPath = "$PSScriptRoot\..\config\profiles.sample.json"
}
$rawJson = Get-Content $ProfilesPath -Raw | ConvertFrom-Json
$sunshineDir = $rawJson.general.sunshine_dir
$backupRoot = if ($rawJson.general.backup_dir) { $rawJson.general.backup_dir } else { Join-Path $sunshineDir "backups" }

if (-not (Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    APOLLO MULTI-SCREEN BRIDGE: BACKUP & RESTORE         " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# Function: Create Snapshot
function New-ApolloSnapshot {
    param([string]$Tag = "manual")
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $destName = "snapshot-$Tag-$timestamp"
    $destPath = Join-Path $backupRoot $destName
    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    
    foreach ($prof in $rawJson.profiles) {
        $sourceDir = Join-Path $sunshineDir $prof.config_dir
        if (Test-Path $sourceDir) {
            $destSub = Join-Path $destPath $prof.config_dir
            Copy-Item -Path $sourceDir -Destination $destSub -Recurse -Force
        }
    }
    # Also backup profiles.json
    Copy-Item $ProfilesPath (Join-Path $destPath "profiles.json") -Force
    
    Write-Host "  [+] Created snapshot: $destName" -ForegroundColor Green
    return $destName
}

# Listing Snapshots
if ($List) {
    Write-Host "`nAvailable Backups in ${backupRoot}:" -ForegroundColor Yellow
    $snapshots = Get-ChildItem -Path $backupRoot -Directory | Sort-Object CreationTime -Descending
    if ($snapshots.Count -eq 0) {
        Write-Host "  (No snapshots found)" -ForegroundColor Gray
    } else {
        $snapshots | ForEach-Object {
            Write-Host "  - $($_.Name)  [$($_.CreationTime)]" -ForegroundColor Cyan
        }
    }
    exit 0
}

# Create backup only
if ($CreateBackupOnly) {
    Write-Host "`n>>> Creating on-demand configuration snapshot..." -ForegroundColor Yellow
    New-ApolloSnapshot -Tag "user"
    exit 0
}

# Restore Snapshot
if (-not $SnapshotName) {
    Write-Host "`nAvailable snapshots to restore:" -ForegroundColor Yellow
    $snapshots = Get-ChildItem -Path $backupRoot -Directory | Sort-Object CreationTime -Descending
    if ($snapshots.Count -eq 0) {
        Write-Error "No snapshots available to restore."
        exit 1
    }
    $snapshots | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Cyan
    }
    Write-Host "`nUsage: .\restore_backup.ps1 -SnapshotName <SnapshotFolderName>" -ForegroundColor Yellow
    exit 0
}

$targetSnapshotPath = Join-Path $backupRoot $SnapshotName
if (-not (Test-Path $targetSnapshotPath)) {
    Write-Error "Snapshot '$SnapshotName' does not exist in $backupRoot."
    exit 1
}

Write-Host "`n[!] Target Snapshot: $SnapshotName" -ForegroundColor Yellow
Write-Host "[1/3] Creating safety rollback snapshot before overwrite..." -ForegroundColor Gray
New-ApolloSnapshot -Tag "pre-restore-rollback"

Write-Host "[2/3] Stopping any running Apollo/Sunshine processes..." -ForegroundColor Gray
Get-Process -Name "sunshine" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

Write-Host "[3/3] Restoring configurations from snapshot..." -ForegroundColor Gray
foreach ($prof in $rawJson.profiles) {
    $srcSub = Join-Path $targetSnapshotPath $prof.config_dir
    $destSub = Join-Path $sunshineDir $prof.config_dir
    if (Test-Path $srcSub) {
        if (-not (Test-Path $destSub)) {
            New-Item -ItemType Directory -Path $destSub -Force | Out-Null
        }
        Copy-Item -Path "$srcSub\*" -Destination $destSub -Recurse -Force
        Write-Host "  [+] Restored config for $($prof.name) to $destSub" -ForegroundColor Green
    }
}

if (Test-Path (Join-Path $targetSnapshotPath "profiles.json")) {
    Copy-Item (Join-Path $targetSnapshotPath "profiles.json") $ProfilesPath -Force
    Write-Host "  [+] Restored profiles.json" -ForegroundColor Green
}

Write-Host "`n[SUCCESS] Snapshot '$SnapshotName' successfully restored!" -ForegroundColor Green
Write-Host "Run .\launch_and_heal.ps1 to start the restored configuration." -ForegroundColor Cyan
