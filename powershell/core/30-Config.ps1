# Quick configuration opener for Windows PowerShell (conf)

function conf {
    param(
        [Parameter(Position = 0)]
        [string]$Key = ""
    )

    $dotfiles = if ($global:DOTFILES_DIR) { $global:DOTFILES_DIR } else { "$env:USERPROFILE\.config\dotfiles" }

    $configMap = [ordered]@{
        "profile"    = $PROFILE
        "pwprofile"  = "$dotfiles\powershell\profile.ps1"
        "git"        = "$env:USERPROFILE\.gitconfig"
        "gitdot"     = "$dotfiles\.gitconfig"
        "ssh"        = "$env:USERPROFILE\.ssh\config"
        "claude"     = "$env:USERPROFILE\.claude\settings.json"
        "cmdlog"     = "$dotfiles\powershell\core\15-CmdLog.ps1"
        "ali"        = "$dotfiles\powershell\core\10-BaseAliases.ps1"
        "shims"      = "$dotfiles\powershell\core\00-PlatformShims.ps1"
        "wsl"        = "$dotfiles\powershell\core\20-WslHost.ps1"
        "starship"   = "$env:USERPROFILE\.config\starship.toml"
    }

    # Discover additional .ps1 scripts in powershell/
    $extraScripts = Get-ChildItem -Path "$dotfiles\powershell\core\*.ps1" -ErrorAction SilentlyContinue
    foreach ($s in $extraScripts) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($s.Name)
        if (-not $configMap.Contains($base)) {
            $configMap[$base] = $s.FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($Key)) {
        Write-Host "=== Available Configurations ===" -ForegroundColor Cyan
        foreach ($k in $configMap.Keys) {
            Write-Host ("  {0,-12} {1}" -f $k, $configMap[$k])
        }
        $Key = Read-Host "`nEnter key to open"
        if ([string]::IsNullOrWhiteSpace($Key)) { return }
    }

    if ($configMap.Contains($Key)) {
        $target = $configMap[$Key]
        $editor = if ($env:EDITOR) {
            $env:EDITOR
        } elseif (Get-Command code -ErrorAction SilentlyContinue) {
            "code"
        } else {
            "notepad.exe"
        }

        Write-Host "Opening $target with $editor..." -ForegroundColor Green
        & $editor $target
    } else {
        Write-Warning "Configuration '$Key' not found in registry."
    }
}
