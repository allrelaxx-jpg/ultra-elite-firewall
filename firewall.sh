#!/usr/bin/env bash
set -euo pipefail

echo "🔥 ULTRA ELITE FIREWALL CORE"

SSH_PORT=22
REALITY_PORT=8443
WG_PORT=51820
FASTPANEL_PORT=8888
PANEL_PORTS="2053,2096"
ALLOWED_COUNTRIES="ru de nl at us"

apt update -y >/dev/null 2>&1
apt install -y nftables curl jq iptables fail2ban ca-certificates >/dev/null 2>&1

update-alternatives --set iptables /usr/sbin/iptables-nft || true

curl -s https://install.crowdsec.net | bash >/dev/null 2>&1
apt install -y crowdsec crowdsec-firewall-bouncer-nftables >/dev/null 2>&1

systemctl enable crowdsec
systemctl restart crowdsec

mkdir -p /etc/nftables/geoip

for CC in $ALLOWED_COUNTRIES; do
 curl -s https://www.ipdeny.com/ipblocks/data/countries/${CC}.zone -o /etc/nftables/geoip/${CC}.zone
done

cat /etc/nftables/geoip/*.zone > /etc/nftables/geoip/allowed.txt

cat > /etc/nftables.conf << NFT
flush ruleset

table inet filter {

 set allowed_geo {
  type ipv4_addr
  flags interval
  elements = {
$(awk '{print "   "$1","}' /etc/nftables/geoip/allowed.txt)
  }
 }

 chain input {
  type filter hook input priority 0;
  policy drop;

  ct state established,related accept
  iif lo accept

  ip protocol icmp limit rate 10/second accept

  tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop
  tcp flags syn limit rate 25/second burst 50 accept

  tcp dport $REALITY_PORT accept
  udp dport $WG_PORT accept

  tcp dport $SSH_PORT ip saddr @allowed_geo accept
  tcp dport { $FASTPANEL_PORT, $PANEL_PORTS } ip saddr @allowed_geo accept

  drop
 }

 chain forward { type filter hook forward priority 0; policy accept; }
 chain output { type filter hook output priority 0; policy accept; }
}
NFT

systemctl enable nftables
systemctl restart nftables

cat > /etc/fail2ban/jail.local << F2B
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
F2B

systemctl enable fail2ban
systemctl restart fail2ban

echo "✅ FIREWALL ACTIVE"
