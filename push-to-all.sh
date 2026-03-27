#!/usr/bin/env bash
# push-to-all.sh — Deploy bootstrap to all daicon-it machines
# Run from CT 101 only
set -euo pipefail

BOOTSTRAP_URL="https://raw.githubusercontent.com/daicon-it/infra/master/machine-bootstrap.sh"
PROXMOX_HOST="root@100.93.132.32"
FLAGS="${1:-}"  # e.g. --skills-only, --config-only, --force

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

declare -A MACHINES=(
    ["hiplet-66136"]="ssh:root@193.168.199.43"
    ["hiplet-36312"]="ssh:root@138.124.125.174"
    ["hiplet-48342"]="ssh:root@193.168.199.249"
    ["PC-001"]="ssh:ss@100.105.50.119"
    ["PC-002"]="ssh:ss@100.80.73.127"
    ["CT-231"]="pct:231"
    ["CT-232"]="pct:232"
    ["CT-233"]="pct:233"
    ["CT-234"]="pct:234"
)

run_on() {
    local name="$1" spec="$2"
    local type="${spec%%:*}" target="${spec##*:}"

    echo -e "\n${CYAN}>>> $name ($spec)${NC}"

    if [[ "$type" == "ssh" ]]; then
        ssh -o ConnectTimeout=10 "$target" \
            "curl -fsSL $BOOTSTRAP_URL | bash -s -- $FLAGS" 2>&1 | sed 's/^/  /' || \
            echo -e "  ${RED}FAILED${NC}"
    elif [[ "$type" == "pct" ]]; then
        ssh -o ConnectTimeout=10 "$PROXMOX_HOST" \
            "pct exec $target -- bash -c 'curl -fsSL $BOOTSTRAP_URL | bash -s -- $FLAGS'" 2>&1 | sed 's/^/  /' || \
            echo -e "  ${RED}FAILED${NC}"
    fi
}

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  push-to-all — deploy to all machines    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo "Flags: ${FLAGS:-none}"

for name in "${!MACHINES[@]}"; do
    run_on "$name" "${MACHINES[$name]}"
done

echo -e "\n${GREEN}Done! Check output above for any failures.${NC}"
