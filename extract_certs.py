#!/usr/bin/env python3
"""
Extract every root certificate embedded in the litten.ca mobileconfig bundle
into individual DER-encoded .cer files under YouTube/Certs/.

These are bundled into the app and used as trust anchors so the client can
validate YouTube / Google (GTS, GlobalSign), ytimg, and googlevideo TLS
chains natively on iOS 6 — no VPS required. TLSFix supplies the modern
handshake/ciphers; these roots supply the modern trust store to verify against.
"""
import base64
import os
import re
import plistlib

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "/tmp/certwork/bundle.mobileconfig"
OUT = os.path.join(HERE, "YouTube", "Certs")

os.makedirs(OUT, exist_ok=True)

with open(SRC, "rb") as f:
    raw = f.read()

# The downloaded file has malformed XML declaration quotes stripped; repair
# just enough for plistlib, otherwise fall back to a manual regex scan.
def sanitize_name(name):
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name)
    if not name.lower().endswith((".cer", ".crt", ".der")):
        name += ".cer"
    # normalise extension to .cer
    name = re.sub(r"\.(crt|der)$", ".cer", name, flags=re.IGNORECASE)
    return name

count = 0
try:
    plist = plistlib.loads(raw)
    payloads = plist.get("PayloadContent", [])
    for p in payloads:
        data = p.get("PayloadContent")
        fname = p.get("PayloadCertificateFileName") or p.get("PayloadDisplayName") or f"root_{count}"
        if data is None:
            continue
        der = bytes(data) if not isinstance(data, (bytes, bytearray)) else data
        out = os.path.join(OUT, sanitize_name(fname))
        with open(out, "wb") as g:
            g.write(der)
        count += 1
except Exception as e:
    print("plistlib failed (%s), using regex fallback" % e)
    # Pair each PayloadCertificateFileName with the following <data> blob.
    pattern = re.compile(
        r"PayloadCertificateFileName</key>\s*<string>([^<]+)</string>.*?<data>\s*([A-Za-z0-9+/=\s]+?)\s*</data>",
        re.DOTALL,
    )
    for m in pattern.finditer(raw.decode("utf-8", "replace")):
        fname = m.group(1).strip()
        b64 = re.sub(r"\s+", "", m.group(2))
        try:
            der = base64.b64decode(b64)
        except Exception:
            continue
        out = os.path.join(OUT, sanitize_name(fname))
        with open(out, "wb") as g:
            g.write(der)
        count += 1

print("Extracted %d certificates to %s" % (count, OUT))
for f in sorted(os.listdir(OUT)):
    sz = os.path.getsize(os.path.join(OUT, f))
    print("  %-44s %d bytes" % (f, sz))
