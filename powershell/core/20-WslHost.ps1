# Windows Host WSL Management & Maintenance Helpers

function wslcompact {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )

    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        Write-Warning 'Administrator privileges required. Please reopen PowerShell as Administrator.'
        return
    }

    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $status = wsl.exe -l -v 2>$null
        if ($status -match '\bRunning\b') {
            Write-Warning "WSL instances are currently running."
            $ans = Read-Host "Run 'wsl --shutdown' now? [Y/n]"
            if ($ans -eq '' -or $ans -match '^[Yy]$') {
                Write-Host "Shutting down WSL instances..." -ForegroundColor Yellow
                wsl.exe --shutdown
                Start-Sleep -Seconds 2
            } else {
                Write-Warning "Please shut down WSL before compacting disk."
                return
            }
        }
    }

    # Auto-discover VHDX if path was not explicitly provided
    if (-not $Path) {
        $found = @()
        $searchRoots = @(
            "$env:LOCALAPPDATA\Packages",
            "$env:LOCALAPPDATA\wsl"
        )
        foreach ($root in $searchRoots) {
            if (Test-Path $root) {
                $found += Get-ChildItem -Path $root -Filter "ext4.vhdx" -Recurse -Depth 4 -ErrorAction SilentlyContinue
            }
        }

        if ($found.Count -eq 1) {
            $defaultPath = $found[0].FullName
            $promptAns = Read-Host ("Found VHDX: {0}`nUse this file? [Y/n/custom path]" -f $defaultPath)
            if ($promptAns -eq '' -or $promptAns -match '^[Yy]$') {
                $Path = $defaultPath
            } elseif ($promptAns -notmatch '^[Nn]$') {
                $Path = $promptAns
            }
        } elseif ($found.Count -gt 1) {
            Write-Host "Found multiple WSL VHDX files:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $found.Count; $i++) {
                $sz = [Math]::Round($found[$i].Length / 1GB, 2)
                Write-Host ("  {0}) [{1} GB] {2}" -f ($i + 1), $sz, $found[$i].FullName)
            }
            $pick = Read-Host "Select [1-$($found.Count), or enter custom path]"
            if ($pick -match '^[0-9]+$' -and [int]$pick -ge 1 -and [int]$pick -le $found.Count) {
                $Path = $found[[int]$pick - 1].FullName
            } else {
                $Path = $pick
            }
        }

        if (-not $Path) {
            $Path = Read-Host 'Enter full VHDX path'
        }
    }

    $Path = $Path.Trim('"').Trim("'")
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Error "VHDX file not found: $Path"
        return
    }

    Import-Module Hyper-V -ErrorAction SilentlyContinue
    $hasOpt = [bool](Get-Command Optimize-VHD -ErrorAction SilentlyContinue)
    $method = if ($hasOpt) {
        $choice = Read-Host 'Backend [1=Optimize-VHD (Hyper-V), 2=DiskPart] (default: 1)'
        if ($choice -eq '2') { 'DiskPart' } else { 'Optimize-VHD' }
    } else {
        Write-Warning 'Optimize-VHD unavailable (Hyper-V feature not installed); using DiskPart fallback.'
        'DiskPart'
    }

    $mode = 'Full'
    if ($method -eq 'Optimize-VHD') {
        $modeChoice = Read-Host 'Mode [1=Quick, 2=Full, 3=Retrim] (default: 2)'
        $mode = switch ($modeChoice) {
            '1' { 'Quick' }
            '3' { 'Retrim' }
            default { 'Full' }
        }
    }

    $before = (Get-Item -LiteralPath $Path).Length / 1GB
    Write-Host "`nTarget:  $Path" -ForegroundColor Cyan
    Write-Host ("Backend: {0} ({1}) | Current size: {2:N2} GB" -f $method, $mode, $before) -ForegroundColor Yellow
    $confirm = Read-Host 'Press Enter to begin compaction, or Ctrl+C to cancel'

    try {
        if ($method -eq 'Optimize-VHD') {
            Optimize-VHD -Path $Path -Mode $mode -ErrorAction Stop
        } else {
            $tmp = New-TemporaryFile
            try {
                @("select vdisk file=`"$Path`"", 'compact vdisk', 'exit') |
                    Set-Content -LiteralPath $tmp.FullName -Encoding ASCII
                $result = & diskpart.exe /s $tmp.FullName 2>&1
                $result | Write-Host
                if ($LASTEXITCODE -ne 0 -or $result -match '(?i)\berror\b|failed') {
                    throw ($result -join "`n")
                }
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Error "Compaction failed: $($_.Exception.Message)"
        return
    }

    $after = (Get-Item -LiteralPath $Path).Length / 1GB
    $saved = $before - $after
    Write-Host @"

============================================================
✓ VHDX Compaction Complete
============================================================
  Before: {0:N2} GB
  After:  {1:N2} GB
  Saved:  {2:N2} GB
============================================================
"@ -f $before, $after, $saved -ForegroundColor Green
}
