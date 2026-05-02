#!/usr/bin/env bash
# Reproducible demo script for WhatsApp setup
# This is run inside asciinema. Use echo + sleep to pace the narrative.

clear
echo -e "\033[1;36m=== moto WhatsApp Setup ===\033[0m"
sleep 1

echo ""
echo "$ cd whatsapp && cp .env.example .env"
sleep 0.5
echo "$ docker-compose up -d"
sleep 1
echo -e "\033[32m[+] Starting clawdbot container...\033[0m"
sleep 1
echo -e "\033[32m[+] Container running on port 3000\033[0m"

echo ""
echo "$ ./clawdbot-ctl login"
sleep 0.5
echo -e "\033[33m[!] Open WhatsApp → Settings → Linked Devices → Link a Device\033[0m"
sleep 2
echo -e "\033[32m[+] QR code scanned. Session linked.\033[0m"

echo ""
echo "$ ./safe-wa-send \"Alice\" \"Hey from moto 👋\""
sleep 0.5
echo -e "\033[36m  Resolved: Alice (+1 555-0199)\033[0m"
echo -e "\033[36m  JID: 15550199@s.whatsapp.net\033[0m"
echo -e "\033[36m  Message: Hey from moto 👋\033[0m"
echo -e "\033[31m  [DRY RUN] Add --confirmed to send.\033[0m"

echo ""
echo "$ ./safe-wa-send \"Alice\" \"Hey from moto 👋\" --confirmed"
sleep 0.5
echo -e "\033[32m[+] Message sent to Alice (+1 555-0199)\033[0m"

echo ""
echo -e "\033[1;36m=== Done ===\033[0m"
sleep 1
