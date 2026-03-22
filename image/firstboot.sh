#!/usr/bin/env bash
# ============================================================
# PassiveStack — firstboot.sh
# Wird beim ersten Boot des fertigen Pi-Images automatisch
# ausgeführt. Richtet alles ein und startet install.sh.
# ============================================================

set -euo pipefail

LOG_FILE="/var/log/passivestack-firstboot.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== PassiveStack First Boot ==="
log "Warte auf Netzwerkverbindung..."

# Warten bis Netzwerk verfügbar
TIMEOUT=60
COUNT=0
until curl -s --max-time 3 https://1.1.1.1 &>/dev/null; do
  sleep 2
  COUNT=$((COUNT + 2))
  if [[ ${COUNT} -ge ${TIMEOUT} ]]; then
    log "Netzwerk-Timeout — fahre trotzdem fort"
    break
  fi
done
log "Netzwerk verfügbar"

# Bootstrap ausführen
log "Starte bootstrap.sh..."
bash /home/pi/passivestack/bootstrap.sh

# Firstboot-Service deaktivieren (läuft nur einmal)
systemctl disable passivestack-firstboot.service
log "Firstboot-Service deaktiviert"

# Reboot für cgroup memory
log "Reboot in 5 Sekunden..."
sleep 5
reboot
