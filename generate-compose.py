import json
import os
from jinja2 import Template

# Lade Konfigurationen
with open('config/apps.json', 'r') as f:
    apps = json.load(f)

with open('user-config.json', 'r') as f:
    user_config = json.load(f)

# Basis Docker Compose Template (komplett)
compose_template = """version: '3.8'

networks:
  proxy:
    external: true
  default:
    driver: bridge

services:
{% for service_name, config in apps.items() %}
  {% if config.get('enabled', False) or service_name in ['traefik', 'homepage', 'portainer', 'watchtower'] %}
  {{ service_name }}:
    image: {{ config['image'] }}
    container_name: {{ config.get('container_name', service_name) }}
    restart: {{ config.get('restart', 'unless-stopped') }}
    {% if config.get('security_opt') %}security_opt: {{ config['security_opt'] | tojson }}{% endif %}
    {% if config.get('networks') %}networks: {{ config['networks'] | tojson }}{% endif %}
    {% if config.get('ports') %}ports: {{ config['ports'] | tojson }}{% endif %}
    {% if config.get('volumes') %}volumes: {{ config['volumes'] | tojson }}{% endif %}
    {% if config.get('environment') %}
    environment:
      {% for key, value in config['environment'].items() %}
      - {{ key }}={{ value }}
      {% endfor %}
    {% endif %}
    {% if config.get('command') %}command: {{ config['command'] }}{% endif %}
    {% if config.get('labels') %}
    labels:
      {% for key, value in config['labels'].items() %}
      - "{{ key }}={{ value }}"
      {% endfor %}
    {% endif %}
  {% endif %}
{% endfor %}
"""

# Render Template
template = Template(compose_template)
rendered = template.render(apps=apps)

# Schreibe docker-compose.yml
with open('docker-compose.yml', 'w') as f:
    f.write(rendered)

print("✅ docker-compose.yml wurde erfolgreich generiert!")
print("   Aktivierte Services:")
for name, cfg in apps.items():
    if cfg.get('enabled', False) or name in ['traefik', 'homepage', 'portainer', 'watchtower']:
        print(f"   - {name}")
#!/usr/bin/env python3
import json
import os
from pathlib import Path

# ===================== CONFIG =====================
CONFIG_FILE = Path("config/user-config.json")
OUTPUT_FILE = Path("docker-compose.yml")

# ===================== LOAD CONFIG =====================
if not CONFIG_FILE.exists():
    print(f"Fehler: {CONFIG_FILE} nicht gefunden!")
    exit(1)

with open(CONFIG_FILE, "r") as f:
    config = json.load(f)

global_cfg = config.get("global", {})
apps = config.get("apps", {})

# ===================== HELPER FUNCTIONS =====================
def env(var_name: str, value):
    if value is None or value == "":
        return ""
    return f'      - {var_name}={value}'

def service_header(name: str, image: str, restart: str = "unless-stopped"):
    return f"""  {name}:
    image: {image}
    container_name: {name}
    restart: {restart}
    network_mode: bridge
"""

# ===================== START COMPOSE =====================
compose = f"""version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    network_mode: bridge
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/traefik:/letsencrypt
    environment:
      - TZ={global_cfg.get('timezone', 'Europe/Berlin')}
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.myresolver.acme.tlschallenge=true
      - --certificatesresolvers.myresolver.acme.email={global_cfg.get('email', 'your@email.com')}
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
"""

# Watchtower
if config.get("watchtower", {}).get("enabled", True):
    compose += """
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ={timezone}
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 3 * * *
""".format(timezone=global_cfg.get('timezone', 'Europe/Berlin'))

# ===================== SERVICES =====================

# Grass
if apps.get("grass", {}).get("email"):
    g = apps["grass"]
    compose += service_header("grass", "grasscloud/cloud-node:latest")
    compose += f"""    environment:
{env('GRASS_EMAIL', g.get('email'))}
{env('GRASS_PASSWORD', g.get('password'))}
    volumes:
      - ./data/grass:/data
"""

# Honeygain
if apps.get("honeygain", {}).get("email"):
    h = apps["honeygain"]
    compose += service_header("honeygain", "honeygain/honeygain:latest")
    compose += f"""    environment:
{env('HONEYGAIN_EMAIL', h.get('email'))}
{env('HONEYGAIN_PASSWORD', h.get('password'))}
{env('HONEYGAIN_DEVICE', h.get('device', 'passivestack-pi'))}
    cap_add:
      - NET_ADMIN
"""

# EarnApp
if apps.get("earnapp", {}).get("token"):
    compose += service_header("earnapp", "fazalfarhan01/earnapp:latest")
    compose += f"""    environment:
{env('EARNAPP_TOKEN', apps['earnapp'].get('token'))}
    volumes:
      - ./data/earnapp:/app
"""

# IPRoyal
if apps.get("iproyal", {}).get("email") and apps.get("iproyal", {}).get("password"):
    i = apps["iproyal"]
    compose += service_header("iproyal", "iproyal/pawns-cli:latest")
    compose += f"""    environment:
{env('IPROYAL_EMAIL', i.get('email'))}
{env('IPROYAL_PASSWORD', i.get('password'))}
{env('IPROYAL_DEVICE', i.get('device', 'passivestack-pi'))}
{env('IPROYAL_DEVICE_ID', i.get('device_id', 'auto'))}
"""

# Repocket
if apps.get("repocket", {}).get("api_key"):
    compose += service_header("repocket", "repocket/repocket:latest")
    compose += f"""    environment:
{env('REPOCKET_API_KEY', apps['repocket'].get('api_key'))}
{env('REPOCKET_EMAIL', apps['repocket'].get('email'))}
"""

# Traffmonetizer
if apps.get("traffmonetizer", {}).get("token"):
    compose += service_header("traffmonetizer", "traffmonetizer/traffmonetizer:latest")
    compose += f"""    command: start accept --token {apps['traffmonetizer'].get('token')}
"""

# Packetstream
if apps.get("packetstream", {}).get("cid"):
    compose += service_header("packetstream", "packetstream/psnode:latest")
    compose += f"""    environment:
{env('CID', apps['packetstream'].get('cid'))}
"""

# EarnFM
if apps.get("earnfm", {}).get("token"):
    compose += service_header("earnfm", "earnfm/earnfm-client:latest")
    compose += f"""    environment:
{env('EARNFM_TOKEN', apps['earnfm'].get('token'))}
"""

# Bitping
if apps.get("bitping", {}).get("email") and apps.get("bitping", {}).get("password"):
    b = apps["bitping"]
    compose += service_header("bitping", "bitping/node:latest")
    compose += f"""    environment:
{env('BITPING_EMAIL', b.get('email'))}
{env('BITPING_PASSWORD', b.get('password'))}
"""

# Mysterium
if apps.get("mysterium", {}).get("api_key"):
    compose += service_header("mysterium", "mysteriumnetwork/myst:latest")
    compose += f"""    environment:
{env('MYSTERIUM_API_KEY', apps['mysterium'].get('api_key'))}
    volumes:
      - ./data/mysterium:/var/lib/mysterium-node
"""

# ===================== WRITE FILE =====================
with open(OUTPUT_FILE, "w") as f:
    f.write(compose)

print("✅ docker-compose.yml wurde erfolgreich generiert!")
print(f"   Konfiguration basiert auf: {CONFIG_FILE}")
print(f"   Aktivierte Services: {len([k for k,v in apps.items() if v and any(v.values())])}")
