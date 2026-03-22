#!/usr/bin/env bash
# ============================================================
# PassiveStack — install.sh
# Interaktiver Installer für den Bandwidth-Sharing Stack
# https://passivecompute.de
# ============================================================

set -euo pipefail

# ── Farben & Symbole ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

OK="✅"
WARN="⚠️ "
ERR="❌"
INFO="ℹ️ "
ARROW="→"

# ── Pfade ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
APPS_JSON="${CONFIG_DIR}/apps.json"
USER_CONFIG="${CONFIG_DIR}/user-config.json"
ENV_FILE="${SCRIPT_DIR}/.env"
DATA_DIR="${SCRIPT_DIR}/.data"
LOG_FILE="${SCRIPT_DIR}/install.log"

# ── Logging ──────────────────────────────────────────────────
exec > >(tee -a "${LOG_FILE}") 2>&1

log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()   { echo -e "${GREEN}${OK}${NC} $*"; }
warn() { echo -e "${YELLOW}${WARN}${NC} $*"; }
err()  { echo -e "${RED}${ERR}${NC} $*"; }
info() { echo -e "${BLUE}${INFO}${NC} $*"; }
ask()  { echo -e "${BOLD}${ARROW}${NC} $*"; }

# ── Banner ───────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${YELLOW}${BOLD}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║         ☀️  PassiveStack Installer         ║"
  echo "  ║     Solar-powered passive income stack    ║"
  echo "  ║          passivecompute.de  v1.0          ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Hilfsfunktionen ──────────────────────────────────────────
confirm() {
  local prompt="${1:-Fortfahren?}"
  local default="${2:-y}"
  local answer
  if [[ "${default}" == "y" ]]; then
    read -rp "$(echo -e "${BOLD}${ARROW}${NC} ${prompt} [Y/n]: ")" answer </dev/tty
    answer="${answer:-y}"
  else
    read -rp "$(echo -e "${BOLD}${ARROW}${NC} ${prompt} [y/N]: ")" answer </dev/tty
    answer="${answer:-n}"
  fi
  [[ "${answer,,}" == "y" ]]
}

prompt() {
  local varname="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local secret="${4:-false}"

  if [[ -n "${default}" ]]; then
    prompt_text="${prompt_text} [${default}]"
  fi

  if [[ "${secret}" == "true" ]]; then
    read -rsp "$(echo -e "${BOLD}${ARROW}${NC} ${prompt_text}: ")" value
    echo ""
  else
    read -rp "$(echo -e "${BOLD}${ARROW}${NC} ${prompt_text}: ")" value
  fi

  value="${value:-${default}}"
  printf -v "${varname}" '%s' "${value}"
}

divider() {
  echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

# ── Voraussetzungen prüfen ───────────────────────────────────
check_requirements() {
  divider
  log "Prüfe Voraussetzungen..."
  local missing=()

  # Docker
  if command -v docker &>/dev/null; then
    local docker_ver
    docker_ver=$(docker --version | grep -oP '\d+\.\d+')
    ok "Docker installiert: ${docker_ver}"
  else
    err "Docker nicht gefunden"
    missing+=("docker")
  fi

  # Docker Compose
  if docker compose version &>/dev/null 2>&1; then
    ok "Docker Compose Plugin verfügbar"
  elif command -v docker-compose &>/dev/null; then
    warn "Altes docker-compose gefunden — bitte auf Docker Compose Plugin upgraden"
  else
    err "Docker Compose nicht gefunden"
    missing+=("docker-compose")
  fi

  # Python3 (für generate-compose.py)
  if command -v python3 &>/dev/null; then
    ok "Python3 verfügbar"
  else
    err "Python3 nicht gefunden"
    missing+=("python3")
  fi

  # PyYAML
  if python3 -c "import yaml" &>/dev/null 2>&1; then
    ok "PyYAML verfügbar"
  else
    warn "PyYAML fehlt — wird installiert..."
    pip3 install pyyaml --break-system-packages -q 2>/dev/null || \
    pip3 install pyyaml -q 2>/dev/null || \
    { err "PyYAML konnte nicht installiert werden"; missing+=("pyyaml"); }
  fi

  # jq (optional, für JSON-Verarbeitung)
  if command -v jq &>/dev/null; then
    ok "jq verfügbar"
  else
    warn "jq nicht gefunden (optional) — sudo apt install jq"
  fi

  # Architektur erkennen
  ARCH=$(uname -m)
  case "${ARCH}" in
    x86_64|amd64) DOCKER_ARCH="amd64" ;;
    aarch64|arm64) DOCKER_ARCH="arm64" ;;
    armv7l) DOCKER_ARCH="arm/v7" ;;
    *) DOCKER_ARCH="amd64"; warn "Unbekannte Architektur: ${ARCH} — setze amd64" ;;
  esac
  ok "Architektur: ${ARCH} → Docker: linux/${DOCKER_ARCH}"

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Fehlende Voraussetzungen: ${missing[*]}"
    echo ""
    info "Docker installieren: curl -fsSL https://get.docker.com | bash"
    exit 1
  fi
}

