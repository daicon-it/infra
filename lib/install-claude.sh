# install-claude.sh — install Claude CLI natively (idempotent)
# Source this file after helpers.sh

step_claude_install() {
  step_header "" "Install Claude CLI"

  # Already installed natively — skip
  if [[ -f "$HOME/.local/bin/claude" ]]; then
    ok "Claude CLI already installed natively at ~/.local/bin/claude"
    "$HOME/.local/bin/claude" --version 2>/dev/null || true
    return 0
  fi

  # Found somewhere else (npm or other) — don't touch it
  if is_installed claude; then
    local claude_path
    claude_path=$(command -v claude)
    warn "Claude CLI found at $claude_path (not native install). Skipping."
    return 0
  fi

  # Install via official native installer
  log "Installing Claude CLI via native installer..."
  if curl -fsSL https://claude.ai/install.sh | sh; then
    ok "Claude CLI installed successfully"
    "$HOME/.local/bin/claude" --version 2>/dev/null || true
  else
    err "Claude CLI installation failed"
    return 1
  fi
}
