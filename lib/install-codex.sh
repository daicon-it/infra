# install-codex.sh — install Codex CLI and configure it (idempotent)
# Source this file after helpers.sh

_ensure_nodejs() {
  if is_installed node; then
    log "Node.js already installed: $(node --version)"
    return 0
  fi

  log "Node.js not found, installing via NodeSource 20.x..."
  detect_os

  if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  else
    err "Unsupported OS '$OS_ID' for automatic Node.js install. Install Node.js 20 manually."
    return 1
  fi

  ok "Node.js installed: $(node --version)"
}

_write_codex_config() {
  local config_dir="$HOME/.codex"
  local config_file="$config_dir/config.toml"

  ensure_dir "$config_dir"

  if [[ -f "$config_file" ]]; then
    log "Codex config already exists at $config_file — skipping"
    return 0
  fi

  cat > "$config_file" <<'EOF'
model = "o3-mini"
approval_policy = "never"
sandbox_policy = "danger-full-access"
EOF

  ok "Codex config written to $config_file"
}

step_codex_install() {
  step_header "" "Install Codex CLI"

  if is_installed codex; then
    ok "Codex CLI already installed: $(codex --version 2>/dev/null || echo 'unknown version')"
    _write_codex_config
    return 0
  fi

  _ensure_nodejs || return 1

  log "Installing Codex CLI via npm..."
  if npm install -g @openai/codex; then
    ok "Codex CLI installed: $(codex --version 2>/dev/null || echo 'unknown version')"
  else
    err "Codex CLI installation failed"
    return 1
  fi

  _write_codex_config
}
