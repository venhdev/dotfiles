param(
    [Parameter(Position = 0)]
    [int]$Minutes = 30
)

if ($Minutes -lt 0) {
    Write-Error "Minutes must be >= 0"
    exit 1
}

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
