# Dotfiles Windows PowerShell Installer
# Usage:
#   irm https://raw.githubusercontent.com/venhdev/dotfiles/main/install.ps1 | iex

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/venhdev/dotfiles.git",
    [string]$TargetDir = "$env:USERPROFILE\.config\dotfiles"
)

$ErrorActionPreference = "Stop"

Write-Host @"
============================================================
      Dotfiles Installer for Windows (PowerShell)
============================================================
"@ -ForegroundColor Cyan

# 1. Clone or Update Dotfiles Repository
if (Test-Path "$TargetDir\.git") {
    Write-Host "Updating existing dotfiles repository at $TargetDir..." -ForegroundColor Green
    try {
        git -C $TargetDir pull --rebase
    } catch {
        Write-Warning "Failed to auto-update via git pull. Proceeding with existing checkout."
    }
} elseif (Test-Path $TargetDir) {
    Write-Host "Found directory at $TargetDir without .git. Using existing files." -ForegroundColor Yellow
} else {
    Write-Host "Cloning dotfiles from $RepoUrl to $TargetDir..." -ForegroundColor Green
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone $RepoUrl $TargetDir
    } else {
        Write-Error "Git is required to clone dotfiles. Please install Git for Windows (winget install Git.Git) and retry."
        return
    }
}

# 2. Configure PowerShell $PROFILE
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$markerStart = "# Load dotfiles"
$markerEnd = "# End dotfiles"
$loaderBlock = @"
$markerStart
`$global:DOTFILES_DIR = "$TargetDir"
`$dotfilesLoader = "$TargetDir\powershell\profile.ps1"
if (Test-Path `$dotfilesLoader) { . `$dotfilesLoader }
$markerEnd
"@

$existingContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
if (-not $existingContent) { $existingContent = "" }

if ($existingContent -like "*$markerStart*") {
    Write-Host "Refreshing dotfiles loader hook in $PROFILE..." -ForegroundColor Green
    $pattern = "(?s)" + [regex]::Escape($markerStart) + ".*?" + [regex]::Escape($markerEnd) + "\r?\n?"
    $updatedContent = [regex]::Replace($existingContent, $pattern, "")
    $updatedContent = $updatedContent.TrimEnd() + "`r`n`r`n" + $loaderBlock + "`r`n"
    Set-Content -Path $PROFILE -Value $updatedContent -Encoding utf8
} else {
    Write-Host "Adding dotfiles loader hook to $PROFILE..." -ForegroundColor Green
    Add-Content -Path $PROFILE -Value ("`r`n" + $loaderBlock) -Encoding utf8
}

# 3. Global Git Configuration Integration
$gitConfigPath = "$TargetDir\.gitconfig"
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path $gitConfigPath)) {
    $currentIncludes = git config --global --get-all include.path 2>$null
    if ($currentIncludes -notcontains $gitConfigPath) {
        Write-Host "Configuring global git include.path -> $gitConfigPath" -ForegroundColor Green
        git config --global --add include.path $gitConfigPath
    }
}

Write-Host @"

============================================================
✓ Dotfiles installation for Windows completed successfully!
============================================================

To activate in current session, run:
  . `$PROFILE

Or type 'rel' after reloading.
"@ -ForegroundColor Cyan
