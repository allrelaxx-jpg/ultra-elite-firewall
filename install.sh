#!/usr/bin/env bash
set -e

echo "ULTRA ELITE FIREWALL INSTALLER"

INSTALL_DIR="/opt/ultra-firewall"

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[1] Download core"
curl -sLO https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/firewall.sh
curl -sLO https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/geo-update.sh

chmod +x *.sh

echo "[2] Install firewall"
bash firewall.sh

echo "[3] Setup GeoIP auto-update"
(crontab -l 2>/dev/null; echo "0 3 * * * bash $INSTALL_DIR/geo-update.sh") | crontab -

echo "✅ INSTALL COMPLETE"