# ── Gerätename ───────────────────────────────────────────────
setup_device() {
  divider
  log "Gerätekonfiguration..."
  echo ""

  local hostname_default
  hostname_default=$(hostname 2>/dev/null || echo "my-device")
  # Leerzeichen und Sonderzeichen entfernen
  hostname_default=$(echo "${hostname_default}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

  prompt DEVICE_NAME "Gerätename (wird als Container-Prefix verwendet)" "${hostname_default}"
  # Validierung: nur alphanumerisch + Bindestriche
  DEVICE_NAME=$(echo "${DEVICE_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
  ok "Gerätename: ${DEVICE_NAME}"
}

# ── App-Konfiguration ────────────────────────────────────────
setup_apps() {
  divider
  log "App-Konfiguration..."
  echo ""
  info "Konfiguriere nur Apps für die du bereits einen Account hast."
  info "Nicht konfigurierte Apps werden deaktiviert."
  echo ""

  # Initialisiere Apps-Array für user-config
  declare -gA APP_ENABLED
  declare -gA APP_CONFIG

  # Apps aus apps.json lesen
  local apps_names
  apps_names=$(python3 -c "
import json
with open('${APPS_JSON}') as f:
    d = json.load(f)
for app in d['apps']:
    print(app['name'] + '|' + app['label'] + '|' + app['auth_type'] + '|' + str(app['enabled_default']).lower())
")

  while IFS='|' read -r name label auth_type enabled_default; do
    echo ""
    echo -e "${BOLD}── ${label} ──${NC}"

    # Referral-Link anzeigen
    local ref_url
    ref_url=$(python3 -c "
import json
with open('${APPS_JSON}') as f:
    d = json.load(f)
for app in d['apps']:
    if app['name'] == '${name}':
        print(app.get('referral') or 'kein Referral')
        break
")
    info "Registrieren: ${ref_url}"

    if confirm "Hast du einen Account bei ${label}?" "${enabled_default}"; then
      APP_ENABLED["${name}"]="true"
      configure_app "${name}" "${label}" "${auth_type}"
    else
      APP_ENABLED["${name}"]="false"
      ok "${label} übersprungen"
    fi
  done <<< "${apps_names}"
}

# ── Einzelne App konfigurieren ───────────────────────────────
configure_app() {
  local name="$1"
  local label="$2"
  local auth_type="$3"
  local cfg=""

  case "${auth_type}" in
    uuid)
      # UUID automatisch generieren
      local uuid
      uuid=$(python3 -c "import uuid; print(uuid.uuid4().hex)")
      APP_CONFIG["${name}_uuid"]="${uuid}"
      ok "${label}: UUID generiert: sdk-node-${uuid}"
      info "Claim-Link: https://earnapp.com/r/sdk-node-${uuid}"
      ;;

    email_password)
      prompt "APP_EMAIL" "${label} E-Mail"
      prompt "APP_PASS"  "${label} Passwort" "" "true"
      APP_CONFIG["${name}_email"]="${APP_EMAIL}"
      APP_CONFIG["${name}_password"]="${APP_PASS}"
      ok "${label}: E-Mail + Passwort gespeichert"
      ;;

    token)
      prompt "APP_TOKEN" "${label} Token/API-Key"
      APP_CONFIG["${name}_token"]="${APP_TOKEN}"
      ok "${label}: Token gespeichert"
      ;;

    apikey)
      prompt "APP_KEY" "${label} API-Key"
      APP_CONFIG["${name}_apikey"]="${APP_KEY}"
      ok "${label}: API-Key gespeichert"
      ;;

    cid)
      prompt "APP_CID" "${label} CID (z.B. psr=XXXX)"
      APP_CONFIG["${name}_cid"]="${APP_CID}"
      ok "${label}: CID gespeichert"
      ;;

    email_apikey)
      prompt "APP_EMAIL"  "${label} E-Mail"
      prompt "APP_APIKEY" "${label} API-Key"
      APP_CONFIG["${name}_email"]="${APP_EMAIL}"
      APP_CONFIG["${name}_apikey"]="${APP_APIKEY}"
      ok "${label}: E-Mail + API-Key gespeichert"
      ;;

    manual)
      warn "${label}: Manuelle Einrichtung nach dem Start erforderlich"
      info "Dashboard wird nach dem Start unter http://DEVICE_IP:4449 erreichbar sein"
      ;;

    *)
      warn "Unbekannter Auth-Typ: ${auth_type}"
      ;;
  esac
}

