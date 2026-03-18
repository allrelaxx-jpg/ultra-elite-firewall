#!/usr/bin/env bash
set -euo pipefail

echo "ULTRA ELITE FIREWALL v10.6.4 FINAL (VPN SAFE)"

SSH_PORT=22
REALITY_PORT=8443
WG_PORT=51820
FASTPANEL_PORT=8888
PANEL_PORTS="2053,2096"
ALLOWED_COUNTRIES="ru de nl at us"

apt update -y >/dev/null 2>&1
apt install -y nftables curl jq iptables fail2ban ca-certificates >/dev/null 2>&1

update-alternatives --set iptables /usr/sbin/iptables-nft || true

### CROWDSEC
curl -s https://install.crowdsec.net | bash >/dev/null 2>&1
apt install -y crowdsec crowdsec-firewall-bouncer-nftables >/dev/null 2>&1

systemctl enable crowdsec
systemctl restart crowdsec

### GEOIP
mkdir -p /etc/nftables/geoip

for CC in $ALLOWED_COUNTRIES; do
 curl -s https://www.ipdeny.com/ipblocks/data/countries/${CC}.zone \
 -o /etc/nftables/geoip/${CC}.zone
done

cat /etc/nftables/geoip/*.zone > /etc/nftables/geoip/allowed.txt

### CLOUDFLARE
curl -s https://www.cloudflare.com/ips-v4 > /etc/nftables/cloudflare.txt

### DETECT INTERFACE
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

### BUILD CONFIG
{
echo "flush ruleset"

########################
# FILTER TABLE
########################
echo "table inet filter {"

echo " set allowed_geo {"
echo "  type ipv4_addr"
echo "  flags interval"
echo "  elements = {"
awk '{print $1}' /etc/nftables/geoip/allowed.txt | sed '$!s/$/,/' | sed 's/^/   /'
echo "  }"
echo " }"

echo " set cloudflare {"
echo "  type ipv4_addr"
echo "  flags interval"
echo "  elements = {"
awk '{print $1}' /etc/nftables/cloudflare.txt | sed '$!s/$/,/' | sed 's/^/   /'
echo "  }"
echo " }"

cat << EOF

 chain input {
  type filter hook input priority 0;
  policy drop;

  ct state established,related accept
  iif lo accept

  ip protocol icmp accept

  tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop
  tcp flags syn limit rate 25/second burst 50 packets accept

  # Web only via Cloudflare
  tcp dport {80,443} ip saddr @cloudflare accept

  # VPN
  tcp dport $REALITY_PORT accept
  udp dport $WG_PORT accept
  udp dport 32690-32700 accept

  # CYBER AI CORE
  tcp dport 4000 accept

  # Dashboard via VPN
  tcp dport 3000 ip saddr 10.0.0.0/24 accept

  # SSH GEO + brute protect
  ct state new tcp dport $SSH_PORT ip saddr @allowed_geo limit rate 5/minute burst 10 packets accept

  # Panels GEO
  tcp dport { $FASTPANEL_PORT, $PANEL_PORTS } ip saddr @allowed_geo accept

  ct state new limit rate 50/second burst 100 packets accept

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

########################
# NAT TABLE (VPN FIX)
########################
cat << EOF

table ip nat {
 chain postrouting {
  type nat hook postrouting priority 100;
  oifname "$IFACE" masquerade
 }
}
EOF

} > /etc/nftables.conf

### APPLY
echo "Validating nftables..."

if nft -c -f /etc/nftables.conf; then
  systemctl enable nftables >/dev/null 2>&1
  systemctl restart nftables
else
  echo "NFT ERROR"
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

echo "FIREWALL v10.6.4 FINAL ACTIVE"
