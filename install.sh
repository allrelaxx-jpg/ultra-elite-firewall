#!/usr/bin/env bash
set -e

echo "ULTRA ELITE FIREWALL INSTALLER v10.6.1 FINAL"

INSTALL_DIR="/opt/ultra-firewall"

echo "[0] Prepare system"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[1] Download latest core (no cache)"

FIREWALL_URL="https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/firewall.sh"
GEO_URL="https://raw.githubusercontent.com/allrelaxx-jpg/ultra-elite-firewall/main/geo-update.sh"

curl -fsSL "$FIREWALL_URL?nocache=$(date +%s)" -o firewall.sh
curl -fsSL "$GEO_URL?nocache=$(date +%s)" -o geo-update.sh

chmod +x firewall.sh geo-update.sh

echo "[2] Backup current config (safe)"
if [ -f /etc/nftables.conf ]; then
  cp /etc/nftables.conf /etc/nftables.conf.bak.$(date +%s)
fi

echo "[3] Run firewall core"
bash firewall.sh

echo "[4] Setup GeoIP auto-update (cron)"

(crontab -l 2>/dev/null | grep -v geo-update.sh; echo "0 3 * * * bash $INSTALL_DIR/geo-update.sh") | crontab -

echo "[5] Verify services"

systemctl is-active nftables >/dev/null && echo "nftables OK" || echo "nftables FAILED"
systemctl is-active fail2ban >/dev/null && echo "fail2ban OK" || echo "fail2ban FAILED"

echo ""
echo "INSTALL COMPLETE"
echo "Firewall version: v10.6.1 FINAL"
echo "Location: $INSTALL_DIR"
