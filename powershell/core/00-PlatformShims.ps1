# Cross-platform shims for Windows PowerShell (clip, open, pkg, sudo)

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
function pkg {
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
        "update" {
            switch ($mgr) {
                "winget" { winget.exe source update }
                "scoop"  { scoop update }
                "choco"  { choco.exe upgrade all -y --noop }
            }
        }
        "upgrade" {
            switch ($mgr) {
                "winget" { winget.exe upgrade --all }
                "scoop"  { scoop update * }
                "choco"  { choco.exe upgrade all -y }
            }
        }
        { $_ -in "install", "add" } {
            switch ($mgr) {
                "winget" { winget.exe install @RemainingArgs }
                "scoop"  { scoop install @RemainingArgs }
                "choco"  { choco.exe install @RemainingArgs -y }
            }
        }
        { $_ -in "remove", "uninstall" } {
            switch ($mgr) {
                "winget" { winget.exe uninstall @RemainingArgs }
                "scoop"  { scoop uninstall @RemainingArgs }
                "choco"  { choco.exe uninstall @RemainingArgs -y }
            }
        }
        "search" {
            switch ($mgr) {
                "winget" { winget.exe search @RemainingArgs }
                "scoop"  { scoop search @RemainingArgs }
                "choco"  { choco.exe search @RemainingArgs }
            }
        }
        default {
            Write-Host @"
Usage: pkg <command> [arguments...]

Supported commands:
  pkg update             Refresh package indexes
  pkg upgrade            Upgrade all installed packages
  pkg install <package>  Install a package
  pkg remove <package>   Uninstall a package
  pkg search <query>     Search for packages

Active manager detected: $mgr
"@
        }
    }
}