# ── user-config.json schreiben ───────────────────────────────
write_user_config() {
  divider
  log "Schreibe user-config.json..."

  python3 - <<PYEOF
import json, os

apps_json = json.load(open('${APPS_JSON}'))
enabled   = {}
configs   = {}

# Shell-Arrays einlesen
enabled_raw = """$(for k in "${!APP_ENABLED[@]}"; do echo "${k}=${APP_ENABLED[$k]}"; done)"""
config_raw  = """$(for k in "${!APP_CONFIG[@]}"; do echo "${k}=${APP_CONFIG[$k]}"; done)"""

for line in enabled_raw.strip().split('\n'):
    if '=' in line:
        k, v = line.split('=', 1)
        enabled[k.strip()] = v.strip() == 'true'

for line in config_raw.strip().split('\n'):
    if '=' in line:
        k, v = line.split('=', 1)
        configs[k.strip()] = v.strip()

user_apps = {}
for app in apps_json['apps']:
    name = app['name']
    auth = app['auth_type']
    is_enabled = enabled.get(name, app['enabled_default'])

    entry = {
        'enabled': is_enabled,
        'docker_platform': 'linux/${DOCKER_ARCH}'
    }

    if auth == 'uuid':
        entry['uuid'] = 'sdk-node-' + configs.get(f'{name}_uuid', '')
    elif auth == 'email_password':
        entry['email']    = configs.get(f'{name}_email', '')
        entry['password'] = configs.get(f'{name}_password', '')
    elif auth == 'token':
        entry['token'] = configs.get(f'{name}_token', '')
    elif auth == 'apikey':
        entry['apikey'] = configs.get(f'{name}_apikey', '')
    elif auth == 'cid':
        entry['cid'] = configs.get(f'{name}_cid', '')
    elif auth == 'email_apikey':
        entry['email']  = configs.get(f'{name}_email', '')
        entry['apikey'] = configs.get(f'{name}_apikey', '')

    user_apps[name] = entry

user_cfg = {
    'device_info': {
        'device_name':          '${DEVICE_NAME}',
        'os_type':              'Linux',
        'detected_architecture':'${ARCH}',
        'detected_docker_arch': '${DOCKER_ARCH}'
    },
    'apps': user_apps,
    'watchtower': {'enabled': True},
    'm4b_dashboard': {'enabled': True, 'ports': [8081]}
}

os.makedirs('${CONFIG_DIR}', exist_ok=True)
with open('${USER_CONFIG}', 'w') as f:
    json.dump(user_cfg, f, indent=2)

print(f'user-config.json geschrieben ({len(user_apps)} Apps)')
PYEOF

  ok "user-config.json erstellt"
}

