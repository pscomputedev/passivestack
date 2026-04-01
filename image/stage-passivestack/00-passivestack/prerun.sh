#!/bin/bash -e
# ============================================================
# pi-gen Stage: PassiveStack vorinstallieren
# ============================================================

FILES_DIR="${STAGE_DIR}/00-passivestack/files"

echo "=== PassiveStack Stage: Starte Vorinstallation ==="

# PassiveStack-Dateien ins Image kopieren
mkdir -p "${ROOTFS_DIR}/home/pi/passivestack"
cp -r "${FILES_DIR}/passivestack/." \
  "${ROOTFS_DIR}/home/pi/passivestack/"

# Firstboot-Marker
touch "${ROOTFS_DIR}/home/pi/passivestack/.firstboot_pending"

# Firstboot-Service
cp "${FILES_DIR}/passivestack-firstboot.service" \
  "${ROOTFS_DIR}/etc/systemd/system/"

ln -sf \
  /etc/systemd/system/passivestack-firstboot.service \
  "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/passivestack-firstboot.service"

# SSH PasswordAuthentication fix
SSHD_CFG="${ROOTFS_DIR}/etc/ssh/sshd_config"
if [ -f "${SSHD_CFG}" ]; then
  sed -i 's/^#\?[[:blank:]]*PasswordAuthentication.*/PasswordAuthentication yes/' \
    "${SSHD_CFG}"
  grep -q '^PasswordAuthentication yes' "${SSHD_CFG}" \
    || echo 'PasswordAuthentication yes' >> "${SSHD_CFG}"
fi

# Berechtigungen
chown -R 1000:1000 "${ROOTFS_DIR}/home/pi/passivestack"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/install.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/bootstrap.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/generate-compose.py"
[ -f "${ROOTFS_DIR}/home/pi/passivestack/status-updater.sh" ] && \
  chmod +x "${ROOTFS_DIR}/home/pi/passivestack/status-updater.sh"
chmod +x "${ROOTFS_DIR}/home/pi/passivestack/image/firstboot.sh"

echo "=== PassiveStack Stage: Abgeschlossen ==="
