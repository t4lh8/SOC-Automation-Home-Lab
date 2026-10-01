#!/usr/bin/env bash
#
# One-command deploy of the SOC lab server stack (Wazuh + Shuffle + TheHive)
# onto a fresh Ubuntu 22.04 host. Idempotent: safe to re-run.
#
# Usage (on the cloud VM):
#   cp .env.example .env    # then edit .env
#   sudo ./setup.sh
#
# It installs Docker, then brings up each component from its official deployment,
# pinned to a known version. The Windows endpoint (Wazuh Agent + Sysmon) is set up
# separately - see docs/03-windows-agent-sysmon.md.

set -euo pipefail

# ---- config ----
WAZUH_VERSION="${WAZUH_VERSION:-v4.9.2}"
STACK_DIR="${STACK_DIR:-/opt/soc-lab}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$HERE/.env" ] && set -a && . "$HERE/.env" && set +a || true

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root (sudo ./setup.sh)."

# ---- preflight: memory ----
mem_gb=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
log "Detected ${mem_gb} GB RAM"
if [ "$mem_gb" -lt 12 ]; then
  warn "The full stack (Wazuh + Shuffle + TheHive) wants ~16 GB."
  warn "On a smaller host, run only part of it: ./setup.sh wazuh   (or shuffle / thehive)."
fi

# ---- Docker ----
install_docker() {
  if command -v docker >/dev/null 2>&1; then log "Docker already installed"; return; fi
  log "Installing Docker Engine + Compose plugin"
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git jq >/dev/null
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null
  systemctl enable --now docker
}

# The indexer/opensearch in Wazuh and Shuffle need a high vm.max_map_count.
tune_kernel() {
  if ! grep -q 'vm.max_map_count=262144' /etc/sysctl.conf 2>/dev/null; then
    echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
  fi
  sysctl -q -w vm.max_map_count=262144
}

deploy_wazuh() {
  log "Deploying Wazuh single-node (${WAZUH_VERSION})"
  local dir="$STACK_DIR/wazuh-docker"
  if [ ! -d "$dir" ]; then
    git clone -q --branch "$WAZUH_VERSION" --depth 1 https://github.com/wazuh/wazuh-docker.git "$dir"
  fi
  cd "$dir/single-node"
  if [ ! -d config/wazuh_indexer_ssl_certs ] || [ -z "$(ls -A config/wazuh_indexer_ssl_certs 2>/dev/null)" ]; then
    log "Generating indexer certificates"
    docker compose -f generate-indexer-certs.yml run --rm generator
  fi
  docker compose up -d
  log "Wazuh dashboard: https://<server-ip>  (default admin / change it immediately)"
}

deploy_shuffle() {
  log "Deploying Shuffle (SOAR)"
  local dir="$STACK_DIR/Shuffle"
  if [ ! -d "$dir" ]; then
    git clone -q --depth 1 https://github.com/Shuffle/Shuffle "$dir"
  fi
  cd "$dir"
  mkdir -p shuffle-database && chown -R 1000:1000 shuffle-database
  docker compose up -d
  log "Shuffle: https://<server-ip>:3443  (create the admin user on first visit)"
}

deploy_thehive() {
  log "Deploying TheHive + Cassandra"
  local dir="$HERE/thehive"
  cd "$dir"
  docker compose up -d
  log "TheHive: http://<server-ip>:9000  (finish the setup wizard on first visit)"
}

install_docker
tune_kernel

case "${1:-all}" in
  wazuh)   deploy_wazuh ;;
  shuffle) deploy_shuffle ;;
  thehive) deploy_thehive ;;
  all)     deploy_wazuh; deploy_shuffle; deploy_thehive ;;
  *)       die "Unknown target '$1'. Use: all | wazuh | shuffle | thehive" ;;
esac

log "Done. Next:"
cat <<'NEXT'
  1. Open each dashboard (URLs above) and set strong passwords.
  2. Load the custom rules and config from wazuh/  (see docs/02 and docs/03).
  3. Build the Shuffle workflow            (see shuffle/ and docs/05).
  4. Point your Windows 10 agent at this host's IP (docs/03).
  5. Run the Mimikatz detection test       (docs/04) and watch the workflow fire.

  To avoid cloud charges when you're done testing:  terraform destroy  (see deploy/terraform/).
NEXT
