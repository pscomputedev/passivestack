#!/usr/bin/env python3
"""
generate-compose.py - Erzeugt docker-compose.yaml aus Konfigurationen
Korrigierte Version - Fixt alle bekannten Fehler
"""

import json
import os
import sys
import yaml
from pathlib import Path

def load_json_file(filepath):
    """Lädt JSON-Datei mit Fehlerbehandlung"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ JSON-Fehler in {filepath}: {e}")
        sys.exit(1)
    except FileNotFoundError:
        print(f"❌ Datei nicht gefunden: {filepath}")
        sys.exit(1)

def validate_app_config(app_name, app_config):
    """Validiert App-Konfiguration"""
    required_fields = ['image', 'environment']
    for field in required_fields:
        if field not in app_config:
            print(f"❌ App '{app_name}' fehlt Feld: {field}")
            return False
    
    # Validiere Volumes-Format
    if 'volumes' in app_config:
        if not isinstance(app_config['volumes'], list):
            print(f"❌ App '{app_name}': volumes muss eine Liste sein")
            return False
    
    return True

def generate_compose_yaml():
    """Generiert docker-compose.yaml"""
    
    # Pfade definieren
    base_dir = Path(__file__).parent
    apps_file = base_dir / "config" / "apps.json"
    user_config_file = base_dir / "config" / "user-config.json"
    output_file = base_dir / "docker-compose.yaml"
    
    print(f"📁 Working directory: {base_dir}")
    print(f"📄 Apps config: {apps_file}")
    print(f"👤 User config: {user_config_file}")
    
    # Konfigurationen laden
    apps_config = load_json_file(apps_file)
    user_config = load_json_file(user_config_file)
    
    # Basis-Struktur
    compose = {
        'version': '3.8',
        'services': {},
        'volumes': {},
        'networks': {
            'passivestack_net': {
                'driver': 'bridge',
                'ipam': {
                    'config': [{'subnet': '172.20.0.0/16'}]
                }
            }
        }
    }
    
    device_name = user_config.get('device_name', 'passivestack')
    
    # Durch alle Apps iterieren
    for app_name, app_data in apps_config.get('apps', {}).items():
        
        # Prüfen ob App in user-config aktiviert ist
        user_app_config = user_config.get('apps', {}).get(app_name, {})
        if not user_app_config.get('enabled', False):
            print(f"⏭️  Überspringe {app_name} (deaktiviert)")
            continue
        
        print(f"🚀 Verarbeite {app_name}...")
        
        # App-Konfiguration validieren
        if not validate_app_config(app_name, app_data):
            print(f"❌ Überspringe {app_name} wegen Konfigurationsfehler")
            continue
        
        # Service erstellen
        service = {
            'image': app_data['image'],
            'container_name': f"{device_name}_{app_name}",
            'restart': app_data.get('restart', 'unless-stopped'),
            'networks': ['passivestack_net']
        }
        
        # Umgebungsvariablen
        env_vars = []
        
        # 1. Statische Umgebungsvariablen aus apps.json
        for env_key, env_value in app_data.get('environment', {}).items():
            if env_value is not None:
                env_vars.append(f"{env_key}={env_value}")
        
        # 2. User-Credentials aus user-config.json
        credentials = user_app_config.get('credentials', {})
        for cred_key, cred_value in credentials.items():
            env_vars.append(f"{cred_key}={cred_value}")
        
        # 3. Device-Name als Umgebungsvariable
        env_vars.append(f"DEVICE_NAME={device_name}")
        
        if env_vars:
            service['environment'] = env_vars
        
        # Volumes
        volumes = []
        if 'volumes' in app_data:
            for volume_spec in app_data['volumes']:
                # Prüfe ob Volume-Spezifikation gültig ist
                if isinstance(volume_spec, str):
                    # Konvertiere relativen Pfad zu absolut
                    if volume_spec.startswith('./'):
                        host_path = str(base_dir / volume_spec[2:])
                        container_path = volume_spec[2:]
                        volumes.append(f"{host_path}:{container_path}")
                    else:
                        volumes.append(volume_spec)
        
        if volumes:
            service['volumes'] = volumes
        
        # Ports
        if 'ports' in app_data and app_data['ports']:
            service['ports'] = app_data['ports']
        
        # Devices (für Mysterium z.B.)
        if 'devices' in app_data:
            service['devices'] = app_data['devices']
        
        # Capabilities
        if 'cap_add' in app_data:
            service['cap_add'] = app_data['cap_add']
        
        # Privileged mode
        if 'privileged' in app_data:
            service['privileged'] = app_data['privileged']
        
        # Zum Compose hinzufügen
        compose['services'][app_name] = service
        
        # Volumes für persistente Daten
        if 'volumes' in app_data:
            for volume_spec in app_data['volumes']:
                if isinstance(volume_spec, str) and volume_spec.startswith('./'):
                    volume_name = f"{app_name}_data"
                    compose['volumes'][volume_name] = {
                        'driver': 'local',
                        'driver_opts': {
                            'type': 'none',
                            'device': str(base_dir / volume_spec[2:]),
                            'o': 'bind'
                        }
                    }
    
    # YAML schreiben
    try:
        with open(output_file, 'w') as f:
            yaml.dump(compose, f, default_flow_style=False, sort_keys=False)
        
        print(f"✅ docker-compose.yaml erfolgreich generiert: {output_file}")
        print(f"📊 Services: {len(compose['services'])}")
        
        # Erzeugte Datei validieren
        with open(output_file, 'r') as f:
            content = f.read()
            if 'version:' in content and 'services:' in content:
                return True
            else:
                print("❌ Generierte YAML ist ungültig!")
                return False
                
    except Exception as e:
        print(f"❌ Fehler beim Schreiben von docker-compose.yaml: {e}")
        return False

def main():
    """Hauptfunktion"""
    print("=" * 60)
    print("🔄 PassiveStack - Docker Compose Generator")
    print("=" * 60)
    
    # Prüfe ob im richtigen Verzeichnis
    if not os.path.exists("config/apps.json"):
        print("❌ Fehler: config/apps.json nicht gefunden!")
        print("   Bitte führe das Script aus dem passivestack-Verzeichnis aus.")
        return 1
    
    # Generiere Compose
    success = generate_compose_yaml()
    
    if success:
        print("\n✅ Fertig! Du kannst jetzt starten mit:")
        print("   docker compose up -d")
        return 0
    else:
        print("\n❌ Fehler bei der Generierung!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
