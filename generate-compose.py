#!/usr/bin/env python3
import json
import platform
import os
import sys
from pathlib import Path

# ==================== KONFIGURATION ====================
SCRIPT_DIR = Path(__file__).parent
CONFIG_DIR = SCRIPT_DIR / "config"
APPS_JSON = CONFIG_DIR / "apps.json"
USER_CONFIG_JSON = CONFIG_DIR / "user-config.json"
OUTPUT_FILE = SCRIPT_DIR / "docker-compose.yaml"

def detect_architecture():
    machine = platform.machine().lower()
    if machine in ['aarch64', 'arm64']:
        return 'arm64'
    elif machine in ['armv7l', 'arm']:
        return 'arm32'
    return 'amd64'

def load_json_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Fehler beim Laden von {file_path}: {e}")
        sys.exit(1)

def write_compose(services):
    """Schreibt die finale docker-compose.yaml"""
    compose = {
        "version": "3.9",
        "name": "passivestack",
        "services": services
    }
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("# =============================================\n")
        f.write("# AUTOMATISCH GENERIERT VON generate-compose.py\n")
        f.write("# NICHT MANUELL BEARBEITEN - ÄNDERUNGEN GEHEN VERLOREN!\n")
        f.write("# =============================================\n\n")
        f.write(json.dumps(compose, indent=2))
    
    print("✅ docker-compose.yaml wurde erfolgreich generiert!")

def main():
    arch = detect_architecture()
    print(f"🖥️  Erkannte Architektur: {arch}")
    
    apps = load_json_file(APPS_JSON)
    user_config = load_json_file(USER_CONFIG_JSON)
    
    services = {}
    
    # System-Dienste (immer aktiv)
    system_services = ["traefik", "homepage", "portainer", "watchtower", "fail2ban"]
    for svc in system_services:
        if svc in apps and apps[svc].get("enabled", True):
            services[svc] = apps[svc].copy()
            # Platzhalter durch echte Werte aus user_config ersetzen
            if "environment" in services[svc]:
                for key, value in services[svc]["environment"].items():
                    if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
                        env_key = value.strip("${}").split(":")[0]
                        services[svc]["environment"][key] = user_config.get("security", {}).get(env_key.lower(), value)
    
    # DePIN / Passive Earning Dienste (nur wenn in user-config aktiviert)
    if "services" in user_config:
        for app_name, config in user_config["services"].items():
            if isinstance(config, dict) and config.get("enabled", False):
                if app_name in apps:
                    app_template = apps[app_name].copy()
                    # Credentials aus user-config einfügen
                    if "environment" in app_template:
                        for k, v in config.items():
                            if k.upper() in app_template["environment"] or k in app_template["environment"]:
                                app_template["environment"][k.upper()] = v
                    services[app_name] = app_template
                else:
                    print(f"⚠️  App {app_name} ist in user-config aktiviert, aber nicht in apps.json definiert.")
    
    write_compose(services)
    print("✅ Fertig!")

if __name__ == "__main__":
    main()
