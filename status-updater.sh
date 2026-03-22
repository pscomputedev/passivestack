#!/usr/bin/env bash
# ============================================================
# PassiveStack — status-updater.sh
# Liest Docker-Container-Status und schreibt status.json
# für das Web-Dashboard.
#
# Als Cron-Job einrichten (alle 60 Sekunden):
#   * * * * * /pfad/zu/passivestack/status-updater.sh
#   * * * * * sleep 30 && /pfad/zu/passivestack/status-updater.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="${SCRIPT_DIR}/dashboard/.config/status.json"
PROJECT="passivestack"

# Container-Status via docker compose ps abfragen
# Format: NAME STATUS
get_status() {
  docker compose \
    -f "${SCRIPT_DIR}/docker-compose.yaml" \
    --project-name "${PROJECT}" \
    ps --format "{{.Name}}\t{{.Status}}" 2>/dev/null || echo ""
}

# Status-String normalisieren
normalize_status() {
  local raw="$1"
  case "${raw,,}" in
    *"up"*|*"running"*) echo "running" ;;
    *"exit"*|*"exited"*) echo "stopped" ;;
    *"restarting"*) echo "restarting" ;;
    *"paused"*) echo "paused" ;;
    *) echo "unknown" ;;
  esac
}

# Uptime aus Status-String extrahieren (z.B. "Up 2 hours")
extract_uptime() {
  local raw="$1"
  # Extrahiere den "Up X hours/minutes/days" Teil
  if [[ "${raw}" =~ Up[[:space:]](.+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "—"
  fi
}

# JSON bauen
build_json() {
  local status_raw
  status_raw=$(get_status)

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "{"
  echo "  \"_updated\": \"${timestamp}\","

  local first=true
  while IFS=$'\t' read -r name raw_status; do
    [[ -z "${name}" ]] && continue

    # Container-Name zu App-Name (entfernt Device-Prefix)
    # z.B. "pi-bandwidth_earnapp" → "earnapp"
    local app_name
    app_name=$(echo "${name}" | sed 's/^[^_]*_//')

    local status
    status=$(normalize_status "${raw_status}")

    local uptime
    uptime=$(extract_uptime "${raw_status}")

    if [[ "${first}" == "true" ]]; then
      first=false
    else
      echo ","
    fi

    printf '  "%s": {\n    "status": "%s",\n    "uptime": "%s",\n    "container": "%s"\n  }' \
      "${app_name}" "${status}" "${uptime}" "${name}"

  done <<< "${status_raw}"

  echo ""
  echo "}"
}

# Ausgabe in temporäre Datei, dann atomisch verschieben
TMP_FILE="${STATUS_FILE}.tmp"
build_json > "${TMP_FILE}"

# JSON validieren bevor wir die echte Datei überschreiben
if python3 -c "import json,sys; json.load(open('${TMP_FILE}'))" 2>/dev/null; then
  mv "${TMP_FILE}" "${STATUS_FILE}"
else
  rm -f "${TMP_FILE}"
  echo "$(date): JSON-Validierung fehlgeschlagen — status.json nicht aktualisiert" >&2
  exit 1
fi
