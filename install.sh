#!/bin/bash
# =============================================
# PassiveStack - Installationsskript
# =============================================
# Dieses Skript bereitet das System vor und installiert den gesamten Stack.

set -e

echo "🚀 PassiveStack Installation wird gestartet..."

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Prüfen ob als root ausgeführt
if [[ $EUID -ne 0 ]]; then
    error "Dieses Skript muss mit sudo oder als root ausgeführt werden!"
fi

log "System wird aktualisiert..."
apt-get update -qq
apt-get upgrade -y -qq

log "Benötigte Pakete werden installiert..."
apt-get install -y -qq curl git jq docker.io docker-compose-plugin

log "Docker wird aktiviert und gestartet..."
systemctl enable --now docker

log "Überprüfe Docker..."
if ! docker --version > /dev/null 2>&1; then
    error "Docker konnte nicht installiert werden!"
fi

# Verzeichnisse erstellen
log "Verzeichnisstruktur wird erstellt..."
mkdir -p /opt/passivestack/{config,data,media,logs,traefik}
chmod 755 /opt/passivestack
chmod 755 /opt/passivestack/data
chmod 755 /opt/passivestack/media

# Beispielkonfigurationen kopieren, falls noch nicht vorhanden
if [ ! -f /opt/passivestack/config/user-config.json ]; then
    log "user-config.json wird aus dem Beispiel erstellt..."
    cp /opt/passivestack/config/user-config.example.json /opt/passivestack/config/user-config.json 2>/dev/null || warn "user-config.example.json nicht gefunden. Bitte manuell anlegen."
fi

if [ ! -f /opt/passivestack/.env ]; then
    log ".env wird aus dem Beispiel erstellt..."
    cp /opt/passivestack/.env.example /opt/passivestack/.env 2>/dev/null || warn ".env.example nicht gefunden. Bitte manuell anlegen."
    warn "Bitte bearbeite nun die Datei /opt/passivestack/.env und passe alle Werte an!"
fi

log "Berechtigungen werden gesetzt..."
chown -R root:root /opt/passivestack
chmod 600 /opt/passivestack/.env 2>/dev/null || true
chmod 600 /opt/passivestack/config/user-config.json 2>/dev/null || true

log "Installation abgeschlossen! 🎉"
echo ""
echo "Nächste Schritte:"
echo "   1. Bearbeite die Konfigurationsdateien:"
echo "      nano /opt/passivestack/config/user-config.json"
echo "      nano /opt/passivestack/.env"
echo ""
echo "   2. Starte den Stack mit:"
echo "      cd /opt/passivestack && docker compose up -d"
echo ""
echo "Viel Erfolg mit PassiveStack!"

exit 0
