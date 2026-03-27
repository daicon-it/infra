# helpers.sh — color output and utility functions for machine-setup bootstrap
# Source this file: source "$(dirname "$0")/lib/helpers.sh"

# Colors
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_NC='\033[0m' # No Color

log()  { echo -e "${_CYAN}[INFO]${_NC}  $*"; }
ok()   { echo -e "${_GREEN}[ OK ]${_NC}  $*"; }
warn() { echo -e "${_YELLOW}[WARN]${_NC}  $*"; }
err()  { echo -e "${_RED}[ERR ]${_NC}  $*" >&2; }

# Print a numbered step header
# Usage: step_header 3 "Install ZSH"
step_header() {
  local num="$1"
  local name="$2"
  echo -e "\n${_BOLD}${_CYAN}=== Step ${num}: ${name} ===${_NC}"
}

# Check if a command is available in PATH
# Usage: is_installed curl && echo "yes"
is_installed() {
  command -v "$1" &>/dev/null
}

# Compare md5 checksums of two files
# Usage: checksum_match file1 file2
checksum_match() {
  local f1="$1" f2="$2"
  if [[ ! -f "$f1" || ! -f "$f2" ]]; then
    return 1
  fi
  local sum1 sum2
  sum1=$(md5sum "$f1" | awk '{print $1}')
  sum2=$(md5sum "$f2" | awk '{print $1}')
  [[ "$sum1" == "$sum2" ]]
}

# Create directory if it doesn't exist, with logging
# Usage: ensure_dir /some/path
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    log "Created directory: $dir"
  fi
}

# Detect OS from /etc/os-release, sets OS_ID and OS_VERSION
# Usage: detect_os; echo "$OS_ID $OS_VERSION"
detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
  else
    OS_ID="unknown"
    OS_VERSION="unknown"
    warn "Cannot detect OS: /etc/os-release not found"
  fi
  export OS_ID OS_VERSION
}
