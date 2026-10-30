# Dotfiles PowerShell Root Profile
# Sourced by $PROFILE (Microsoft.PowerShell_profile.ps1)

$global:DOTFILES_DIR = if ($env:DOTFILES) {
    $env:DOTFILES
} elseif (Test-Path "$env:USERPROFILE\.config\dotfiles") {
    "$env:USERPROFILE\.config\dotfiles"
} else {
    Split-Path -Parent $PSScriptRoot
}

# 1. Load Core PowerShell Components
$coreScripts = Get-ChildItem -Path "$global:DOTFILES_DIR\powershell\core\*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($script in $coreScripts) {
    . $script.FullName
}

# 2. Load Local Machine Configurations if present
$localPs1 = "$global:DOTFILES_DIR\local\local.ps1"
if (Test-Path $localPs1) {
    . $localPs1
}

# 3. Reload helper
function rel {
    if ($PROFILE -and (Test-Path $PROFILE)) {
        . $PROFILE
        Write-Host "✓ Reloaded $PROFILE" -ForegroundColor Green
    } else {
        . "$global:DOTFILES_DIR\powershell\profile.ps1"
        Write-Host "✓ Reloaded Dotfiles PowerShell profile" -ForegroundColor Green
    }
}
