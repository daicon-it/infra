# install-skills.sh — install Claude Code skills into ~/.claude/skills/ (idempotent)
# Source this file after helpers.sh

REPO_RAW="https://raw.githubusercontent.com/daicon-it/infra/master"

# Install a single skill by name
# Usage: install_skill "skills-db"
install_skill() {
  local name="$1"
  local skill_dir="$HOME/.claude/skills/$name"
  local skill_md="$skill_dir/SKILL.md"

  if [[ -f "$skill_md" ]]; then
    ok "Skill '$name' already installed — skipping"
    return 0
  fi

  log "Installing skill: $name"
  ensure_dir "$skill_dir"

  # Download SKILL.md
  if ! curl -fsSL "${REPO_RAW}/skills/${name}/SKILL.md" -o "$skill_md"; then
    err "Failed to download SKILL.md for skill '$name'"
    return 1
  fi

  # Extra files for devops-agent
  if [[ "$name" == "devops-agent" ]]; then
    _install_skill_devops_agent "$skill_dir"
  fi

  ok "Skill '$name' installed"
}

_install_skill_devops_agent() {
  local skill_dir="$1"

  # Download references/*.md
  local refs_dir="$skill_dir/references"
  ensure_dir "$refs_dir"

  # Fetch the list of reference files from the repo and download each
  log "Downloading devops-agent references..."
  local refs_index
  refs_index=$(curl -fsSL "${REPO_RAW}/skills/devops-agent/references/index.txt" 2>/dev/null || true)

  if [[ -n "$refs_index" ]]; then
    while IFS= read -r ref_file; do
      [[ -z "$ref_file" ]] && continue
      local dest="$refs_dir/$ref_file"
      ensure_dir "$(dirname "$dest")"
      if curl -fsSL "${REPO_RAW}/skills/devops-agent/references/${ref_file}" -o "$dest"; then
        log "  Downloaded references/$ref_file"
      else
        warn "  Failed to download references/$ref_file"
      fi
    done <<< "$refs_index"
  else
    warn "No references/index.txt found for devops-agent — skipping references"
  fi

  # Download scripts/*.sh
  local scripts_dir="$skill_dir/scripts"
  ensure_dir "$scripts_dir"

  log "Downloading devops-agent scripts..."
  local scripts_index
  scripts_index=$(curl -fsSL "${REPO_RAW}/skills/devops-agent/scripts/index.txt" 2>/dev/null || true)

  if [[ -n "$scripts_index" ]]; then
    while IFS= read -r script_file; do
      [[ -z "$script_file" ]] && continue
      local dest="$scripts_dir/$script_file"
      ensure_dir "$(dirname "$dest")"
      if curl -fsSL "${REPO_RAW}/skills/devops-agent/scripts/${script_file}" -o "$dest"; then
        chmod +x "$dest"
        log "  Downloaded scripts/$script_file (chmod +x)"
      else
        warn "  Failed to download scripts/$script_file"
      fi
    done <<< "$scripts_index"
  else
    warn "No scripts/index.txt found for devops-agent — skipping scripts"
  fi
}

step_skills_install() {
  step_header "" "Install Claude Code Skills"

  install_skill "skills-db"
  install_skill "devops-agent"
}
