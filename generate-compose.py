#!/usr/bin/env python3
import json
import os
from pathlib import Path

# Pfade
CONFIG_DIR = Path("config")
APPS_FILE = CONFIG_DIR / "apps.json"
USER_CONFIG_FILE = CONFIG_DIR / "user-config.json"
OUTPUT_FILE = Path("docker-compose.yaml")

def load_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def main():
    if not APPS_FILE.exists():
        print(f"Fehler: {APPS_FILE} nicht gefunden!")
        return 1
    if not USER_CONFIG_FILE.exists():
        print(f"Fehler: {USER_CONFIG_FILE} nicht gefunden!")
        return 1

    apps = load_json(APPS_FILE)
    user_config = load_json(USER_CONFIG_FILE)

    # Basis-Konfiguration
    compose = {
        "version": "3.8",
        "services": {},
        "networks": {
            "proxy": {
                "name": "proxy",
                "driver": "bridge",
                "external": False
            }
        },
        "volumes": {}
    }

    # Environment-Variablen aus user-config
    env = {
        "TIMEZONE": user_config.get("timezone", "Europe/Berlin"),
        "DOMAIN": user_config.get("domain", "yourdomain.com"),
        "EMAIL": user_config.get("email", "your@email.com")
    }

    # Grass Credentials
    if user_config.get("grass"):
        env["GRASS_EMAIL"] = user_config["grass"].get("email", "")
        env["GRASS_PASSWORD"] = user_config["grass"].get("password", "")

    # Honeygain Credentials
    if user_config.get("honeygain"):
        env["HONEYGAIN_EMAIL"] = user_config["honeygain"].get("email", "")
        env["HONEYGAIN_PASSWORD"] = user_config["honeygain"].get("password", "")

    # Weitere Credentials
    if user_config.get("earnapp"):
        env["EARNAPP_TOKEN"] = user_config["earnapp"].get("token", "")
    if user_config.get("iproyal"):
        env["IPROYAL_EMAIL"] = user_config["iproyal"].get("email", "")
        env["IPROYAL_PASSWORD"] = user_config["iproyal"].get("password", "")
    if user_config.get("repocket"):
        env["REPOCKET_EMAIL"] = user_config["repocket"].get("email", "")
        env["REPOCKET_API_KEY"] = user_config["repocket"].get("api_key", "")
    if user_config.get("traffmonetizer"):
        env["TRAFFMONETIZER_TOKEN"] = user_config["traffmonetizer"].get("token", "")
    if user_config.get("packetstream"):
        env["PACKETSTREAM_CID"] = user_config["packetstream"].get("cid", "")

    # Services generieren
    for app_name, app_config in apps.items():
        if not app_config.get("enabled", False):
            continue

        service = {
            "image": app_config["image"],
            "container_name": app_config.get("container_name", app_name),
            "restart": app_config.get("restart", "unless-stopped")
        }

        if "networks" in app_config:
            service["networks"] = app_config["networks"]
        if "ports" in app_config:
            service["ports"] = app_config["ports"]
        if "volumes" in app_config:
            service["volumes"] = app_config["volumes"]
        if "environment" in app_config:
            service_env = app_config["environment"].copy()
            # Platzhalter durch echte Werte ersetzen
            for key, value in service_env.items():
                if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
                    var_name = value.strip("${}").split(":")[0]
                    service_env[key] = env.get(var_name, value)
            service["environment"] = service_env
        if "labels" in app_config:
            service["labels"] = app_config["labels"]
        if "command" in app_config:
            service["command"] = app_config["command"]
        if "hostname" in app_config:
            service["hostname"] = app_config["hostname"]

        compose["services"][app_name] = service

    # Datei schreiben
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(compose, f, indent=2)
        f.write("\n")  # Zusätzlichen Zeilenumbruch für bessere Lesbarkeit

    print(f"✅ docker-compose.yaml erfolgreich generiert mit {len(compose['services'])} aktiven Services.")
    print(f"   Generierte Services: {', '.join(compose['services'].keys())}")
    return 0

if __name__ == "__main__":
    exit(main())
