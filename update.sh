#!/bin/bash
set -e

cd /opt/passivestack

echo "🔄 Aktualisiere PassiveStack..."
docker-compose pull
docker-compose up -d --remove-orphans
docker system prune -af --volumes

echo "✅ Update abgeschlossen"
