# Pester / Native PowerShell Configuration Validation
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Write-Host "Auditing Apollo Multi-Screen Bridge PowerShell scripts and profiles..." -ForegroundColor Cyan

# 1. Parse JSON configs
$Configs = @(
    (Join-Path (Join-Path $RepoRoot "config") "profiles.sample.json"),
    (Join-Path (Join-Path $RepoRoot "config") "profiles.json")
)

foreach ($Cfg in $Configs) {
    if (Test-Path $Cfg) {
        Write-Host "Validating JSON syntax: $Cfg"
        $Data = Get-Content $Cfg -Raw | ConvertFrom-Json
        if (-not $Data.profiles -or $Data.profiles.Count -lt 1) {
            throw "Invalid profile configuration in $Cfg"
        }
    }
}

# 2. Syntax check PowerShell scripts via AST parser (excluding .venv)
$PsScripts = Get-ChildItem -Path $RepoRoot -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.venv[\\/]' }
foreach ($File in $PsScripts) {
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors.Count -gt 0) {
        throw "PowerShell Syntax Error in $($File.Name): $($Errors[0].Message)"
    }
    Write-Host "  [OK] $($File.Name) passed syntax validation"
}

Write-Host "All Apollo configuration and PowerShell syntax audits passed successfully." -ForegroundColor Green
