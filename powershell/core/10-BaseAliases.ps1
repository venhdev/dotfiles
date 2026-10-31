# Base navigation, python virtualenv, and convenience shortcuts for PowerShell

# Navigation Shortcuts
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# File Listing
function ll { Get-ChildItem -Path (Get-Item -Path $PWD) }
function la { Get-ChildItem -Path (Get-Item -Path $PWD) -Force }

# Directory Disk Usage (Cross-Platform 'dirsize' / 'ds')
function dirsize {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".",
        [Parameter(Position = 1)]
        [int]$Top = 0
    )

    $targetPath = $Path
    if ($Path -match '^[0-9]+$' -and $Top -eq 0) {
        $Top = [int]$Path
        $targetPath = "."
    }

    $targetDir = try {
        if (Test-Path -LiteralPath $targetPath) {
            (Resolve-Path -LiteralPath $targetPath -ErrorAction Stop).Path
        } else {
            (Resolve-Path -Path $targetPath -ErrorAction Stop).Path
        }
    } catch {
        Write-Error "Directory not found: $targetPath"
        return
    }

    $subDirs = @(Get-ChildItem -LiteralPath $targetDir -Directory -Force -ErrorAction SilentlyContinue)
    if ($subDirs.Count -eq 0) {
        Write-Host "No subdirectories found in '$targetDir'." -ForegroundColor Yellow
        return
    }

    $results = if ($PSVersionTable.PSVersion.Major -ge 7) {
        $subDirs | ForEach-Object -Parallel {
            $dirPath = $_.FullName.TrimEnd('\')
            $raw = robocopy $dirPath NULL /L /S /NFL /NDL /NJH /NC /NP /BYTES /XJ /R:0 /W:0 2>$null
            $bytes = 0L
            $text = $raw -join "`n"
            if ($text -match 'Bytes\s*:\s*(\d+)') {
                $bytes = [int64]$Matches[1]
            }

            $human = switch ($bytes) {
                { $_ -ge 1GB } { "{0:N2} GB" -f ($_ / 1GB); break }
                { $_ -ge 1MB } { "{0:N2} MB" -f ($_ / 1MB); break }
                { $_ -ge 1KB } { "{0:N2} KB" -f ($_ / 1KB); break }
                default        { "$_ B" }
            }

            [PSCustomObject]@{
                Folder     = $_.Name
                Size       = $human
                GB         = [math]::Round($bytes / 1GB, 3)
                TotalBytes = $bytes
            }
        } -ThrottleLimit 8
    } else {
        foreach ($d in $subDirs) {
            $dirPath = $d.FullName.TrimEnd('\')
            $raw = robocopy $dirPath NULL /L /S /NFL /NDL /NJH /NC /NP /BYTES /XJ /R:0 /W:0 2>$null
            $bytes = 0L
            $text = $raw -join "`n"
            if ($text -match 'Bytes\s*:\s*(\d+)') {
                $bytes = [int64]$Matches[1]
            }

            $human = switch ($bytes) {
                { $_ -ge 1GB } { "{0:N2} GB" -f ($_ / 1GB); break }
                { $_ -ge 1MB } { "{0:N2} MB" -f ($_ / 1MB); break }
                { $_ -ge 1KB } { "{0:N2} KB" -f ($_ / 1KB); break }
                default        { "$_ B" }
            }

            [PSCustomObject]@{
                Folder     = $d.Name
                Size       = $human
                GB         = [math]::Round($bytes / 1GB, 3)
                TotalBytes = $bytes
            }
        }
    }

    $sorted = $results | Sort-Object TotalBytes -Descending
    if ($Top -gt 0) {
        $sorted = $sorted | Select-Object -First $Top
    }

    $sorted
}
Set-Alias -Name ds -Value dirsize -ErrorAction SilentlyContinue

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

# Inspect Environment Variables (run 'gete' to list all, or 'gete <Name>' to query specific variable)
function gete {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Get-ChildItem Env: | Sort-Object Name | Select-Object Name, Value
        return
    }

    $procVal = [Environment]::GetEnvironmentVariable($Name, 'Process')
    $userVal = [Environment]::GetEnvironmentVariable($Name, 'User')
    $machVal = [Environment]::GetEnvironmentVariable($Name, 'Machine')

    if ($null -eq $procVal -and $null -eq $userVal -and $null -eq $machVal) {
        Write-Warning "Environment variable '$Name' not found."
        return
    }

    @(
        [pscustomobject]@{
            Name  = $Name
            Scope = 'Process'
            Value = $procVal
        }
        [pscustomobject]@{
            Name  = $Name
            Scope = 'User'
            Value = $userVal
        }
        [pscustomobject]@{
            Name  = $Name
            Scope = 'Machine'
            Value = $machVal
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

# Dotfiles Installer & Module Helpers (Cross-Platform parity with POSIX)
function insdf {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Modules
    )

    $installerPs1 = "$global:DOTFILES_DIR\install.ps1"
    if (-not (Test-Path $installerPs1)) {
        $installerPs1 = "$env:USERPROFILE\.config\dotfiles\install.ps1"
    }

    if ($Modules.Count -eq 0 -and (Test-Path $installerPs1)) {
        & $installerPs1
    } elseif (Get-Command bash.exe -ErrorAction SilentlyContinue) {
        $installerSh = "$global:DOTFILES_DIR/install.sh" -replace '\\', '/'
        bash.exe $installerSh @Modules
    } elseif (Test-Path $installerPs1) {
        & $installerPs1
    } else {
        Write-Error "Dotfiles installer not found at $global:DOTFILES_DIR"
    }
}

function instools  { insdf tools }
function insssh    { insdf ssh }
function inswsl    { insdf wsl }
function insmobile { insdf mobile }
function insdocker { insdf docker }
function insai     { insdf ai }
function insgit    { insdf gitconfig }
