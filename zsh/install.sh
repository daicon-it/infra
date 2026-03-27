#!/usr/bin/env bash
# =============================================================================
# VPS Zsh Environment Setup
# Compatible: Ubuntu 20.04/22.04, Debian 11/12
# Author: daicon-it
# =============================================================================

set -euo pipefail

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# --- Detect root vs normal user ---
if [[ $EUID -eq 0 ]]; then
    SUDO=""
    TARGET_USER="${SUDO_USER:-root}"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
else
    SUDO="sudo"
    TARGET_USER="$USER"
    TARGET_HOME="$HOME"
fi

info "Installing for user: $TARGET_USER (home: $TARGET_HOME)"

# =============================================================================
# 1. System packages
# =============================================================================
info "Updating package list and installing zsh, git, fzf..."
$SUDO apt-get update -qq
$SUDO apt-get install -y zsh git fzf curl wget
success "System packages installed."

# =============================================================================
# 2. Install lsd from GitHub releases
# =============================================================================
install_lsd() {
    info "Detecting architecture for lsd..."
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64)   LSD_ARCH="x86_64-unknown-linux-gnu" ;;
        arm64)   LSD_ARCH="aarch64-unknown-linux-gnu" ;;
        armhf)   LSD_ARCH="arm-unknown-linux-gnueabihf" ;;
        *)       error "Unsupported architecture: $ARCH" ;;
    esac

    LSD_VERSION=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

    if [[ -z "$LSD_VERSION" ]]; then
        warn "Could not fetch lsd version from GitHub. Trying fallback version 1.1.5..."
        LSD_VERSION="1.1.5"
    fi

    LSD_URL="https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd-v${LSD_VERSION}-${LSD_ARCH}.tar.gz"
    TMP_DIR=$(mktemp -d)

    info "Downloading lsd v${LSD_VERSION} for ${LSD_ARCH}..."
    curl -fsSL "$LSD_URL" -o "$TMP_DIR/lsd.tar.gz" \
        || error "Failed to download lsd from $LSD_URL"

    tar -xzf "$TMP_DIR/lsd.tar.gz" -C "$TMP_DIR"
    $SUDO install -m 0755 "$TMP_DIR/lsd-v${LSD_VERSION}-${LSD_ARCH}/lsd" /usr/local/bin/lsd
    rm -rf "$TMP_DIR"
    success "lsd v${LSD_VERSION} installed to /usr/local/bin/lsd."
}

if command -v lsd &>/dev/null; then
    warn "lsd already installed ($(lsd --version 2>/dev/null | head -1)). Skipping."
else
    install_lsd
fi

# =============================================================================
# 3. Set zsh as default shell
# =============================================================================
ZSH_PATH=$(command -v zsh)
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    info "Setting zsh as default shell for $TARGET_USER..."
    if [[ $EUID -eq 0 && "$TARGET_USER" == "root" ]]; then
        chsh -s "$ZSH_PATH" root
    else
        $SUDO chsh -s "$ZSH_PATH" "$TARGET_USER"
    fi
    success "Default shell set to $ZSH_PATH."
else
    warn "zsh is already the default shell. Skipping chsh."
fi

# =============================================================================
# 4. Clone zsh plugins
# =============================================================================
clone_or_update() {
    local repo="$1"
    local dest="$2"
    if [[ -d "$dest/.git" ]]; then
        info "Updating $(basename $dest)..."
        git -C "$dest" pull --ff-only --quiet
    else
        info "Cloning $(basename $dest)..."
        git clone --depth=1 --quiet "$repo" "$dest"
    fi
    success "$(basename $dest) ready."
}

clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "$TARGET_HOME/.zsh-syntax-highlighting"

clone_or_update "https://github.com/zsh-users/zsh-autosuggestions" \
    "$TARGET_HOME/.zsh-autosuggestions"

clone_or_update "https://github.com/agkozak/zsh-z" \
    "$TARGET_HOME/.zsh-z"

# =============================================================================
# 5. Create ~/.zshrc
# =============================================================================
info "Writing $TARGET_HOME/.zshrc..."

cat > "$TARGET_HOME/.zshrc" << 'ZSHRC_EOF'
# =============================================================================
# ~/.zshrc — VPS Zsh Config (mirroring Termux setup)
# =============================================================================

# --- Prompt (Powerline-style, dark grey bg / green path) ---
# Segment: dark grey (color 236) background, green foreground path, Powerline arrow
PROMPT="%K{236}%F{green} %~ %f%K{0}%F{236}\ue0b0%k%f "

# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# --- Options ---
setopt AUTO_CD
setopt CORRECT
setopt GLOB_DOTS
setopt NO_BEEP

# --- Completion ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# --- Plugins ---
[[ -f ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -f ~/.zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source ~/.zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f ~/.zsh-z/zsh-z.plugin.zsh ]] && \
    source ~/.zsh-z/zsh-z.plugin.zsh

# --- fzf key bindings ---
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && \
    source /usr/share/doc/fzf/examples/key-bindings.zsh

# Fallback path for newer fzf packages
[[ -f /usr/share/fzf/key-bindings.zsh ]] && \
    source /usr/share/fzf/key-bindings.zsh

# --- lsd alias ---
alias ls="lsd"
alias ll="lsd -l"
alias la="lsd -la"
alias lt="lsd --tree"

# --- LS_COLORS ---
export LS_COLORS="\
di=1;34:\
*.zip=1;31:*.tar=1;31:*.gz=1;31:*.bz2=1;31:*.xz=1;31:*.7z=1;31:*.rar=1;31:\
*.png=1;35:*.jpg=1;35:*.jpeg=1;35:*.gif=1;35:*.webp=1;35:*.svg=1;35:\
*.mp4=1;35:*.mkv=1;35:*.avi=1;35:*.mov=1;35:\
*.pdf=1;33:*.doc=1;33:*.docx=1;33:*.odt=1;33:*.xls=1;33:*.xlsx=1;33:\
*.sh=1;32:*.bash=1;32:*.zsh=1;32:*.py=1;32:*.rb=1;32:*.pl=1;32:\
*.yaml=1;36:*.yml=1;36:*.json=1;36:*.toml=1;36:*.xml=1;36:\
*.txt=1;37:*.md=1;37:*.rst=1;37:\
*.log=0;37"

# --- Useful aliases ---
alias grep="grep --color=auto"
alias cp="cp -i"
alias mv="mv -i"
alias df="df -h"
alias du="du -h"
alias free="free -h"

# --- PATH additions ---
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
ZSHRC_EOF

success "$TARGET_HOME/.zshrc written."

# =============================================================================
# 6. Create ~/.config/lsd/config.yaml
# =============================================================================
info "Writing lsd config..."
mkdir -p "$TARGET_HOME/.config/lsd"

cat > "$TARGET_HOME/.config/lsd/config.yaml" << 'LSD_EOF'
# lsd configuration — fancy icons, custom colors
icons:
  when: auto
  theme: fancy
  separator: " "

color:
  when: auto
  theme: custom

layout: grid
classic: false
blocks:
  - permission
  - user
  - group
  - size
  - date
  - name

date: relative
sorting:
  column: name
  reverse: false
  dir-grouping: first

total-size: false
hyperlink: never
LSD_EOF

# Custom color theme for lsd
mkdir -p "$TARGET_HOME/.config/lsd/themes"
cat > "$TARGET_HOME/.config/lsd/themes/custom.yaml" << 'THEME_EOF'
# lsd custom color theme
user: 230
group: 187
permission:
  read: dark_green
  write: dark_yellow
  exec: dark_red
  exec-sticky: 5
  no-access: 245
  octal: 6
  acl: dark_cyan
  context: cyan
date:
  hour-old: 40
  day-old: 42
  older: 36
size:
  none: dark_cyan
  small: 229
  medium: 216
  large: 172
inode:
  valid: 13
  invalid: 245
links:
  valid: 13
  invalid: 245
tree-edge: 245
git-status:
  default: 245
  unmodified: 245
  ignored: 245
  new-in-index: dark_green
  new-in-workdir: dark_green
  typechange: dark_yellow
  deleted: dark_red
  renamed: dark_green
  modified: dark_yellow
  conflicted: dark_red
THEME_EOF

success "lsd config written."

# Fix ownership if running as root for another user
if [[ $EUID -eq 0 && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_USER" \
        "$TARGET_HOME/.zshrc" \
        "$TARGET_HOME/.zsh-syntax-highlighting" \
        "$TARGET_HOME/.zsh-autosuggestions" \
        "$TARGET_HOME/.zsh-z" \
        "$TARGET_HOME/.config/lsd"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
success "============================================"
success " Zsh environment setup complete!"
success "============================================"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "  1. Install MesloLGS NF font on your terminal/SSH client"
echo "     for correct Powerline glyph rendering."
echo "  2. Log out and back in (or run: exec zsh)"
echo "  3. Enjoy your new shell!"
echo ""
