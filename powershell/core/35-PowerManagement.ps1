# Windows Host Power Management & Sleep Helpers

function sleepin {
    <#
    .SYNOPSIS
        Puts the Windows computer to sleep after a specified countdown in minutes.
    .PARAMETER Minutes
        Countdown duration in minutes (default: 30).
    .EXAMPLE
        sleepin
        sleepin 60
        sleepin 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [int]$Minutes = 30
    )

    if ($Minutes -lt 0) {
        Write-Error "Minutes must be >= 0"
        return
    }

    $scriptPath = "$global:DOTFILES_DIR\scripts\sleep.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -Minutes $Minutes
    } else {
        Write-Host "Computer will sleep in $Minutes minute(s). Press Ctrl+C to cancel." -ForegroundColor Yellow
        Start-Sleep -Seconds ($Minutes * 60)

        Add-Type -Namespace Win32 -Name Power -MemberDefinition @'
[DllImport("PowrProf.dll", SetLastError = true)]
public static extern bool SetSuspendState(
    bool hibernate,
    bool forceCritical,
    bool disableWakeEvent
);
'@ -ErrorAction SilentlyContinue

        [Win32.Power]::SetSuspendState($false, $false, $false) | Out-Null
    }
}

Set-Alias -Name winsleep -Value sleepin -Option AllScope -ErrorAction SilentlyContinue