# ── .env Datei schreiben ─────────────────────────────────────
write_env_file() {
  divider
  log "Schreibe .env Datei..."

  python3 - <<PYEOF
import json

user_cfg  = json.load(open('${USER_CONFIG}'))
apps_json = json.load(open('${APPS_JSON}'))

lines = [
    '# PassiveStack .env',
    '# Generiert von install.sh — nicht manuell bearbeiten',
    '# Aendern: install.sh erneut ausfuehren',
    '',
    f"DEVICE_NAME={user_cfg['device_info']['device_name']}",
    '',
]

# Netzwerk
net = apps_json['system']['network']
lines += [
    f"NETWORK_DRIVER={net['driver']}",
    f"NETWORK_SUBNET={net['subnet']}",
    f"NETWORK_NETMASK={net['netmask']}",
    '',
]

# Watchtower
wt = apps_json['system']['watchtower']
lines += [
    f"M4B_WATCHTOWER_SCOPE={wt['scope']}",
    f"M4B_WATCHTOWER_LABELS=true",
    f"WATCHTOWER_NOTIFICATION_URL=",
    '',
]

# Dashboard Port
lines += [
    'M4B_DASHBOARD_PORT=8081',
    '',
]

# Resource Limits
res = apps_json['system']['resource_limits']
lines += [
    f"APP_CPU_LIMIT_LITTLE={res['little']['cpus']}",
    f"APP_CPU_LIMIT_MEDIUM={res['medium']['cpus']}",
    f"APP_CPU_LIMIT_BIG={res['big']['cpus']}",
    f"APP_MEM_RESERV_LITTLE={res['little']['mem_reservation']}",
    f"APP_MEM_RESERV_MEDIUM={res['medium']['mem_reservation']}",
    f"APP_MEM_RESERV_BIG={res['big']['mem_reservation']}",
    f"APP_MEM_LIMIT_LITTLE={res['little']['mem_limit']}",
    f"APP_MEM_LIMIT_MEDIUM={res['medium']['mem_limit']}",
    f"APP_MEM_LIMIT_BIG={res['big']['mem_limit']}",
    '',
]

# App-Credentials
for app in apps_json['apps']:
    name = app['name']
    auth = app['auth_type']
    u    = user_cfg['apps'].get(name, {})

    if not u.get('enabled', False):
        continue

    lines.append(f'# {app["label"]}')

    if auth == 'uuid':
        lines.append(f"EARNAPP_UUID={u.get('uuid','')}")
    elif auth == 'email_password':
        prefix = name.upper()
        lines.append(f"{prefix}_EMAIL={u.get('email','')}")
        lines.append(f"{prefix}_PASSWORD={u.get('password','')}")
    elif auth == 'token':
        prefix = name.upper()
        lines.append(f"{prefix}_TOKEN={u.get('token','')}")
    elif auth == 'apikey':
        prefix = name.upper()
        lines.append(f"{prefix}_APIKEY={u.get('apikey','')}")
    elif auth == 'cid':
        lines.append(f"PACKETSTREAM_CID={u.get('cid','')}")
    elif auth == 'email_apikey':
        prefix = name.upper()
        lines.append(f"{prefix}_EMAIL={u.get('email','')}")
        lines.append(f"{prefix}_APIKEY={u.get('apikey','')}")

    lines.append('')

# Mysterium Port
lines.append('MYSTNODE_PORT=4449')

with open('${ENV_FILE}', 'w') as f:
    f.write('\n'.join(lines) + '\n')

print(f'.env geschrieben ({len(lines)} Zeilen)')
PYEOF

  # .env absichern — nur Owner darf lesen (Credentials drin!)
  chmod 600 "${ENV_FILE}"
  ok ".env erstellt (chmod 600)"
}

