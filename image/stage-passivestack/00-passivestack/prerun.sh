#!/bin/bash -e
# pi-gen Stage: PassiveStack vorinstallieren

# PassiveStack-Dateien ins Image kopieren
mkdir -p "${ROOTFS_DIR}/home/pi/passivestack"
cp -r "${STAGE_DIR}/00-passivestack/files/passivestack/." \
  "${ROOTFS_DIR}/home/pi/passivestack/"

# Firstboot-Marker setzen
touch "${ROOTFS_DIR}/home/pi/passivestack/.firstboot_pending"

# Firstboot-Service installieren
cp "${STAGE_DIR}/00-passivestack/files/passivestack-firstboot.service" \
  "${ROOTFS_DIR}/etc/systemd/system/"

# Service aktivieren
ln -sf /etc/systemd/system/passivestack-firstboot.service \
  "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/passivestack-firstboot.service"

# Berechtigungen setzen
chown -R 1000:1000 "${ROOTFS_DIR}/home/pi/passivestack"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/install.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/bootstrap.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/status-updater.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/image/firstboot.sh"

echo "✅ PassiveStack Stage abgeschlossen"
