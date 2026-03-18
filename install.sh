#!/usr/bin/env bash
set -e

echo "ULTRA ELITE FIREWALL INSTALLER v10.6.3 FINAL"

INSTALL_DIR="/opt/ultra-firewall"

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[1] Download latest core"

curl -fsSL "https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/firewall.sh?nocache=$(date +%s)" -o firewall.sh
curl -fsSL "https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/geo-update.sh?nocache=$(date +%s)" -o geo-update.sh

chmod +x *.sh

echo "[2] Backup current config"
[ -f /etc/nftables.conf ] && cp /etc/nftables.conf /etc/nftables.conf.bak.$(date +%s)

echo "[3] Apply firewall"
bash firewall.sh

echo "[4] Setup GeoIP auto-update"
(crontab -l 2>/dev/null | grep -v geo-update.sh; echo "0 3 * * * bash $INSTALL_DIR/geo-update.sh") | crontab -

echo "INSTALL COMPLETE"
