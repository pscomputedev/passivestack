#!/usr/bin/env python3
"""
PassiveStack — docker-compose.yaml Generator
Liest apps.json + user-config.json und generiert eine saubere docker-compose.yaml
ohne DNS-Socket-Leak.
"""

import json
import os
import sys
import yaml

APPS_CONFIG   = os.path.join(os.path.dirname(__file__), "config/apps.json")
USER_CONFIG   = os.path.join(os.path.dirname(__file__), "config/user-config.json")
OUTPUT_FILE   = os.path.join(os.path.dirname(__file__), "docker-compose.yaml")

def load_json(path):
    with open(path) as f:
        return json.load(f)

def build_service(app, user_apps, device_name, scope):
    """Baut einen Docker Compose Service-Block für eine App."""
    cfg = app["compose"].copy()
    name = app["name"]
    label = app["label"]

    service = {}
    service["container_name"] = f"{device_name}_{name}"
    service["hostname"]       = f"{device_name}_{name}"
    service["image"]          = cfg["image"]

    # Platform aus user-config oder app-default
    user_app = user_apps.get(name, {})
    platform = user_app.get("docker_platform", app["platforms"][0])
    service["platform"] = platform

    # Environment
    if "environment" in cfg:
        service["environment"] = cfg["environment"]

    # Command
    if "command" in cfg:
        service["command"] = cfg["command"]

    # Volumes
    if "volumes" in cfg:
        service["volumes"] = cfg["volumes"]

    # Ports
    if "ports" in cfg:
        service["ports"] = cfg["ports"]

    # cap_add
    if "cap_add" in cfg:
        service["cap_add"] = cfg["cap_add"]

    # Labels für Watchtower
    service["labels"] = [
        "com.centurylinklabs.watchtower.enable=true",
        f"com.centurylinklabs.watchtower.scope={scope}"
    ]

    service["restart"] = cfg.get("restart", "always")

    # Ressourcen
    service["cpus"]            = cfg.get("cpus", 1.0)
    service["mem_reservation"] = cfg.get("mem_reservation", "64m")
    service["mem_limit"]       = cfg.get("mem_limit", "256m")

    # Logging — immer explizit setzen (verhindert log-flood)
    service["logging"] = {
        "driver": "json-file",
        "options": {"max-size": "10m", "max-file": "3"}
    }

    return service


def build_watchtower(device_name, wt_cfg, scope, arch="arm64"):
    return {
        "container_name": f"{device_name}_watchtower",
        "hostname":       f"{device_name}_watchtower",
        "image":          wt_cfg.get("image", "nickfedor/watchtower:latest"),
        "platform":       f"linux/{arch}",
        "environment": [
            "WATCHTOWER_LABEL_ENABLE=true",
            f"WATCHTOWER_SCOPE={scope}",
            f"WATCHTOWER_POLL_INTERVAL={wt_cfg.get('poll_interval', 14400)}",
            "WATCHTOWER_ROLLING_RESTART=true",
            "WATCHTOWER_NO_STARTUP_MESSAGE=false",
            "WATCHTOWER_CLEANUP=true",
        ],
        "labels": [
            "com.centurylinklabs.watchtower.enable=true",
            f"com.centurylinklabs.watchtower.scope={scope}"
        ],
        "volumes": ["/var/run/docker.sock:/var/run/docker.sock"],
        "restart": "always",
        "cpus": 1.0,
        "mem_reservation": "64m",
        "mem_limit": "256m",
        "logging": {
            "driver": "json-file",
            "options": {"max-size": "10m", "max-file": "3"}
        }
    }


def build_compose(apps_cfg, user_cfg):
    device_name = user_cfg["device_info"]["device_name"]
    user_apps   = user_cfg.get("apps", {})
    sys_cfg     = apps_cfg["system"]
    scope       = sys_cfg["watchtower"]["scope"]
    net_cfg     = sys_cfg["network"]
    dns_cfg     = sys_cfg["dns"]

    services = {}

    # App-Services
    for app in apps_cfg["apps"]:
        name     = app["name"]
        user_app = user_apps.get(name, {})
        enabled  = user_app.get("enabled", app["enabled_default"])

        if not enabled:
            continue

        services[name] = build_service(app, user_apps, device_name, scope)

    # Watchtower
    if user_cfg.get("watchtower", {}).get("enabled", True):
        arch = user_cfg.get("device_info", {}).get("detected_docker_arch", "arm64")
        services["watchtower"] = build_watchtower(
            device_name, sys_cfg["watchtower"], scope, arch
        )

    # Netzwerk-Konfiguration
    # DNS explizit auf Container-Ebene setzen → verhindert UDP-Socket-Leak
    # (money4band-Bug: tun2socks erzeugt tausende UDP sockets)
    network_name = f"passivestack_{device_name}"
    compose = {
        "services": services,
        "networks": {
            "default": {
                "driver": net_cfg["driver"],
                "driver_opts": {
                    # DNS für alle Container direkt — kein interner DNS-Proxy
                    "com.docker.network.bridge.enable_icc": "true",
                },
                "ipam": {
                    "config": [{
                        "subnet": f"{net_cfg['subnet']}/{net_cfg['netmask']}"
                    }]
                }
            }
        }
    }

    # DNS in jeden Service eintragen (explizit, kein Docker-internen DNS-Proxy)
    for svc_name, svc in compose["services"].items():
        svc["dns"] = list(dns_cfg["servers"])
        svc["dns_opt"] = list(dns_cfg.get("options", ["ndots:1"]))

    return compose


def main():
    # Config laden
    if not os.path.exists(APPS_CONFIG):
        print(f"❌ apps.json nicht gefunden: {APPS_CONFIG}")
        sys.exit(1)
    if not os.path.exists(USER_CONFIG):
        print(f"❌ user-config.json nicht gefunden: {USER_CONFIG}")
        print("   Bitte zuerst install.sh ausführen.")
        sys.exit(1)

    apps_cfg = load_json(APPS_CONFIG)
    user_cfg = load_json(USER_CONFIG)

    compose = build_compose(apps_cfg, user_cfg)

    # YAML schreiben
    with open(OUTPUT_FILE, "w") as f:
        f.write("# PassiveStack — docker-compose.yaml\n")
        f.write("# Generiert von generate-compose.py — nicht manuell bearbeiten\n")
        f.write("# Änderungen in config/user-config.json vornehmen\n\n")
        yaml.dump(compose, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    # Statistik
    n_services = len(compose["services"])
    print(f"✅ docker-compose.yaml generiert")
    print(f"   Services: {n_services}")
    for svc in compose["services"]:
        print(f"   → {svc}")
    print(f"   Subnet: {apps_cfg['system']['network']['subnet']}/{apps_cfg['system']['network']['netmask']}")
    print(f"   DNS: {apps_cfg['system']['dns']['servers']}")


if __name__ == "__main__":
    main()
