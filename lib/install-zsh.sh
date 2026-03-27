# install-zsh.sh — install vps-zsh-config from GitHub (idempotent)
# Source this file after helpers.sh

step_zsh_install() {
  step_header "" "Install ZSH Config (vps-zsh-config)"

  # Check if already installed
  if [[ -f "$HOME/.zshrc" ]] && grep -q "VPS Zsh Config" "$HOME/.zshrc" 2>/dev/null; then
    ok "vps-zsh-config already installed (marker found in ~/.zshrc)"
  else
    log "Installing vps-zsh-config..."
    if bash <(curl -fsSL https://raw.githubusercontent.com/daicon-it/vps-zsh-config/main/install.sh); then
      ok "vps-zsh-config installed successfully"
    else
      err "vps-zsh-config installation failed"
      return 1
    fi
  fi

  # Ensure zsh is installed
  if ! is_installed zsh; then
    err "zsh binary not found after install — something went wrong"
    return 1
  fi

  # Change default shell to zsh if it's not already
  local current_shell
  current_shell=$(getent passwd root | cut -d: -f7)
  local zsh_path
  zsh_path=$(which zsh)

  if [[ "$current_shell" != "$zsh_path" ]]; then
    log "Changing default shell to zsh ($zsh_path)..."
    chsh -s "$zsh_path"
    ok "Default shell changed to $zsh_path"
  else
    ok "Default shell is already zsh ($zsh_path)"
  fi
}
