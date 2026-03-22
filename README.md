# ☀️ PassiveStack

**Solar-powered passive income stack — Bandwidth Sharing & DePIN Nodes**

> Automatisierter Docker-Stack für passives Einkommen durch Bandwidth-Sharing.
> Eigene Referral-Links, kein DNS-Leak, saubere Konfiguration.
> Entwickelt für Raspberry Pi (arm64) und x86-Server (amd64).
>
> 🌐 [passivecompute.de](https://passivecompute.de)

---

## Inhalt

- [Voraussetzungen](#voraussetzungen)
- [Schnellstart](#schnellstart)
- [Was wird installiert](#was-wird-installiert)
- [Apps & Referral-Links](#apps--referral-links)
- [Projektstruktur](#projektstruktur)
- [Konfiguration](#konfiguration)
- [Dashboard](#dashboard)
- [Stack verwalten](#stack-verwalten)
- [Fehlerbehebung](#fehlerbehebung)
- [Bekannte Probleme & Fixes](#bekannte-probleme--fixes)

---

## Voraussetzungen

| Anforderung | Minimum | Empfohlen |
|-------------|---------|-----------|
| Hardware | Raspberry Pi 4 (2 GB RAM) | Pi 4 (4 GB RAM) oder x86-PC |
| OS | Debian 11 / Ubuntu 22.04 | Raspberry Pi OS Bookworm / Ubuntu 24.04 |
| Docker | 24.x | 27.x |
| Python | 3.9 | 3.11+ |
| RAM | 2 GB | 4 GB |
| Speicher | 8 GB | 32 GB |
| Upload | 10 Mbit/s | 50+ Mbit/s |

**Docker installieren (falls nicht vorhanden):**
```bash
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## Schnellstart

```bash
# 1. Repository klonen
git clone https://github.com/dein-user/passivestack.git
cd passivestack

# 2. Installer ausführen
chmod +x install.sh
./install.sh

# 3. Fertig — Dashboard öffnen
# http://DEINE-IP:8081
```

Der Installer führt dich interaktiv durch die Konfiguration:
- Gerätename festlegen
- Für jede App: Account vorhanden? → Credentials eingeben
- Stack automatisch starten

---

## Was wird installiert

```
passivestack/
├── install.sh              ← Interaktiver Installer
├── generate-compose.py     ← Compose-Generator (von install.sh aufgerufen)
├── docker-compose.yaml     ← Generiert — nicht manuell bearbeiten
├── .env                    ← Credentials (chmod 600, nicht committen!)
├── config/
│   ├── apps.json           ← App-Definitionen & Referral-Links
│   ├── user-config.json    ← Deine Einstellungen (generiert)
│   └── status.json         ← Container-Status (optional, für Dashboard)
├── dashboard/
│   ├── index.html          ← Web-Dashboard
│   └── .config/
│       └── app-config.json ← Dashboard-Konfiguration
└── .data/                  ← Persistente App-Daten (automatisch angelegt)
    ├── .earnapp/
    ├── .bitpingd/
    └── .mysterium-node/
```

> ⚠️ `.env` und `config/user-config.json` enthalten Credentials.
> Diese Dateien **niemals** in Git committen.
> Eine `.gitignore` wird automatisch angelegt.

---

## Apps & Referral-Links

Alle Links öffnen sich mit dem Referral des Projekts — du hast keine Mehrkosten.

| App | Verdienst/Monat | Payout | Referral |
|-----|----------------|--------|----------|
| [EarnApp](https://earnapp.com/i/TRYhjqRy) | $5–20 | PayPal | [Anmelden](https://earnapp.com/i/TRYhjqRy) |
| [Honeygain](https://join.honeygain.com/KRAUS21A12) | $2–10 | PayPal / Bitcoin | [Anmelden](https://join.honeygain.com/KRAUS21A12) |
| [IPRoyal Pawns](https://pawns.app/?r=10931672) | $1–5 | PayPal / Crypto | [Anmelden](https://pawns.app/?r=10931672) |
| [TraffMonetizer](https://traffmonetizer.com/?aff=2110620) | $5–20 | USDT | [Anmelden](https://traffmonetizer.com/?aff=2110620) |
| [Earn.fm](https://earn.fm/ref/MARC6JC7) | $1–5 | Crypto / PayPal | [Anmelden](https://earn.fm/ref/MARC6JC7) |
| [PacketStream](https://packetstream.io/?psr=7vdc) | $2–15 | PayPal | [Anmelden](https://packetstream.io/?psr=7vdc) |
| Repocket | $3–12 | PayPal / Wise | [Anmelden](https://app.repocket.co) |
| [Mysterium Node](https://mystnodes.co/?referral_code=VOsNXHhqET0XiSHsgaTNUkWP4SBZ0tE8OpdM9t8v) | $3–20 | MYST | [Anmelden](https://mystnodes.co/?referral_code=VOsNXHhqET0XiSHsgaTNUkWP4SBZ0tE8OpdM9t8v) |

> 💡 Verdienst-Schätzungen basieren auf 1 Gerät mit deutschem DSL-Anschluss (50+ Mbit/s Upload).
> Tatsächliche Einnahmen variieren je nach Standort, Bandbreite und Auslastung.

---

## Projektstruktur

### `apps.json`
Zentrale App-Definitionen. Enthält für jede App:
- Docker-Image, Umgebungsvariablen, Ressourcen-Limits
- Referral-Links, Dashboard-URLs
- Auth-Typ (uuid / email+password / token / apikey / cid)

**Nicht manuell bearbeiten** — Änderungen hier erfordern ein erneutes Ausführen von `install.sh`.

### `user-config.json`
Deine persönliche Konfiguration: welche Apps aktiviert sind, deine Credentials,
Gerätename und Architektur. Wird von `install.sh` generiert.

### `generate-compose.py`
Liest `apps.json` + `user-config.json` und generiert `docker-compose.yaml`.
Wird automatisch von `install.sh` aufgerufen.

Manuell ausführen nach Konfigurationsänderungen:
```bash
python3 generate-compose.py
```

### `.env`
Enthält alle Credentials als Umgebungsvariablen für Docker Compose.
Wird mit `chmod 600` angelegt — nur der Owner kann lesen.

---

## Konfiguration

### App hinzufügen oder entfernen

```bash
# Konfiguration neu durchlaufen
./install.sh

# Oder user-config.json manuell bearbeiten:
nano config/user-config.json
# enabled: true/false pro App ändern

# Compose neu generieren
python3 generate-compose.py

# Stack neu starten
docker compose -p passivestack up -d
```

### Gerätename ändern

```bash
./install.sh
# → Neuen Gerätename eingeben
# Achtung: Alle Container werden neu erstellt
```

### Mysterium Node einrichten

Mysterium ist standardmäßig deaktiviert. Aktivierung:

```bash
# 1. In user-config.json aktivieren
nano config/user-config.json
# mystnode.enabled: true setzen

# 2. Compose neu generieren
python3 generate-compose.py

# 3. Stack neu starten
docker compose -p passivestack up -d

# 4. Node-Dashboard öffnen
# http://DEINE-IP:4449
# Wizard durchlaufen und Node beanspruchen
```

---

## Dashboard

Das integrierte Web-Dashboard zeigt:
- Status aller Container (running / stopped)
- Direkte Links zu App-Dashboards
- Referral-Links mit Share-Funktion (Clipboard, WhatsApp, Telegram, Twitter/X)
- Event-Log mit Auto-Refresh alle 60 Sekunden

**Öffnen:**
```
http://DEINE-IP:8081
```

**Dashboard-Port ändern:**
```bash
# In .env:
M4B_DASHBOARD_PORT=8082  # beliebiger freier Port

# Stack neu starten
docker compose -p passivestack up -d
```

---

## Stack verwalten

```bash
# Status anzeigen
docker compose -p passivestack ps

# Logs live verfolgen
docker compose -p passivestack logs -f

# Einzelne App-Logs
docker compose -p passivestack logs -f earnapp

# Stack stoppen
docker compose -p passivestack down

# Stack starten
docker compose -p passivestack up -d

# Einzelnen Container neu starten
docker compose -p passivestack restart honeygain

# Alle Images aktualisieren (Watchtower macht das automatisch)
docker compose -p passivestack pull
docker compose -p passivestack up -d

# Stack komplett entfernen (Daten bleiben in .data/)
docker compose -p passivestack down --remove-orphans
```

---

## Fehlerbehebung

### DNS-Auflösung schlägt fehl / `apt update` funktioniert nicht

**Symptom:** `Temporary failure resolving 'deb.debian.org'`

**Ursache:** UDP-Socket-Erschöpfung durch Docker-internen DNS-Proxy bei vielen Containern.

**Lösung:**
```bash
# Sofortlösung: Docker neu starten
sudo systemctl restart docker

# Permanenter Fix (bereits in PassiveStack eingebaut):
# DNS ist explizit auf 8.8.8.8 / 1.1.1.1 gesetzt — kein interner DNS-Proxy
# Prüfen:
grep dns docker-compose.yaml
```

Falls das Problem nach einem Update auftritt:
```bash
# Sockets zählen
ss -ulnp | wc -l  # >1000 = Problem

# Neustart des Systems
sudo reboot
```

### Container startet nicht

```bash
# Logs prüfen
docker compose -p passivestack logs CONTAINERNAME

# Häufige Ursachen:
# - Falsche Credentials in .env
# - Port bereits belegt
# - Image nicht verfügbar (arm64 vs. amd64)

# Image manuell testen
docker pull IMAGE:TAG
```

### EarnApp: Node nicht sichtbar im Dashboard

Nach dem ersten Start muss der Node beansprucht werden:
```bash
# Claim-URL anzeigen
docker logs pi-bandwidth_earnapp 2>&1 | grep "earnapp.com/r"
```
Dann den Link im Browser öffnen und im EarnApp-Dashboard bestätigen.

### Mysterium: Port nicht erreichbar

```bash
# Prüfen ob Container läuft
docker compose -p passivestack ps mystnode

# Port-Weiterleitung in Fritzbox prüfen:
# Heimnetz → Netzwerk → Port-Freigaben → TCP 4449 → DEINE-IP
```

### Watchtower aktualisiert nicht

```bash
# Watchtower-Logs prüfen
docker compose -p passivestack logs watchtower

# Scope prüfen (muss passivestack sein)
docker inspect pi-bandwidth_watchtower | grep SCOPE
```

---

## Bekannte Probleme & Fixes

### TraffMonetizer: platform linux/amd64 auf arm64

TraffMonetizer's offizielles Image unterstützt arm64 — sollte auf Pi 4 laufen.
Falls Probleme:
```bash
docker pull traffmonetizer/cli_v2:latest --platform linux/arm64
```

### PacketStream: nur 1 Gerät pro IP

PacketStream erlaubt pro IP-Adresse nur 1 aktiven Client.
Bei mehreren Geräten im selben Netzwerk nur auf einem aktivieren.

### Repocket: kein Referral-Programm

Repocket bietet kein öffentliches Referral-Programm an.
Der Link führt direkt zur Registrierungsseite.

---

## Autostart nach Reboot

Docker Compose startet Container mit `restart: always` automatisch nach einem Reboot,
sobald Docker läuft. Sicherstellen dass Docker beim Boot startet:

```bash
sudo systemctl enable docker
sudo systemctl status docker
```

---

## Sicherheitshinweise

- `.env` enthält alle Credentials → **niemals in Git committen**
- `.gitignore` wird automatisch angelegt und schützt `.env` und `user-config.json`
- SSH-Zugang zum Pi mit Key-only Authentifizierung absichern
- Dashboard (Port 8081) nur im lokalen Netzwerk zugänglich halten
- Regelmäßige Updates via Watchtower (automatisch alle 4 Stunden)

---

## Lizenz

MIT License — frei verwendbar und anpassbar.

---

*Erstellt mit ❤️ — [passivecompute.de](https://passivecompute.de)*
