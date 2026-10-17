# Base system, navigation, dev, and package management aliases

# ENVIRONMENT & RELOAD
alias rel='source ~/.bashrc'
alias rebash='exec bash'
alias insdf='bash "${DOTFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/install.sh"'
alias instools='bash "${DOTFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/scripts/install-tools.sh"'
alias insssh='insdf ssh'
alias inswsl='insdf wsl'
alias insmobile='insdf mobile'
alias insdocker='insdf docker'
alias insai='insdf ai'
alias insgit='insdf gitconfig'
alias ts='date +%s'

# PYTHON VENV
alias va='source .venv/bin/activate'
alias vd='deactivate'

# SYSTEM CONTROL
alias sc='systemctl'
alias scu='systemctl --user'
alias scr='sudo systemctl restart'
alias scs='systemctl status'
alias sce='sudo systemctl enable --now'
alias scd='sudo systemctl disable --now'
alias scdr='sudo systemctl daemon-reload'
alias scedit='sudo systemctl edit --full'

# JOURNAL
alias jc='journalctl'
alias jcs='journalctl -u'
alias jcf='journalctl -f -u'

# SECURITY & NETWORK CHECK
alias curlip='curl ifconfig.me' # Quick check of public IP
alias ports_listen='sudo lsof -i -P -n | grep LISTEN' # Check what's hogging ports

# APT PACKAGE MANAGEMENT
alias aupdate='sudo apt update'
alias aupgrade='sudo apt update && sudo apt upgrade -y'
alias ainstall='sudo apt install'
alias aremove='sudo apt remove'
alias asearch='apt search'
alias afix='sudo apt --fix-broken install'
aautoremove() {
  sudo apt autoremove --dry-run

  _confirm "Continue? [y/N] " &&
    sudo apt autoremove ||
    echo "Cancelled"
}

alias pg='ps aux | grep'

# FILE & SYSTEM & NAVIGATION
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -haltF' # Long list, hidden files, human sizes
alias la='ls -A'
alias l='ls -CF'
alias lsize='ls -lSrh' # Sort by size, largest at bottom
alias h='history | grep'
alias cls='clear'

alias cx='chmod +x'
alias chownme='sudo chown -R $USER:$USER'

alias rm='rm -i'
alias rmf='rm -rf'

alias lst4='tree -a -h -L 4'
alias lst3='tree -a -h -L 3'
alias lst2='tree -a -h -L 2'
alias lst1='tree -a -h -L 1'
alias lst='tree -a -h -L 1'

alias dus='du -sh * | sort -h'
alias dut='du -h --max-depth=1 . | sort -h'
alias dfh='df -h'
alias bigfiles='find . -type f -exec du -h {} + | sort -hr | head -20'
