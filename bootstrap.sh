#!/usr/bin/env bash
# ============================================================
# PassiveStack — bootstrap.sh
# Installiert alle Voraussetzungen auf frischem Raspberry Pi OS
# Danach install.sh ausführen für die App-Konfiguration.
#
# Ausführen:
#   curl -fsSL https://raw.githubusercontent.com/pscomputedev/passivestack/main/bootstrap.sh | bash
#   oder: bash bootstrap.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️ ${NC} $*"; }
err()  { echo -e "${RED}❌${NC} $*"; exit 1; }
log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }

LOG_FILE="/var/log/passivestack-bootstrap.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

if [[ "${EUID}" -ne 0 ]]; then
  err "Bitte als root ausführen: sudo bash bootstrap.sh"
fi

echo ""
echo -e "${YELLOW}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║      ☀️  PassiveStack Bootstrap               ║"
echo "  ║   Raspberry Pi OS — Ersteinrichtung          ║"
echo "  ║         passivecompute.de  v1.3              ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

log "Bootstrap gestartet: $(date)"
log "Hostname: $(hostname)"
log "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"

log "System aktualisieren..."
apt-get update -qq
apt-get upgrade -y -qq
ok "System aktuell"

log "Basis-Pakete installieren..."
apt-get install -y -qq \
  curl wget git unzip \
  python3 python3-pip python3-venv \
  jq bc \
  ca-certificates gnupg \
  lsb-release \
  qemu-user-static \
  2>/dev/null
ok "Basis-Pakete installiert"

log "PyYAML installieren..."
pip3 install pyyaml --break-system-packages -q 2>/dev/null || \
pip3 install pyyaml -q 2>/dev/null
ok "PyYAML installiert"

if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker --version | grep -oP '\d+\.\d+')
  ok "Docker bereits installiert: ${DOCKER_VER}"
else
  log "Docker installieren..."
  curl -fsSL https://get.docker.com | bash -s -- --quiet
  ok "Docker installiert"
fi

systemctl enable docker --quiet
systemctl start docker

# QEMU für amd64 Emulation registrieren (für TraffMonetizer, Bitping)
log "QEMU binfmt registrieren..."
docker run --privileged --rm tonistiigi/binfmt --install all 2>/dev/null || true
ok "QEMU binfmt registriert"

PI_USER="${SUDO_USER:-pi}"
if id "${PI_USER}" &>/dev/null; then
  usermod -aG docker "${PI_USER}"
  ok "User ${PI_USER} zur docker-Gruppe hinzugefügt"
fi

CMDLINE="/boot/firmware/cmdline.txt"
if [[ ! -f "${CMDLINE}" ]]; then
  CMDLINE="/boot/cmdline.txt"
fi
if [[ -f "${CMDLINE}" ]]; then
  if ! grep -q "cgroup_memory=1" "${CMDLINE}"; then
    log "cgroup memory aktivieren..."
    sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' "${CMDLINE}"
    ok "cgroup memory aktiviert (wirkt nach Reboot)"
  else
    ok "cgroup memory bereits aktiviert"
  fi
fi

log "sysctl optimieren..."
cat >> /etc/sysctl.conf << 'EOF'

# PassiveStack: UDP socket exhaustion fix
net.ipv4.ip_local_port_range = 1024 60999
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
EOF
sysctl -p -q
ok "sysctl optimiert"

log "Docker DNS konfigurieren..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "dns-opts": ["ndots:1"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"}
}
EOF
systemctl restart docker
ok "Docker DNS konfiguriert"

INSTALL_DIR="/home/${PI_USER}/passivestack"
log "PassiveStack installieren nach ${INSTALL_DIR}..."

if [[ -d "${INSTALL_DIR}" ]]; then
  warn "Verzeichnis existiert bereits — überspringe Download"
else
  if command -v git &>/dev/null; then
    sudo -u "${PI_USER}" git clone \
      https://github.com/pscomputedev/passivestack.git \
      "${INSTALL_DIR}" 2>/dev/null || \
    {
      warn "Git-Clone fehlgeschlagen — versuche direkten Download"
      mkdir -p "${INSTALL_DIR}"
      curl -fsSL https://github.com/pscomputedev/passivestack/archive/refs/heads/main.zip \
        -o /tmp/passivestack.zip
      unzip -q /tmp/passivestack.zip -d /tmp/
      cp -r /tmp/passivestack-main/* "${INSTALL_DIR}/"
      rm -f /tmp/passivestack.zip
    }
  fi
  chown -R "${PI_USER}:${PI_USER}" "${INSTALL_DIR}"
fi

if [[ -f "${INSTALL_DIR}/install.sh" ]]; then
  chmod +x "${INSTALL_DIR}/install.sh"
  chmod +x "${INSTALL_DIR}/status-updater.sh" 2>/dev/null || true
  ok "PassiveStack bereit"
else
  warn "install.sh nicht gefunden — bitte manuell entpacken"
fi

# config/apps.json aus Repo holen falls nicht vorhanden
if [[ ! -f "${INSTALL_DIR}/config/apps.json" ]]; then
  log "config/apps.json herunterladen..."
  mkdir -p "${INSTALL_DIR}/config"
  curl -fsSL https://raw.githubusercontent.com/pscomputedev/passivestack/main/config/apps.json \
    -o "${INSTALL_DIR}/config/apps.json"
  chown -R "${PI_USER}:${PI_USER}" "${INSTALL_DIR}/config"
  ok "config/apps.json heruntergeladen"
fi

log "Status-Updater Cron-Job einrichten..."
CRON_LINE="* * * * * cd ${INSTALL_DIR} && bash status-updater.sh"
(crontab -u "${PI_USER}" -l 2>/dev/null | grep -v "status-updater"; \
 echo "${CRON_LINE}") | crontab -u "${PI_USER}" -
ok "Status-Updater Cron-Job eingerichtet"

echo ""
echo -e "${GREEN}${BOLD}  Bootstrap abgeschlossen!${NC}"
echo ""
echo -e "  Nächster Schritt:"
echo -e "  ${CYAN}cd ~/passivestack && ./install.sh${NC}"
echo ""
warn "Reboot empfohlen für cgroup memory Aktivierung:"
echo -e "  ${CYAN}sudo reboot${NC}"
echo ""
