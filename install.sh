#!/bin/bash
set -e

echo "=========================================="
echo "   PassiveStack Installer - GitHub Edition"
echo "=========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Prüfe Verzeichnisstruktur...${NC}"

# Verzeichnisse sicherstellen
mkdir -p config data/traefik data/portainer data/earnapp data/repocket traefik

# acme.json mit korrekten Rechten (wird beim ersten Docker-Start gesetzt)
if [ ! -f data/traefik/acme.json ]; then
    echo -e "${YELLOW}Erstelle acme.json...${NC}"
    touch data/traefik/acme.json
    chmod 600 data/traefik/acme.json 2>/dev/null || true
fi

# generate-compose.py muss ausführbar sein
chmod +x generate-compose.py 2>/dev/null || true

echo -e "${YELLOW}Prüfe user-config.json...${NC}"
if [ ! -f config/user-config.json ]; then
    echo -e "${RED}Fehler: config/user-config.json fehlt!${NC}"
    echo "Bitte lege diese Datei zuerst an (siehe vorherige Schritte)."
    exit 1
fi

echo -e "${YELLOW}Generiere docker-compose.yml...${NC}"
if ! ./generate-compose.py; then
    echo -e "${RED}Fehler beim Generieren von docker-compose.yml!${NC}"
    exit 1
fi

# Standard-Traefik-Konfiguration
if [ ! -f traefik/traefik.yml ]; then
    echo -e "${YELLOW}Erstelle traefik/traefik.yml...${NC}"
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
      email: your@email.com
      storage: /acme.json
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

# .env Datei
if [ ! -f .env ]; then
    echo -e "${YELLOW}Erstelle .env Datei...${NC}"
    cat > .env << EOF
TIMEZONE=Europe/Berlin
DOMAIN=yourdomain.com
EMAIL=your@email.com
EOF
fi

echo ""
echo -e "${GREEN}✅ Installation erfolgreich abgeschlossen!${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Passe config/user-config.json an (Tokens, Domain, E-Mail)"
echo "2. Führe aus: ./generate-compose.py"
echo "3. Commit + Push die Änderungen"
echo "4. Auf dem Server: docker compose up -d"
echo ""
echo -e "${YELLOW}Hinweis: chmod-Befehle werden im GitHub-Editor ignoriert.${NC}"
echo "         Der executable-Bit wird über den Commit gesetzt."
