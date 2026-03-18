#!/usr/bin/env bash
set -euo pipefail

echo "ULTRA ELITE FIREWALL CORE START"

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

### NFTABLES CONFIG
cat > /etc/nftables.conf << 'NFT'
flush ruleset

table inet filter {

 set allowed_geo {
  type ipv4_addr
  flags interval
  elements = {
NFT

awk '{print "   "$1","}' /etc/nftables/geoip/allowed.txt >> /etc/nftables.conf

cat >> /etc/nftables.conf << 'NFT'
  }
 }

 chain input {
  type filter hook input priority 0;
  policy drop;

  ct state established,related accept
  iif lo accept

  ### ICMP
  ip protocol icmp limit rate 10/second accept

  ### Anti-scan
  tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop

  ### SYN protection
  tcp flags syn limit rate 25/second burst 50 accept

  ### VPN OPEN
  tcp dport 8443 accept
  udp dport 51820 accept

  ### SSH GEO
  tcp dport 22 ip saddr @allowed_geo accept

  ### PANELS GEO
  tcp dport { 8888, 2053, 2096 } ip saddr @allowed_geo accept

  ### FINAL DROP
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
NFT

### APPLY
systemctl enable nftables >/dev/null 2>&1
systemctl restart nftables

### FAIL2BAN
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 22
EOF

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban

echo "FIREWALL ACTIVE"
