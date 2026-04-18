#!/usr/bin/env python3

import json
import platform
import os
import sys
from pathlib import Path

# Pfad-Konfiguration
SCRIPT_DIR = Path(__file__).parent
CONFIG_DIR = SCRIPT_DIR / "config"
APPS_JSON = CONFIG_DIR / "apps.json"
USER_CONFIG_JSON = CONFIG_DIR / "user-config.json"
OUTPUT_FILE = SCRIPT_DIR / "docker-compose.yaml"

def detect_architecture():
    """Erkennt die System-Architektur"""
    machine = platform.machine().lower()
    if machine in ['aarch64', 'arm64']:
        return 'arm64'
    elif machine in ['armv7l', 'arm']:
        return 'arm32'
    elif machine in ['x86_64', 'amd64']:
        return 'amd64'
    else:
        return 'unknown'

def load_json_file(file_path):
    """Lädt und parsed eine JSON-Datei"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Fehler beim Laden von {file_path}: {e}")
        sys.exit(1)

def format_yaml_dict(d, indent=0):
    """Formatiert ein Dictionary als YAML-String ohne PyYAML"""
    lines = []
    for key, value in d.items():
        spaces = "  " * indent
        if isinstance(value, dict):
            lines.append(f"{spaces}{key}:")
            lines.append(format_yaml_dict(value, indent + 1))
        elif isinstance(value, list):
            lines.append(f"{spaces}{key}:")
            for item in value:
                if isinstance(item, dict):
                    lines.append(f"{spaces}  - " + format_yaml_dict(item, indent + 2).lstrip())
                else:
                    lines.append(f"{spaces}  - {json.dumps(item)}")
        else:
            lines.append(f"{spaces}{key}: {json.dumps(value)}")
    return "\n".join(lines)

def generate_compose_yaml(arch, apps, user_config):
    """Generiert die docker-compose.yaml basierend auf apps und user_config"""
    
    services = {}
    
    # Watchtower hinzufügen, falls aktiviert
    if user_config.get("watchtower", {}).get("enabled", False):
        services["watchtower"] = {
            "image": "containrrr/watchtower:latest",
            "volumes": [
                "/var/run/docker.sock:/var/run/docker.sock"
            ],
            "environment": {
                "WATCHTOWER_CLEANUP": "true",
                "WATCHTOWER_POLL_INTERVAL": "3600"
            },
            "command": "--interval 3600"
        }
    
    # Apps hinzufügen
    for app_name, app_config in apps.items():
        if not app_config.get("enabled", True):
            continue
            
        profile = app_config.get("profile", "default")
        image_base = app_config.get("image", f"{app_name}:latest")
        
        # Architektur-spezifische Image-Tags
        if arch in ["arm64", "arm32"] and profile == "minimal":
            image = image_base.replace(":latest", f":{arch}-minimal")
        elif arch in ["arm64", "arm32"]:
            image = image_base.replace(":latest", f":{arch}-latest")
        else:
            image = image_base
            
        service = {
            "image": image,
            "container_name": app_name,
            "restart": "unless-stopped"
        }
        
        # Volumes hinzufügen
        if "volumes" in app_config:
            service["volumes"] = app_config["volumes"]
            
        # Umgebungsvariablen hinzufügen
        if "environment" in app_config:
            service["environment"] = app_config["environment"]
            
        # Ports hinzufügen
        if "ports" in app_config:
            service["ports"] = app_config["ports"]
            
        # Netzwerke hinzufügen
        if "networks" in app_config:
            service["networks"] = app_config["networks"]
            
        # Devices hinzufügen (für GPU/NVIDIA)
        if app_config.get("gpu_support", False) and arch in ["amd64", "x86_64"]:
            service["deploy"] = {
                "resources": {
                    "reservations": {
                        "devices": [
                            {
                                "driver": "nvidia",
                                "count": "all",
                                "capabilities": ["gpu"]
                            }
                        ]
                    }
                }
            }
            
        services[app_name] = service
    
    # YAML Struktur erstellen
    compose_data = {
        "version": "3.8",
        "services": services
    }
    
    # YAML schreiben
    with open(OUTPUT_FILE, 'w') as f:
        f.write("# Automatisch generiert von generate-compose.py\n")
        f.write("# NICHT MANUELL BEARBEITEN\n\n")
        f.write(format_yaml_dict(compose_data))
    
    print(f"✅ docker-compose.yaml erfolgreich erstellt für Arch: {arch}")

def main():
    """Hauptfunktion"""
    # Architektur erkennen
    arch = detect_architecture()
    print(f"🖥️  Erkannte Architektur: {arch}")
    
    # Configs laden
    apps = load_json_file(APPS_JSON)
    user_config = load_json_file(USER_CONFIG_JSON)
    
    # YAML generieren
    generate_compose_yaml(arch, apps, user_config)

if __name__ == "__main__":
    main()