# ── Docker Compose generieren ────────────────────────────────
generate_compose() {
  divider
  log "Generiere docker-compose.yaml..."
  python3 "${SCRIPT_DIR}/generate-compose.py"
  ok "docker-compose.yaml generiert"
}

# ── Datenverzeichnisse anlegen ───────────────────────────────
create_data_dirs() {
  divider
  log "Lege Datenverzeichnisse an..."
  local dirs=(
    "${DATA_DIR}/.earnapp"
    "${DATA_DIR}/.bitpingd"
    "${DATA_DIR}/.mysterium-node"
    "${DATA_DIR}/.gradient"
  )
  for dir in "${dirs[@]}"; do
    mkdir -p "${dir}"
    ok "Erstellt: ${dir}"
  done
}

# ── Stack starten ────────────────────────────────────────────
start_stack() {
  divider
  log "Starte PassiveStack..."
  echo ""

  if ! confirm "Stack jetzt starten?"; then
    info "Stack nicht gestartet. Manuell starten mit:"
    echo "  cd ${SCRIPT_DIR} && docker compose up -d"
    return
  fi

  docker compose -f "${SCRIPT_DIR}/docker-compose.yaml" \
    --env-file "${ENV_FILE}" \
    --project-name "passivestack" \
    up -d

  echo ""
  ok "Stack gestartet!"
  echo ""
  log "Laufende Container:"
  docker compose -f "${SCRIPT_DIR}/docker-compose.yaml" \
    --project-name "passivestack" \
    ps --format "table {{.Name}}\t{{.Status}}"
}

# ── Zusammenfassung ──────────────────────────────────────────
print_summary() {
  divider
  echo ""
  echo -e "${GREEN}${BOLD}  PassiveStack erfolgreich eingerichtet!${NC}"
  echo ""
  echo -e "  ${CYAN}Dashboard:${NC}  http://$(hostname -I | awk '{print $1}'):8081"
  echo -e "  ${CYAN}Logs:${NC}       docker compose -p passivestack logs -f"
  echo -e "  ${CYAN}Stoppen:${NC}    docker compose -p passivestack down"
  echo -e "  ${CYAN}Neustart:${NC}   docker compose -p passivestack restart"
  echo ""

  # EarnApp Claim-Link anzeigen falls konfiguriert
  if [[ "${APP_ENABLED[earnapp]:-false}" == "true" ]]; then
    local uuid="${APP_CONFIG[earnapp_uuid]:-}"
    if [[ -n "${uuid}" ]]; then
      echo -e "  ${YELLOW}EarnApp Claim:${NC} https://earnapp.com/r/sdk-node-${uuid}"
      echo ""
    fi
  fi

  echo -e "  ${BLUE}${INFO} Mehr Infos: https://passivecompute.de${NC}"
  echo ""
  divider
}

# ── Hauptprogramm ────────────────────────────────────────────
main() {
  print_banner
  log "Installer gestartet: $(date)"
  log "Log-Datei: ${LOG_FILE}"
  echo ""

  # Voraussetzungen
  check_requirements

  # Gerät konfigurieren
  setup_device

  # Apps konfigurieren
  setup_apps

  # Dateien schreiben
  write_user_config
  write_env_file
  generate_compose
  create_data_dirs

  # Starten
  start_stack

  # Zusammenfassung
  print_summary
}

# Nur ausführen wenn direkt aufgerufen, nicht wenn gesourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
