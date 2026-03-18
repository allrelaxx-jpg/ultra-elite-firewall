#!/usr/bin/env bash
set -e

echo "ULTRA ELITE FIREWALL INSTALLER v10.6 PRO CF SAFE"

INSTALL_DIR="/opt/ultra-firewall"

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[1] Download latest core"

curl -sL "https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/firewall.sh?nocache=$(date +%s)" -o firewall.sh
curl -sL "https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/geo-update.sh?nocache=$(date +%s)" -o geo-update.sh

chmod +x *.sh

echo "[2] Run firewall"
bash firewall.sh

echo "[3] Setup GeoIP auto-update"
(crontab -l 2>/dev/null; echo "0 3 * * * bash $INSTALL_DIR/geo-update.sh") | crontab -

echo "INSTALL COMPLETE"
