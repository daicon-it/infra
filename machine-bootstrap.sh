#!/usr/bin/env bash
# machine-bootstrap.sh — Idempotent setup for daicon-it machines
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/daicon-it/infra/master/machine-bootstrap.sh | bash
#   bash machine-bootstrap.sh [--skills-only|--config-only|--force]
set -euo pipefail

REPO_INFRA="https://raw.githubusercontent.com/daicon-it/infra/master"
REPO_SKILLS="https://raw.githubusercontent.com/daicon-it/skills/master"
REPO_RAW="$REPO_INFRA"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
TMPDIR_BOOTSTRAP=""

# Parse args
SKILLS_ONLY=false
CONFIG_ONLY=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --skills-only) SKILLS_ONLY=true ;;
        --config-only) CONFIG_ONLY=true ;;
        --force) FORCE=true ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*"; }
step_header() { echo -e "\n${CYAN}━━━ Step $1: $2 ━━━${NC}"; }

get_file() {
    # Get file from local clone or download from GitHub
    local relpath="$1" dest="$2" base="${3:-$REPO_INFRA}"
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$relpath" ]]; then
        cp "$SCRIPT_DIR/$relpath" "$dest"
    else
        curl -fsSL "$base/$relpath" -o "$dest"
    fi
}

# ── Step 1: Claude CLI ──────────────────────────────────────────────
step_claude_install() {
    step_header 1 "Claude CLI"
    if [[ -f "$HOME/.local/bin/claude" ]]; then
        ok "Claude CLI native already installed"
        return
    fi
    if command -v claude &>/dev/null; then
        ok "Claude CLI found at $(which claude) — skip"
        return
    fi
    log "Installing Claude CLI (native)..."
    curl -fsSL https://claude.ai/install.sh | sh
    ok "Claude CLI installed"
}

# ── Step 2: Codex CLI ───────────────────────────────────────────────
step_codex_install() {
    step_header 2 "Codex CLI"
    if command -v codex &>/dev/null; then
        ok "Codex CLI already installed"
        return
    fi
    # Ensure Node.js
    if ! command -v node &>/dev/null; then
        log "Installing Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    fi
    log "Installing Codex CLI..."
    npm install -g @openai/codex
    # Config
    mkdir -p "$HOME/.codex"
    cat > "$HOME/.codex/config.toml" << 'TOML'
model = "o3-mini"
approval_policy = "never"
sandbox_policy = "danger-full-access"
TOML
    ok "Codex CLI installed"
}

# ── Step 3: Claude Config ───────────────────────────────────────────
step_config_install() {
    step_header 3 "Claude Config"
    mkdir -p "$HOME/.claude"

    # settings.json
    local dest="$HOME/.claude/settings.json"
    if [[ -f "$dest" ]] && [[ "$FORCE" != "true" ]]; then
        ok "settings.json already exists — skip (use --force to overwrite)"
    else
        get_file "config/settings.json" "$dest"
        ok "settings.json installed"
    fi

    # statusline-command.sh
    dest="$HOME/.claude/statusline-command.sh"
    get_file "config/statusline-command.sh" "$dest"
    chmod +x "$dest"
    ok "statusline-command.sh installed"
}

# ── Step 4: ZSH ─────────────────────────────────────────────────────
step_zsh_install() {
    step_header 4 "ZSH Config"
    if [[ -f "$HOME/.zshrc" ]] && grep -q "VPS Zsh Config" "$HOME/.zshrc" 2>/dev/null; then
        ok "vps-zsh-config already installed — skip"
        return
    fi
    # Install zsh if missing
    if ! command -v zsh &>/dev/null; then
        log "Installing zsh..."
        apt-get install -y zsh
    fi
    log "Installing vps-zsh-config..."
    bash <(curl -fsSL "$REPO_INFRA/zsh/install.sh") || warn "vps-zsh-config install failed (non-critical)"
    # Set default shell
    if [[ "$(getent passwd "$(whoami)" | cut -d: -f7)" != *"zsh"* ]]; then
        chsh -s "$(which zsh)" 2>/dev/null || warn "Could not set zsh as default shell"
    fi
    ok "ZSH configured"
}

# ── Step 5: Skills ──────────────────────────────────────────────────

discover_skills() {
    # Auto-discover skill directories from GitHub API
    curl -sf "https://api.github.com/repos/daicon-it/skills/contents/" 2>/dev/null \
        | python3 -c "import json,sys; [print(d['name']) for d in json.load(sys.stdin) if d['type']=='dir']" 2>/dev/null
}

