#!/bin/sh
set -e

echo "=== Building via Theos ==="
rm -rf .theos packages obj YouTube.app
THEOS=/Users/balls/theos make package

echo "=== Syncing YouTube.app bundle ==="
cp -r .theos/_/Applications/YouTube.app YouTube.app

echo "=== Signing with entitlements ==="
codesign -f -s - --entitlements entitlements.xml YouTube.app

echo "=== Packaging YouTube.ipa ==="
mkdir -p Payload
cp -r YouTube.app Payload/
zip -r YouTube.ipa Payload >/dev/null
rm -rf Payload

echo "=== Build Complete: YouTube.app & YouTube.ipa updated! ==="
