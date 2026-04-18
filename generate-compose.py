#!/usr/bin/env python3
import json
import os
from collections import OrderedDict

def load_json(filepath):
    with open(filepath, 'r') as f:
        return json.load(f, object_pairs_hook=OrderedDict)

def main():
    apps_schema = load_json('config/apps.json')
    user_config = load_json('config/user-config.json')

    compose = OrderedDict([
        ('version', '3.8'),
        ('services', OrderedDict())
    ])

    # Watchtower global aktivieren?
    if user_config.get('global', {}).get('WATCHTOWER_ENABLED', True):
        compose['services']['watchtower'] = apps_schema['watchtower']

    # App-spezifische Services
    for app_name, app_def in apps_schema.items():
        if app_name == 'watchtower':
            continue

        # Default enabled?
        is_enabled = app_def.get('enabled_by_default', False)
        
        # User override?
        user_app_settings = user_config.get('apps', {}).get(app_name, {})
        if 'ENABLED' in user_app_settings:
            is_enabled = user_app_settings['ENABLED']

        if not is_enabled and not user_app_settings:
            continue
        if not is_enabled and all(v == "" for v in user_app_settings.values()):
            continue

        service = OrderedDict()
        service['image'] = app_def['image']
        
        # Required fields check
        required = app_def.get('required_fields', [])
        missing = [field for field in required if not user_app_settings.get(field)]
        if missing:
            print(f"[WARN] {app_name} deaktiviert - fehlende Felder: {missing}")
            continue

        if 'volumes' in app_def:
            service['volumes'] = app_def['volumes']
        if 'ports' in app_def:
            service['ports'] = app_def['ports']
        if 'command' in app_def:
            service['command'] = app_def['command']
        if 'cap_add' in app_def:
            service['cap_add'] = app_def['cap_add']
        if 'restart' in app_def:
            service['restart'] = app_def['restart']
            
        # Environment merge
        env = {}
        if 'environment' in app_def:
            env.update(app_def['environment'])
        env.update({k: v for k, v in user_app_settings.items() if k != 'ENABLED'})
        if env:
            service['environment'] = env
            
        compose['services'][app_name] = service

    # Schreibe docker-compose.yaml
    with open('docker-compose.yaml', 'w') as f:
        json.dump(compose, f, indent=2)
    print("✅ docker-compose.yaml wurde generiert")

if __name__ == '__main__':
    main()
