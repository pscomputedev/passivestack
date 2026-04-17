#!/bin/bash
# PassiveStack Installation Script - Korrigierte Version
set -e  # Beende bei Fehlern

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log-Funktionen
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Prüfe Root-Rechte
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Dieses Script benötigt sudo Rechte!"
        echo "Bitte ausführen mit: sudo ./install.sh"
        exit 1
    fi
}

# Prüfe Betriebssystem
check_os() {
    if ! command -v lsb_release &> /dev/null; then
        apt-get update && apt-get install -y lsb-release
    fi
    
    OS=$(lsb_release -si)
    ARCH=$(uname -m)
    
    case "$ARCH" in
        "x86_64") ARCH="amd64" ;;
        "aarch64"|"armv8l"|"armv7l") ARCH="arm64" ;;
        *) ARCH="unknown" ;;
    esac
    
    log_info "Betriebssystem: $OS"
    log_info "Architektur: $ARCH"
    
    if [ "$ARCH" = "unknown" ]; then
        log_error "Nicht unterstützte Architektur: $(uname -m)"
        exit 1
    fi
}

# Prüfe Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_warn "Docker nicht gefunden. Installiere..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        usermod -aG docker $USER
    else
        log_info "Docker ist installiert"
    fi
    
    # Starte Docker wenn nicht läuft
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker Dienst wird gestartet..."
        systemctl start docker
        systemctl enable docker
    fi
}

# Prüfe Docker Compose
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose nicht gefunden. Installiere..."
        
        # Für ARM64 (Raspberry Pi) spezielle Installation
        if [ "$ARCH" = "arm64" ]; then
            curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-aarch64" \
                -o /usr/local/bin/docker-compose
        else
            curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-$(uname -m)" \
                -o /usr/local/bin/docker-compose
        fi
        
        chmod +x /usr/local/bin/docker-compose
    else
        log_info "Docker Compose ist installiert"
    fi
}

# Backup bestehender Installation
backup_existing() {
    local backup_dir="/var/backups/passivestack_$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "/opt/passivestack" ]; then
        log_info "Erstelle Backup in $backup_dir"
        mkdir -p "$backup_dir"
        
        # Backup Compose-Datei
        if [ -f "/opt/passivestack/docker-compose.yaml" ]; then
            cp "/opt/passivestack/docker-compose.yaml" "$backup_dir/"
        fi
        
        # Backup Config
        if [ -d "/opt/passivestack/config" ]; then
            cp -r "/opt/passivestack/config" "$backup_dir/"
        fi
        
        log_info "Backup abgeschlossen"
    fi
}

# Kopiere Dateien
copy_files() {
    local install_dir="/opt/passivestack"
    
    log_info "Kopiere Dateien nach $install_dir"
    
    # Erstelle Verzeichnisstruktur
    mkdir -p "$install_dir"
    mkdir -p "$install_dir/config"
    mkdir -p "$install_dir/logs"
    mkdir -p "$install_dir/data"
    
    # Kopiere alle Dateien
    cp -r ./* "$install_dir/"
    
    # Setze korrekte Berechtigungen
    chmod +x "$install_dir/install.sh"
    chmod +x "$install_dir/generate-compose.py"
    chmod +x "$install_dir/update.sh"
    
    log_info "Dateien kopiert"
}

# Erstelle user-config.json Template
create_user_config() {
    local config_file="/opt/passivestack/config/user-config.json"
    
    if [ ! -f "$config_file" ]; then
        log_info "Erstelle user-config.json Template"
        
        cat > "$config_file" << EOF
{
  "device_name": "passivestack",
  "apps": {
    "earnapp": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com",
        "REFCODE": ""
      }
    },
    "honeygain": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com",
        "PASSWORD": "your-password"
      }
    },
    "iproyal": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com",
        "PASSWORD": "your-password"
      }
    },
    "packetstream": {
      "enabled": false,
      "credentials": {
        "CID": "your-client-id"
      }
    },
    "peer2profit": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com"
      }
    },
    "traffmonetizer": {
      "enabled": false,
      "credentials": {
        "TOKEN": "your-token"
      }
    },
    "repocket": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com",
        "API": "your-api-key"
      }
    },
    "earnfish": {
      "enabled": false,
      "credentials": {
        "TOKEN": "your-token"
      }
    },
    "bitping": {
      "enabled": false,
      "credentials": {
        "EMAIL": "your-email@example.com",
        "PASSWORD": "your-password",
        "MFA_CODE": ""
      }
    },
    "mysterium": {
      "enabled": false,
      "credentials": {
        "IDENTITY_PASSWORD": "your-password"
      }
    }
  }
}
EOF
        
        log_warn "⚠️  Bitte bearbeiten: $config_file"
        log_warn "   Setze 'enabled': true für gewünschte Apps"
        log_warn "   Trage deine Credentials ein"
    else
        log_info "user-config.json existiert bereits"
    fi
}

# Erstelle docker-compose.yaml
generate_compose() {
    log_info "Generiere docker-compose.yaml"
    
    cd /opt/passivestack
    
    if [ -f "generate-compose.py" ]; then
        python3 generate-compose.py
        if [ $? -eq 0 ]; then
            log_info "docker-compose.yaml erfolgreich generiert"
        else
            log_error "Fehler bei generate-compose.py"
            exit 1
        fi
    else
        log_error "generate-compose.py nicht gefunden"
        exit 1
    fi
}

# Starte Container
start_containers() {
    log_info "Starte Docker Container..."
    
    cd /opt/passivestack
    
    if [ -f "docker-compose.yaml" ]; then
        docker-compose up -d
        
        # Warte auf Container
        sleep 10
        
        # Zeige Status
        docker-compose ps
        
        log_info "✅ PassiveStack wurde erfolgreich installiert!"
        echo ""
        echo "📋 NÄCHSTE SCHRITTE:"
        echo "1. Bearbeite die Konfiguration: /opt/passivestack/config/user-config.json"
        echo "2. Aktualisiere die Container: cd /opt/passivestack && ./update.sh"
        echo "3. Logs anzeigen: docker-compose logs -f"
        echo ""
        echo "🔧 Verwaltung:"
        echo "   cd /opt/passivestack"
        echo "   docker-compose stop      # Stoppt alle Container"
        echo "   docker-compose start     # Startet alle Container"
        echo "   docker-compose restart   # Startet alle Container neu"
        echo "   ./update.sh              # Aktualisiert alle Container"
        
    else
        log_error "docker-compose.yaml nicht gefunden"
        exit 1
    fi
}

# Hauptfunktion
main() {
    echo "=========================================="
    echo "🔄 PassiveStack Installation"
    echo "=========================================="
    
    # Prüfungen
    check_root
    check_os
    check_docker
    check_docker_compose
    
    # Installation
    backup_existing
    copy_files
    create_user_config
    generate_compose
    start_containers
    
    echo "=========================================="
    echo "✅ Installation abgeschlossen!"
    echo "=========================================="
}

# Ausführung
main "$@"
