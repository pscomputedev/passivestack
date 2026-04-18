#!/bin/bash
set -e

echo "=========================================="
echo "   PassiveStack Installer"
echo "=========================================="

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verzeichnisse erstellen
echo -e "${YELLOW}Erstelle Verzeichnisstruktur...${NC}"
mkdir -p config data/traefik data/portainer data/earnapp data/repocket
mkdir -p traefik

# Berechtigungen für acme.json
if [ ! -f data/traefik/acme.json ]; then
    echo -e "${YELLOW}Erstelle acme.json mit korrekten Rechten...${NC}"
    touch data/traefik/acme.json
    chmod 600 data/traefik/acme.json
fi

# generate-compose.py ausführbar machen
chmod +x generate-compose.py

# user-config.json prüfen
if [ ! -f config/user-config.json ]; then
    echo -e "${RED}Fehler: config/user-config.json nicht gefunden!${NC}"
    echo "Bitte erstelle diese Datei zuerst."
    exit 1
fi

# docker-compose.yaml generieren
echo -e "${YELLOW}Generiere docker-compose.yaml...${NC}"
if ! ./generate-compose.py; then
    echo -e "${RED}Fehler beim Generieren der compose Datei!${NC}"
    exit 1
fi

# Traefik Konfiguration kopieren falls nicht vorhanden
if [ ! -f traefik/traefik.yml ]; then
    echo -e "${YELLOW}Erstelle Standard-Traefik Konfiguration...${NC}"
    cat > traefik/traefik.yml << 'EOF'
global:
  checkNewVersion: true
  sendAnonymousUsage: false

entryPoints:
  web:
    address: :80
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: :443

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    exposedByDefault: false
    network: proxy
  file:
    directory: /etc/traefik
    watch: true

api:
  dashboard: true
  insecure: true

log:
  level: INFO
EOF
fi

# .env Datei erstellen falls nicht vorhanden
if [ ! -f .env ]; then
    echo -e "${YELLOW}Erstelle .env Datei...${NC}"
    cat > .env << EOF
TIMEZONE=Europe/Berlin
DOMAIN=yourdomain.com
EMAIL=your@email.com
EOF
fi

echo -e "${GREEN}Installation abgeschlossen!${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Passe config/user-config.json an (Domain, E-Mail, Credentials)"
echo "2. Starte die Stack mit: docker compose up -d"
echo "3. Überprüfe mit: docker compose ps"
echo ""
echo -e "${YELLOW}Wichtig:${NC} Nach Änderungen an user-config.json oder apps.json immer ./generate-compose.py ausführen!"
