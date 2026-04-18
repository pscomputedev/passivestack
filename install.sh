#!/bin/bash
set -e

######################################
# PassiveStack - Setup Script v1.2
######################################

echo "🚀 PassiveStack Installer wird gestartet..."

# Root-Check
if [[ $EUID -eq 0 ]]; then
   echo "❌ Bitte nicht als root ausführen. Docker wird ohnehin benötigt."
   exit 1
fi

# Plattform feststellen
PLATFORM=$(uname -m)
DOCKER_COMPOSE_CMD="docker compose"

echo "🔍 Plattform: $PLATFORM"

# Prüfung: Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Docker ist nicht installiert. Installation wird gestartet..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker wurde installiert. Bitte Terminal NEU STARTEN oder 'newgrp docker' ausführen."
    echo "💡 Danach install.sh erneut ausführen."
    exit 0
fi

# Prüfung: docker compose
if ! $DOCKER_COMPOSE_CMD version &> /dev/null; then
    echo "🔧 'docker compose' nicht gefunden. Bitte Docker Compose Plugin installieren."
    echo "💡 Ubuntu/Debian: sudo apt install docker-compose-plugin"
    exit 1
fi

# Abhängigkeiten
if ! command -v python3 &> /dev/null; then
    echo "🐍 Python3 fehlt. Installiere..."
    sudo apt update && sudo apt install -y python3
fi

# Setup config Ordner
mkdir -p config/data

# Template config kopieren (falls noch nicht existent)
if [ ! -f "config/user-config.json" ]; then
    echo "📝 Erstelle config/user-config.json aus Template..."
    cp config/user-config.example.json config/user-config.json
fi

# Generate compose
echo "⚙️ Generiere docker-compose.yml..."
python3 generate-compose.py

# App Token Abfrage
echo "🔐 App-Token Konfiguration"

ask_field() {
    local app=$1
    local key=$2
    local value=$(jq -r ".apps.$app.$key" config/user-config.json 2>/dev/null)
    if [[ "$value" == "null" ]] || [[ -z "$value" ]] || [[ "$value" == *"dein-"* ]]; then
        read -p "[$app] $key: " input
        jq ".apps.$app.$key = \"$input\"" config/user-config.json > tmp.$$.json && mv tmp.$$.json config/user-config.json
    fi
}

# Nur aktive Apps abfragen
for app in earnapp honeygain iproyal packetstream peer2profit traffmonetizer repocket earnfm bitping mysterium; do
    isActive=$(jq -r ".overrides.$app.enabled // (.apps.$app | if .enabled_by_default == true then \"true\" else \"false\" end)" config/apps.json config/user-config.json | tail -n1)
    if [[ "$isActive" == "true" ]]; then
        echo ""
        echo "🔹 $app Setup"
        case "$app" in
            earnapp)
                ask_field earnapp EARNAPP_UUID
                ;;
            honeygain)
                ask_field honeygain HONEYGAIN_EMAIL
                ask_field honeygain HONEYGAIN_PASSWORD
                ask_field honeygain HONEYGAIN_DEVICE
                ;;
            iproyal)
                ask_field iproyal IPRoyal_EMAIL
                ask_field iproyal IPRoyal_PASSWORD
                ask_field iproyal IPRoyal_DEVICE
                ask_field iproyal IPRoyal_DEVICE_ID
                ;;
            packetstream)
                ask_field packetstream CID
                ;;
            peer2profit)
                ask_field peer2profit P2P_EMAIL
                ;;
            traffmonetizer)
                ask_field traffmonetizer TRAFFMONETIZER_TOKEN
                ;;
            repocket)
                ask_field repocket RP_EMAIL
                ask_field repocket RP_API_KEY
                ;;
            earnfm)
                ask_field earnfm EARNFM_TOKEN
                ;;
            bitping)
                ask_field bitping BITPING_EMAIL
                ask_field bitping BITPING_PASSWORD
                ;;
            mysterium)
                echo "[i] Mysterium Node ist aktiviert. Keine manuelle Konfiguration nötig."
                ;;
        esac
    fi
done

# Final compose erzeugen
echo "🔁 Finaler docker-compose.yml wird generiert..."
python3 generate-compose.py

# Start
echo "🐋 Container werden gestartet..."
$DOCKER_COMPOSE_CMD up -d

echo ""
echo "✅ Installation abgeschlossen!"
echo "📋 Nützliche Befehle:"
echo "  - Status:        docker compose ps"
echo "  - Logs:          docker compose logs -f [appname]"
echo "  - Stop:          docker compose down"
echo "  - Update:        ./update.sh"
