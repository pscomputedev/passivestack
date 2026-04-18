#!/bin/bash
set -e

echo "========================================="
echo "   PassiveStack Pi Builder (Raspberry Pi)"
echo "========================================="

echo "📥 Aktualisiere Pakete..."
apt-get update -qq

echo "📦 Installiere notwendige Tools..."
apt-get install -y curl git docker.io docker-compose-plugin

echo "🔧 Docker Dienst aktivieren..."
systemctl enable --now docker

echo "📂 Erstelle Verzeichnisse..."
mkdir -p /opt/passivestack/config
cd /opt/passivestack

echo "📥 Klone Repository..."
git clone https://github.com/deinusername/passivestack.git .
# Falls du einen bestimmten Branch brauchst: git clone -b pi-build https://...

echo "📋 Konfigurationsdateien kopieren..."
cp -r config/* /opt/passivestack/config/

echo "🚀 Starte PassiveStack Services..."
cd /opt/passivestack
docker compose pull
docker compose up -d

echo "✅ PassiveStack Pi Image erfolgreich eingerichtet!"
echo "📊 Aktive Services: watchtower, honeygain, iproyal, pawns, repocket, traffmonetizer, packetstream, myst, earnfm"
echo ""
echo "Zugriff:"
echo "  - Traefik Dashboard: http://$(hostname -I | awk '{print $1}'):8080"
echo "  - Portainer:         http://$(hostname -I | awk '{print $1}'):9000"
echo ""
echo "Logs ansehen mit: docker compose logs -f"
