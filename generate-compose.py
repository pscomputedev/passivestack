#!/usr/bin/env python3
"""
PassiveStack Docker Compose Generator

Liest:
  - config/apps.json (Basisdefinitionen)
  - config/user-config.json (Userdaten, overrides)
  - optional: platform-flag (arm64/amd64)

Erzeugt:
  - docker-compose.yml
"""

import json
import os
import sys
import platform as platform_module

# Globale Konstanten
APPS_JSON_PATH = "config/apps.json"
USER_CONFIG_PATH = "config/user-config.json"
OUTPUT_COMPOSE = "docker-compose.yml"

def load_json(path):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Fehler: '{path}' nicht gefunden.", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Fehler beim Parsen von '{path}': {e}", file=sys.stderr)
        sys.exit(1)

def write_compose(services):
    compose_data = {
        "services": services
    }

    with open(OUTPUT_COMPOSE, "w") as f:
        json.dump(compose_data, f, indent=2)
    print(f"Docker Compose erfolgreich geschrieben: {OUTPUT_COMPOSE}")

def main():
    platform_requested = sys.argv[1] if len(sys.argv) > 1 else None
    detected_platform = platform_module.machine().lower()

    if detected_platform in ['aarch64', 'armv8l']:
        platform = 'arm64'
    elif detected_platform in ['x86_64', 'amd64']:
        platform = 'amd64'
    else:
        platform = 'unknown'

    if platform_requested:
        platform = platform_requested

    apps_config = load_json(APPS_JSON_PATH)
    user_config = {}

    if os.path.exists(USER_CONFIG_PATH):
        user_config = load_json(USER_CONFIG_PATH)
    else:
        print("WARNUNG: Keine user-config.json gefunden. Nur default-apps werden generiert.")

    services = {}
    app_definitions = apps_config.get("apps", {})
    user_app_overrides = user_config.get("apps", {})
    global_settings = user_config.get("global", {})

    data_dir = global_settings.get("data_dir", "./data")

    for app_name, app_def in app_definitions.items():
        is_enabled = app_def.get("enabled_by_default", False)
        required_arch = app_def.get("architecture", "multiarch").lower()
        is_system = app_def.get("is_system", False)

        # Override durch user-config
        override_block = user_config.get("overrides", {}).get(app_name, {})
        if "enabled" in override_block:
            is_enabled = override_block["enabled"]

        if not is_enabled and not is_system:
            continue

        # Architekturfilterung
        if required_arch == "amd64" and platform == "arm64":
            print(f"⚠️ SKIP: {app_name} benötigt AMD64-Emulation")
            continue
        elif required_arch not in ["multiarch", platform]:
            print(f"⚠️ SKIP: {app_name} nicht kompatibel mit {platform}")
            continue

        service = {
            "image": app_def["image"],
            "restart": app_def.get("restart", "no"),
        }

        if app_def.get("network_mode"):
            service["network_mode"] = app_def["network_mode"]
        if app_def.get("privileged") is True:
            service["privileged"] = True
        if app_def.get("cap_add"):
            service["cap_add"] = app_def["cap_add"]
        if app_def.get("devices"):
            service["devices"] = app_def["devices"]

        command = app_def.get("command")
        if command:
            service["command"] = command

        volumes = []
        for vol in app_def.get("volumes", []):
            if vol.startswith("./data/") and not vol.startswith(data_dir):
                vol = vol.replace("./data/", f"{data_dir}/", 1)
            volumes.append(vol)
        if volumes:
            service["volumes"] = volumes

        env_vars = {}
        static_env = app_def.get("environment", {})
        if isinstance(static_env, dict):
            env_vars.update(static_env)

        user_env_data = user_app_overrides.get(app_name, {})
        for key in app_def.get("required_fields", []):
            value = user_env_data.get(key)
            if value:
                env_vars[key] = value
            else:
                print(f"❌ Fehlender Wert: {app_name}.{key}. App wird übersprungen.")
                break
        else:
            # Nur wenn alle Felder ok sind
            if env_vars or command:
                if env_vars:
                    service["environment"] = env_vars
                services[app_name] = service

    write_compose(services)
    print("✅ Fertig!")

if __name__ == "__main__":
    main()
