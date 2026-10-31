# Cross-platform shims for Windows PowerShell (clip, open, zen, sudo)

# Detect Windows Host Environment (supports both PowerShell 5.1 Desktop and PowerShell Core 7+)
$global:IsWindowsHost = ($PSEdition -eq 'Desktop') -or [bool]$IsWindows

# Clipboard Helper
function clip {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]$InputObject
    )
    begin {
        $piped = [System.Collections.Generic.List[string]]::new()
    }
    process {
        if ($null -ne $InputObject) {
            $piped.Add([string]$InputObject)
        }
    }
    end {
        if ($piped.Count -gt 0) {
            Set-Clipboard -Value ($piped -join [Environment]::NewLine)
        } elseif ($args) {
            Set-Clipboard -Value ($args -join ' ')
        } else {
            Get-Clipboard
        }
    }
}

# Open Target (Explorer / Default App)
function open_target {
    param(
        [string]$Target = "."
    )
    if (Test-Path $Target) {
        Invoke-Item $Target
    } else {
        Start-Process $Target
    }
}

# Universal Package Manager shim (winget / scoop)
function zen {
    param(
        [Parameter(Position = 0)]
        [string]$Action = "help",
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    $mgr = if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        "winget"
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        "scoop"
    } elseif (Get-Command choco.exe -ErrorAction SilentlyContinue) {
        "choco"
    } else {
        $null
    }

    if (-not $mgr) {
        Write-Error "No supported package manager found on Windows (winget, scoop, choco)."
        return
    }

    switch ($Action) {
        { $_ -in "update", "up" } {
            switch ($mgr) {
                "winget" { winget.exe source update }
                "scoop"  { scoop update }
                "choco"  { choco.exe upgrade all -y --noop }
            }
        }
        "upgrade" {
            if ($RemainingArgs.Count -eq 0) {
                Write-Warning "Notice: 'zen upgrade' requires an explicit target to prevent unintended system-wide changes."
                Write-Host @"
Usage:
  zen upgrade --all       Upgrade system packages AND managed tools
  zen upgrade system      Upgrade system package manager only
  zen upgrade <package>   Upgrade or reinstall specific package
"@
                return
            }
            switch ($mgr) {
                "winget" { winget.exe upgrade --all }
                "scoop"  { scoop update * }
                "choco"  { choco.exe upgrade all -y }
            }
        }
        { $_ -in "install", "add", "i" } {
            if ($RemainingArgs.Count -eq 0) {
                Write-Error "Error: Missing package name. Usage: zen i <package...>"
                return
            }
            switch ($mgr) {
                "winget" { winget.exe install @RemainingArgs }
                "scoop"  { scoop install @RemainingArgs }
                "choco"  { choco.exe install @RemainingArgs -y }
            }
        }
        { $_ -in "remove", "uninstall", "rm" } {
            if ($RemainingArgs.Count -eq 0) {
                Write-Error "Error: Missing package name to remove. Usage: zen rm <package...>"
                return
            }
            switch ($mgr) {
                "winget" { winget.exe uninstall @RemainingArgs }
                "scoop"  { scoop uninstall @RemainingArgs }
                "choco"  { choco.exe uninstall @RemainingArgs -y }
            }
        }
        "search" {
            if ($RemainingArgs.Count -eq 0) {
                Write-Error "Error: Missing search query. Usage: zen search <query>"
                return
            }
            switch ($mgr) {
                "winget" { winget.exe search @RemainingArgs }
                "scoop"  { scoop search @RemainingArgs }
                "choco"  { choco.exe search @RemainingArgs }
            }
        }
        { $_ -in "setup", "init" } {
            if (Get-Command insdf -ErrorAction SilentlyContinue) {
                insdf @RemainingArgs
            } else {
                Write-Error "Dotfiles setup command not available."
            }
        }
        default {
            Write-Host @"
Usage: zen <command> [arguments...]

Headless Package Management:
  zen i <package...>     Install a package (shorthand for zen install)
  zen rm <package...>    Uninstall a package (shorthand for zen remove)
  zen update             Refresh package indexes
  zen upgrade --all      Upgrade all installed packages
  zen search <query>     Search for packages

Ecosystem & Workstation:
  zen setup [modules...] Run dotfiles installer & module setup

Active manager detected: $mgr
"@
        }
    }
}
