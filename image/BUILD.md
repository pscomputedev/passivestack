# PassiveStack Image Build Anleitung

## Voraussetzungen

Build-System: Ubuntu 22.04 oder Debian 12 (x86_64)

```bash
sudo apt install -y \
  coreutils quilt parted qemu-user-static debootstrap \
  zerofree zip dosfstools libcap2-bin rsync xz-utils \
  file git curl bc
```

## Image bauen

```bash
# 1. pi-gen klonen
git clone https://github.com/RPi-Distro/pi-gen.git
cd pi-gen

# 2. PassiveStack Stage einfügen
cp -r /pfad/zu/passivestack/image/stage-passivestack ./
cp /pfad/zu/passivestack/image/pi-gen-config ./config

# 3. PassiveStack-Dateien in Stage kopieren
mkdir -p stage-passivestack/00-passivestack/files/
cp -r /pfad/zu/passivestack/. \
  stage-passivestack/00-passivestack/files/passivestack/
cp /pfad/zu/passivestack/image/passivestack-firstboot.service \
  stage-passivestack/00-passivestack/files/

# 4. Stages 3-5 überspringen (kein Desktop)
touch ./stage3/SKIP ./stage4/SKIP ./stage5/SKIP
touch ./stage4/SKIP_IMAGES ./stage5/SKIP_IMAGES

# 5. Image bauen (dauert 20-40 Minuten)
sudo bash build.sh
```

## Output

```
deploy/
└── PassiveStack-v1.3-arm64.img.xz   (~500 MB komprimiert)
```

## Image flashen

Mit [Raspberry Pi Imager](https://www.raspberrypi.com/software/):
1. "Use custom image" wählen
2. `PassiveStack-v1.3-arm64.img.xz` auswählen
3. SSH aktivieren + WLAN konfigurieren (optional)
4. Auf SD-Karte schreiben

## Erster Boot

1. SD-Karte in Pi einlegen, einschalten
2. Pi verbindet sich mit Netzwerk
3. `passivestack-firstboot.service` läuft automatisch:
   - Installiert Docker
   - Richtet sysctl ein
   - Rebootet einmalig
4. Nach Reboot: SSH einloggen
   ```bash
   ssh pi@passivestack.local
   # Passwort: passivestack
   ```
5. PassiveStack konfigurieren:
   ```bash
   cd ~/passivestack && ./install.sh
   ```

## Verkauf / Distribution

Das fertige Image kann als digitaler Download verkauft werden.
Empfohlene Plattformen: Gumroad, LemonSqueezy, eigener Shop.

Standardpasswort `passivestack` muss beim ersten Login geändert werden —
im `firstboot.sh` ist `passwd` Zwangsänderung integrierbar.
