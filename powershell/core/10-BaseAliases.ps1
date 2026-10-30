# Base navigation, python virtualenv, and convenience shortcuts for PowerShell

# Navigation Shortcuts
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# File Listing
function ll { Get-ChildItem -Path (Get-Item -Path $PWD) }
function la { Get-ChildItem -Path (Get-Item -Path $PWD) -Force }

# Screen Clear
Set-Alias -Name cl -Value Clear-Host -ErrorAction SilentlyContinue

# Executable Path Lookup (equivalent to POSIX 'which')
Set-Alias -Name wh -Value where.exe -ErrorAction SilentlyContinue
Set-Alias -Name which -Value where.exe -ErrorAction SilentlyContinue

# Edit PowerShell Profile
function ep {
    $editor = if ($env:EDITOR) {
        $env:EDITOR
    } elseif (Get-Command code -ErrorAction SilentlyContinue) {
        "code"
    } else {
        "notepad.exe"
    }
    Write-Host "Opening $PROFILE with $editor..." -ForegroundColor Green
    & $editor $PROFILE
}
Set-Alias -Name confprof -Value ep -ErrorAction SilentlyContinue

# Inspect Environment Variables across Process, User, and Machine scopes
function gete {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    @(
        [pscustomobject]@{
            Scope = 'Process'
            Value = [Environment]::GetEnvironmentVariable($Name, 'Process')
        }
        [pscustomobject]@{
            Scope = 'User'
            Value = [Environment]::GetEnvironmentVariable($Name, 'User')
        }
        [pscustomobject]@{
            Scope = 'Machine'
            Value = [Environment]::GetEnvironmentVariable($Name, 'Machine')
        }
    )
}

# Python Virtual Environment activation
function va {
    $venvPaths = @(
        ".venv\Scripts\Activate.ps1",
        "venv\Scripts\Activate.ps1",
        "env\Scripts\Activate.ps1"
    )
    foreach ($p in $venvPaths) {
        if (Test-Path $p) {
            . $p
            Write-Host "✓ Activated $p" -ForegroundColor Green
            return
        }
    }
    Write-Warning "No virtualenv found at .venv, venv, or env"
}

function vd {
    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
        Write-Host "✓ Virtual environment deactivated" -ForegroundColor Green
    } else {
        Write-Warning "No active virtual environment detected."
    }
}

# Quick Timestamp
function ts { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

# Public IP Check
function curlip { (Invoke-RestMethod -Uri "https://ifconfig.me" -TimeoutSec 5).Trim() }
