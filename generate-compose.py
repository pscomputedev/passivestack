#!/usr/bin/env python3
import json
import sys
from pathlib import Path

def load_config():
    config_file = Path("config/user-config.json")
    if not config_file.exists():
        print("Fehler: config/user-config.json nicht gefunden!")
        print("Bitte erstelle diese Datei zuerst mit deinen Einstellungen.")
        sys.exit(1)
    
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"Fehler in user-config.json: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Fehler beim Lesen der Config: {e}")
        sys.exit(1)

def main():
    config = load_config()
    
    domain = config.get("domain", "example.com")
    email = config.get("email", "your@email.com")
    timezone = config.get("timezone", "Europe/Berlin")
    
    services = config.get("services", {})
    
    compose = {
        "version": "3.8",
        "networks": {
            "proxy": {
                "external": True
            }
        },
        "services": {}
    }
    
    # Traefik
    compose["services"]["traefik"] = {
        "image": "traefik:v3.0",
        "container_name": "traefik",
        "restart": "unless-stopped",
        "ports": ["80:80", "443:443"],
        "volumes": [
            "/var/run/docker.sock:/var/run/docker.sock:ro",
            "./traefik/traefik.yml:/traefik.yml:ro",
            "./data/traefik/acme.json:/acme.json",
            "./traefik:/etc/traefik"
        ],
        "networks": ["proxy"],
        "environment": [
            f"TZ={timezone}"
        ]
    }
    
    # Portainer
    if services.get("portainer", True):
        compose["services"]["portainer"] = {
            "image": "portainer/portainer-ce:latest",
            "container_name": "portainer",
            "restart": "unless-stopped",
            "volumes": [
                "/var/run/docker.sock:/var/run/docker.sock",
                "./data/portainer:/data"
            ],
            "networks": ["proxy"],
            "labels": [
                "traefik.enable=true",
                f"traefik.http.routers.portainer.rule=Host(`portainer.{domain}`)",
                "traefik.http.routers.portainer.entrypoints=websecure",
                "traefik.http.routers.portainer.tls.certresolver=letsencrypt",
                "traefik.http.services.portainer.loadbalancer.server.port=9000"
            ],
            "environment": [
                f"TZ={timezone}"
            ]
        }
    
    # EarnApp
    if services.get("earnapp", True):
        earnapp_token = services.get("earnapp", {}).get("token", "")
        if earnapp_token:
            compose["services"]["earnapp"] = {
                "image": "fazalfarhan01/earnapp:latest",
                "container_name": "earnapp",
                "restart": "unless-stopped",
                "networks": ["proxy"],
                "environment": [
                    f"TOKEN={earnapp_token}",
                    f"TZ={timezone}"
                ],
                "labels": [
                    "traefik.enable=true",
                    f"traefik.http.routers.earnapp.rule=Host(`earnapp.{domain}`)",
                    "traefik.http.routers.earnapp.entrypoints=websecure",
                    "traefik.http.routers.earnapp.tls.certresolver=letsencrypt",
                    "traefik.http.services.earnapp.loadbalancer.server.port=80"
                ]
            }
    
    # Repocket
    if services.get("repocket", True):
        repocket_token = services.get("repocket", {}).get("token", "")
        if repocket_token:
            compose["services"]["repocket"] = {
                "image": "ghcr.io/repocket/repocket:latest",
                "container_name": "repocket",
                "restart": "unless-stopped",
                "networks": ["proxy"],
                "environment": [
                    f"REPOCKET_TOKEN={repocket_token}",
                    f"TZ={timezone}"
                ],
                "labels": [
                    "traefik.enable=true",
                    f"traefik.http.routers.repocket.rule=Host(`repocket.{domain}`)",
                    "traefik.http.routers.repocket.entrypoints=websecure",
                    "traefik.http.routers.repocket.tls.certresolver=letsencrypt",
                    "traefik.http.services.repocket.loadbalancer.server.port=80"
                ]
            }
    
    # docker-compose.yml schreiben
    output_file = Path("docker-compose.yml")
    with open(output_file, "w", encoding="utf-8") as f:
        # Manuelles YAML schreiben für bessere Kontrolle im GitHub-Editor
        f.write('version: "3.8"\n\n')
        f.write('networks:\n')
        f.write('  proxy:\n')
        f.write('    external: true\n\n')
        f.write('services:\n')
        
        # Traefik
        f.write('  traefik:\n')
        f.write('    image: traefik:v3.0\n')
        f.write('    container_name: traefik\n')
        f.write('    restart: unless-stopped\n')
        f.write('    ports:\n')
        f.write('      - "80:80"\n')
        f.write('      - "443:443"\n')
        f.write('    volumes:\n')
        f.write('      - /var/run/docker.sock:/var/run/docker.sock:ro\n')
        f.write('      - ./traefik/traefik.yml:/traefik.yml:ro\n')
        f.write('      - ./data/traefik/acme.json:/acme.json\n')
        f.write('      - ./traefik:/etc/traefik\n')
        f.write('    networks:\n')
        f.write('      - proxy\n')
        f.write(f'    environment:\n')
        f.write(f'      - TZ={timezone}\n\n')
        
        # Portainer
        if services.get("portainer", True):
            f.write('  portainer:\n')
            f.write('    image: portainer/portainer-ce:latest\n')
            f.write('    container_name: portainer\n')
            f.write('    restart: unless-stopped\n')
            f.write('    volumes:\n')
            f.write('      - /var/run/docker.sock:/var/run/docker.sock\n')
            f.write('      - ./data/portainer:/data\n')
            f.write('    networks:\n')
            f.write('      - proxy\n')
            f.write('    labels:\n')
            f.write('      - traefik.enable=true\n')
            f.write(f'      - traefik.http.routers.portainer.rule=Host(`portainer.{domain}`)\n')
            f.write('      - traefik.http.routers.portainer.entrypoints=websecure\n')
            f.write('      - traefik.http.routers.portainer.tls.certresolver=letsencrypt\n')
            f.write('      - traefik.http.services.portainer.loadbalancer.server.port=9000\n')
            f.write(f'    environment:\n')
            f.write(f'      - TZ={timezone}\n\n')
        
        # EarnApp
        if services.get("earnapp", True):
            earnapp_token = services.get("earnapp", {}).get("token", "")
            if earnapp_token:
                f.write('  earnapp:\n')
                f.write('    image: fazalfarhan01/earnapp:latest\n')
                f.write('    container_name: earnapp\n')
                f.write('    restart: unless-stopped\n')
                f.write('    networks:\n')
                f.write('      - proxy\n')
                f.write('    environment:\n')
                f.write(f'      - TOKEN={earnapp_token}\n')
                f.write(f'      - TZ={timezone}\n')
                f.write('    labels:\n')
                f.write('      - traefik.enable=true\n')
                f.write(f'      - traefik.http.routers.earnapp.rule=Host(`earnapp.{domain}`)\n')
                f.write('      - traefik.http.routers.earnapp.entrypoints=websecure\n')
                f.write('      - traefik.http.routers.earnapp.tls.certresolver=letsencrypt\n')
                f.write('      - traefik.http.services.earnapp.loadbalancer.server.port=80\n\n')
        
        # Repocket
        if services.get("repocket", True):
            repocket_token = services.get("repocket", {}).get("token", "")
            if repocket_token:
                f.write('  repocket:\n')
                f.write('    image: ghcr.io/repocket/repocket:latest\n')
                f.write('    container_name: repocket\n')
                f.write('    restart: unless-stopped\n')
                f.write('    networks:\n')
                f.write('      - proxy\n')
                f.write('    environment:\n')
                f.write(f'      - REPOCKET_TOKEN={repocket_token}\n')
                f.write(f'      - TZ={timezone}\n')
                f.write('    labels:\n')
                f.write('      - traefik.enable=true\n')
                f.write(f'      - traefik.http.routers.repocket.rule=Host(`repocket.{domain}`)\n')
                f.write('      - traefik.http.routers.repocket.entrypoints=websecure\n')
                f.write('      - traefik.http.routers.repocket.tls.certresolver=letsencrypt\n')
                f.write('      - traefik.http.services.repocket.loadbalancer.server.port=80\n')
    
    print("✅ docker-compose.yml wurde erfolgreich generiert!")
    print(f"   Domain: {domain}")
    print("   Enthaltene Services: Traefik + " + 
          ("Portainer, " if services.get("portainer", True) else "") +
          ("EarnApp, " if services.get("earnapp", {}).get("token") else "") +
          ("Repocket" if services.get("repocket", {}).get("token") else ""))

if __name__ == "__main__":
    main()
