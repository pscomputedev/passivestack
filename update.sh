#!/bin/bash
set -e

######################################
# PassiveStack - Update Script v1.1
######################################

echo "🔄 PassiveStack Updater"

# Plattform erkennen
PLATFORM=$(uname -m)
echo "🔍 Plattform: $PLATFORM"

# Git notwendig
if ! command -v git &> /dev/null; then
    echo "📦 Git wird installiert..."
    sudo apt update && sudo apt install -y git
fi

echo "🔁 Git Repo wird aktualisiert..."
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Keine Änderungen. Bereits aktuell."
else
    echo "📥 Neue Version wird geholt..."
    git pull origin main

    # Neue/fehlende Configs kopieren (ohne Überschreiben)
    if [ ! -f "config/user-config.json" ]; then
        echo "📝 Erstelle user-config.json aus Template"
        cp config/user-config.example.json config/user-config.json
    fi

    echo "⚙️ Docker Compose wird regeneriert..."
    python3 generate-compose.py

    echo "🐋 Container werden aktualisiert..."
    docker compose up -d

    echo "✅ Update erfolgreich!"
fi