install_skill() {
    local skill_name="$1"
    local skill_dir="$HOME/.claude/skills/$skill_name"

    if [[ -f "$skill_dir/SKILL.md" ]] && [[ "$FORCE" != "true" ]]; then
        ok "$skill_name already installed"
        return
    fi

    log "Installing $skill_name..."
    mkdir -p "$skill_dir"

    # Download SKILL.md (required)
    if ! curl -fsSL "$REPO_SKILLS/$skill_name/SKILL.md" -o "$skill_dir/SKILL.md" 2>/dev/null; then
        warn "$skill_name — no SKILL.md found, skipping"
        rm -rf "$skill_dir"
        return
    fi

    # Download subdirectories (references/, scripts/) if they exist
    local api_url="https://api.github.com/repos/daicon-it/skills/contents/$skill_name"
    local subdirs
    subdirs=$(curl -sf "$api_url" 2>/dev/null \
        | python3 -c "import json,sys; [print(d['name']) for d in json.load(sys.stdin) if d['type']=='dir']" 2>/dev/null || true)

    local file_count=1
    for subdir in $subdirs; do
        mkdir -p "$skill_dir/$subdir"
        # Get files in subdir
        local subfiles
        subfiles=$(curl -sf "$api_url/$subdir" 2>/dev/null \
            | python3 -c "import json,sys; [print(d['name']) for d in json.load(sys.stdin) if d['type']=='file']" 2>/dev/null || true)
        for f in $subfiles; do
            [[ -z "$f" ]] && continue
            curl -fsSL "$REPO_SKILLS/$skill_name/$subdir/$f" -o "$skill_dir/$subdir/$f" 2>/dev/null || continue
            [[ "$f" == *.sh ]] && chmod +x "$skill_dir/$subdir/$f"
            file_count=$((file_count + 1))
        done
    done

    ok "$skill_name installed ($file_count files)"
}

step_skills_install() {
    step_header 5 "Claude Code Skills"
    mkdir -p "$HOME/.claude/skills"

    # Auto-discover all skills from daicon-it/skills repo
    log "Discovering skills from daicon-it/skills..."
    local skill_list
    skill_list=$(discover_skills)

    if [[ -z "$skill_list" ]]; then
        warn "Could not fetch skill list from GitHub API, using fallback"
        skill_list="skills-db devops-agent watchdog-agent"
    fi

    local count=0
    while IFS= read -r skill_name; do
        [[ -z "$skill_name" ]] && continue
        install_skill "$skill_name"
        count=$((count + 1))
    done <<< "$skill_list"

    ok "Total: $count skills processed"
}

# ── Step 6: Health Check ────────────────────────────────────────────
step_health_check() {
    step_header 6 "Health Check"
    local fails=0

    # Claude
    if command -v claude &>/dev/null || [[ -f "$HOME/.local/bin/claude" ]]; then
        ok "Claude CLI"
    else err "Claude CLI not found"; fails=$((fails + 1)); fi

    # Codex
    if command -v codex &>/dev/null; then
        ok "Codex CLI"
    else warn "Codex CLI not found (non-critical)"; fi

    # Node
    if command -v node &>/dev/null; then
        ok "Node.js $(node --version)"
    else warn "Node.js not found"; fi

    # ZSH
    if command -v zsh &>/dev/null; then
        ok "ZSH"
    else warn "ZSH not found"; fi

    # Config files
    [[ -f "$HOME/.claude/settings.json" ]] && ok "settings.json" || { err "settings.json missing"; fails=$((fails + 1)); }
    [[ -x "$HOME/.claude/statusline-command.sh" ]] && ok "statusline-command.sh" || warn "statusline-command.sh missing"

    # Skills (dynamic check)
    local skill_count=0
    for sd in "$HOME/.claude/skills"/*/SKILL.md; do
        [[ -f "$sd" ]] || continue
        local sname
        sname=$(basename "$(dirname "$sd")")
        ok "skill: $sname"
        skill_count=$((skill_count + 1))
    done
    [[ $skill_count -eq 0 ]] && warn "No skills installed" || log "$skill_count skill(s) installed"

    # Skills-DB API
    if curl -sf "http://100.115.152.102:8410/health" &>/dev/null; then
        ok "Skills-DB API reachable"
    else
        warn "Skills-DB API unreachable (Tailscale may not be connected)"
    fi

    echo ""
    if [[ $fails -eq 0 ]]; then
        ok "All critical checks passed!"
    else
        err "$fails critical check(s) failed"
        return 1
    fi
}

# ── Main ─────────────────────────────────────────────────────────────
main() {
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  machine-setup — daicon-it bootstrap     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

    if [[ "$SKILLS_ONLY" == "true" ]]; then
        step_skills_install
        step_health_check
        return
    fi

    if [[ "$CONFIG_ONLY" == "true" ]]; then
        step_config_install
        step_health_check
        return
    fi

    step_claude_install
    step_codex_install
    step_config_install
    step_zsh_install
    step_skills_install
    step_health_check

    echo -e "\n${GREEN}Bootstrap complete!${NC}"
}

main
