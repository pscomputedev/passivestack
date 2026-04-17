#!/bin/bash
set -e

BACKUP_DIR="/var/backups/passivestack"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "💾 Erstelle Backup..."
tar -czf "$BACKUP_DIR/passivestack_$DATE.tar.gz" \
    /opt/passivestack/config \
    /opt/passivestack/docker-compose.yaml

echo "✅ Backup erstellt: $BACKUP_DIR/passivestack_$DATE.tar.gz"
