# TOOLS
alias claudebypass='claude --dangerously-skip-permissions'
alias clpp=claudebypass
alias pn='pnpm'
alias ocwatch='pn openclaw setup && pn gateway:watch'
alias ocstop='pn openclaw gateway stop'

# System control (`-u`, `cat` type manually)
alias sc='systemctl'
alias scu='systemctl --user'

alias scr='sudo systemctl restart'
alias scs='systemctl status'
alias sce='sudo systemctl enable --now'
alias scd='sudo systemctl disable --now'
alias scdr='sudo systemctl daemon-reload'
alias scedit='sudo systemctl edit --full'

## Journal
alias jc='journalctl'
alias jcs='journalctl -u'
alias jcf='journalctl -f -u'

# SECURITY & NETWORK CHECK
alias curlip='curl ifconfig.me' # Quick check of public IP
alias ports_listen='sudo lsof -i -P -n | grep LISTEN' # Check what's hogging ports

# APT PACKAGE MANAGEMENT
alias update='sudo apt update'
alias upgrade='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias fixapt='sudo apt --fix-broken install'
alias check-autoremove='apt list --autoremove'

alias pg='ps aux | grep'

# FILE & SYSTEM & NAVIGATION
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -haltF' # Long list, hidden files, human sizes
alias la='ls -A'
alias l='ls -CF'
alias lsize='ls -lSrh'           # Sort by size, largest at bottom
alias h='history | grep'
alias cls='clear'

alias cx='chmod +x'
alias chownme='sudo chown -R $USER:$USER'

## Some more alias to avoid making mistakes:
# alias cp='cp -i'
# alias mv='mv -i'
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

# DOCKER & DEVOPS
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcl='docker system prune -a --volumes'
