#!/usr/bin/env bash

echo "🧨 Removing firewall..."

systemctl stop nftables
systemctl disable nftables

rm -rf /etc/nftables.conf
rm -rf /etc/nftables

echo "Done"
