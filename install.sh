#!/bin/bash

# PassiveStack Auto-Installer
# Silent Mode - liest alles aus config/user-config.json

set -eE
trap 'echo "❌ Fehler in Zeile $LINENO"' ERR

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly LOG_FILE="/var/log/passivestack-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
    log "❌ FEHLER: $*"
    exit 1
}

# Prüfen ob root
if [[ $EUID -ne 0 ]]; then
   die "Dieses Skript muss als root ausgeführt werden"
fi

log "🚀 PassiveStack Installation gestartet..."

# Config laden
if [ ! -f "$CONFIG_DIR/user-config.json" ]; then
    die "❌ $CONFIG_DIR/user-config.json fehlt"
fi

# Python check
if ! command -v python3 &>/dev/null; then
    log "🐍 Python3 installieren..."
    apt-get update && apt-get install -y python3
fi

# Docker installieren
if ! command -v docker &>/dev/null; then
    log "🐳 Docker installieren..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker pi
fi

# Docker Compose installieren
if ! command -v docker-compose &>/dev/null; then
    log "📦 Docker Compose installieren..."
    apt-get install -y docker-compose
fi

# generate-compose.py ausführen
log "🔧 docker-compose.yaml generieren..."
python3 "$SCRIPT_DIR/generate-compose.py" || die "generate-compose.py fehlgeschlagen"

# systemd Service erstellen
log "サービ Systemd Service einrichten..."
cat > /etc/systemd/system/passivestack.service <<'EOF'
[Unit]
Description=PassiveStack Service
After=network.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'cd /home/pi/passivestack && docker-compose up -d'
WorkingDirectory=/home/pi/passivestack
User=pi
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable passivestack.service

log "✅ PassiveStack wurde installiert!"
log "🔄 Pi neustarten, um alle Dienste zu starten..."
reboot
