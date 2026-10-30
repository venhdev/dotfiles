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
Set-Alias -Name which -Value where.exe -ErrorAction SilentlyContinue

# History Search (PSReadLine persistent history, default limit: 10)
function h {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Arg1 = "",
        [Parameter(Position = 1)]
        [string]$Arg2 = "",
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    $query = ""
    $limit = 10

    $allArgs = @()
    if ($Arg1) { $allArgs += $Arg1 }
    if ($Arg2) { $allArgs += $Arg2 }
    if ($RemainingArgs) { $allArgs += $RemainingArgs }

    switch ($allArgs.Count) {
        0 {
            $query = ""
            $limit = 10
        }
        1 {
            if ($allArgs[0] -match '^[0-9]+$') {
                $limit = [int]$allArgs[0]
                $query = ""
            } else {
                $query = $allArgs[0]
                $limit = 10
            }
        }
        default {
            $last = $allArgs[-1]
            if ($last -match '^[0-9]+$') {
                $limit = [int]$last
                $query = ($allArgs[0..($allArgs.Count - 2)] -join " ")
            } elseif ($allArgs[0] -match '^[0-9]+$') {
                $limit = [int]$allArgs[0]
                $query = ($allArgs[1..($allArgs.Count - 1)] -join " ")
            } else {
                $query = ($allArgs -join " ")
                $limit = 10
            }
        }
    }

    if ($limit -le 0) { $limit = 10 }

    $histPath = $null
    if (Get-Command Get-PSReadLineOption -ErrorAction SilentlyContinue) {
        $histPath = (Get-PSReadLineOption).HistorySavePath
    }
    if (-not $histPath -or -not (Test-Path $histPath)) {
        $candidates = @(
            "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
            "$env:APPDATA\Microsoft\PowerShell\PSReadLine\ConsoleHost_history.txt",
            "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $histPath = $c; break }
        }
    }

    $results = @()
    if ($histPath -and (Test-Path $histPath)) {
        $lines = Get-Content -Path $histPath -ErrorAction SilentlyContinue
        if (-not $lines) { return }

        $lines = @($lines | Where-Object { $_ -notmatch '^\s*h(\s+|$)' })

        if ($query) {
            $filtered = $lines | Where-Object { $_ -like "*$query*" }
            $results = @($filtered | Select-Object -Unique | Select-Object -Last $limit)
        } else {
            $results = @($lines | Select-Object -Last $limit)
        }
    } else {
        if ($query) {
            $results = @(Get-History | Where-Object { $_.CommandLine -like "*$query*" } | Select-Object -Last $limit | ForEach-Object { $_.CommandLine })
        } else {
            $results = @(Get-History -Count $limit | ForEach-Object { $_.CommandLine })
        }
    }

    for ($i = 0; $i -lt $results.Count; $i++) {
        Write-Host (" {0,2}) " -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
        Write-Host $results[$i]
    }
}

# Profile edit shortcut (delegates to canonical 'conf profile')
function ep { conf profile }

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
