#!/usr/bin/env bash
set -euo pipefail

echo "ULTRA ELITE FIREWALL CORE v10.5.1"

### CONFIG
SSH_PORT=22
REALITY_PORT=8443
WG_PORT=51820
FASTPANEL_PORT=8888
PANEL_PORTS="2053,2096"
ALLOWED_COUNTRIES="ru de nl at us"

### INSTALL BASE
apt update -y >/dev/null 2>&1
apt install -y nftables curl jq iptables fail2ban ca-certificates >/dev/null 2>&1

update-alternatives --set iptables /usr/sbin/iptables-nft || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-nft || true

### CROWDSEC
curl -s https://install.crowdsec.net | bash >/dev/null 2>&1
apt install -y crowdsec crowdsec-firewall-bouncer-nftables >/dev/null 2>&1

systemctl enable crowdsec >/dev/null 2>&1
systemctl restart crowdsec

### GEOIP
mkdir -p /etc/nftables/geoip

for CC in $ALLOWED_COUNTRIES; do
 curl -s https://www.ipdeny.com/ipblocks/data/countries/${CC}.zone \
 -o /etc/nftables/geoip/${CC}.zone
done

cat /etc/nftables/geoip/*.zone > /etc/nftables/geoip/allowed.txt

### NFTABLES CONFIG (SAFE BUILD)
echo "Generating nftables config..."

{
echo "flush ruleset"
echo ""
echo "table inet filter {"

echo " set allowed_geo {"
echo "  type ipv4_addr"
echo "  flags interval"
echo "  elements = {"

# безопасная генерация без лишней запятой
awk '{print $1}' /etc/nftables/geoip/allowed.txt | sed '$!s/$/,/' | sed 's/^/   /'

echo "  }"
echo " }"

cat << EOF

 chain input {
  type filter hook input priority 0;
  policy drop;

  ct state established,related accept
  iif lo accept

  ip protocol icmp limit rate 10/second accept

  # anti scan
  tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop

  # SYN protection (FIXED)
  tcp flags syn limit rate 25/second burst 50 packets accept

  # VPN OPEN
  tcp dport $REALITY_PORT accept
  udp dport $WG_PORT accept

  # SSH GEO
  tcp dport $SSH_PORT ip saddr @allowed_geo accept

  # PANELS GEO
  tcp dport { $FASTPANEL_PORT, $PANEL_PORTS } ip saddr @allowed_geo accept

  drop
 }

 chain forward {
  type filter hook forward priority 0;
  policy accept;
 }

 chain output {
  type filter hook output priority 0;
  policy accept;
 }
}
EOF

} > /etc/nftables.conf

### VALIDATE BEFORE APPLY (ВАЖНО)
echo "Validating nftables config..."

if nft -c -f /etc/nftables.conf; then
  echo "Config valid, applying..."
  systemctl enable nftables >/dev/null 2>&1
  systemctl restart nftables
else
  echo "ERROR: nftables config invalid!"
  exit 1
fi

### FAIL2BAN
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
EOF

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban

echo "FIREWALL v10.5.1 ACTIVE"
