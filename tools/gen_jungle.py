"""Regenerate monkey.jungle: picks a colour theme per watch from the SDK's device data.

Usage: python3 tools/gen_jungle.py   (needs the device files in ~/.Garmin/ConnectIQ/Devices)
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEVICES = Path.home() / ".Garmin/ConnectIQ/Devices"
THEMES = ["color", "mip", "lowcolor", "mono"]

products = re.findall(r'<iq:product id="([^"]+)"/>', (ROOT / "manifest.xml").read_text())
lines = [
    "project.manifest = manifest.xml",
    "",
    "# Unit tests (built with: monkeyc --unit-test ...)",
    "base.sourcePath = source;source-test",
    "",
    "# Per watch: colour theme for its screen (source/Theme.mc) and whether it has",
    "# the Notifications API (CIQ 5.1+: (:notif), else (:nonotif)). (:forcebg) is a",
    "# simulator-only background check, excluded from every normal build.",
    "base.excludeAnnotations = mip;lowcolor;mono;nonotif;forcebg",
]
counts = {t: 0 for t in THEMES}
for p in sorted(products):
    j = json.loads((DEVICES / p / "compiler.json").read_text())
    bpp, kind = j.get("bitsPerPixel", 16), j.get("displayType", "")
    theme = "mono" if bpp <= 1 else "lowcolor" if bpp <= 4 else "mip" if kind == "mip" else "color"
    counts[theme] += 1
    major, minor = (int(x) for x in j["partNumbers"][0]["connectIQVersion"].split(".")[:2])
    notif = (major, minor) >= (5, 1)
    if theme != "color" or not notif:
        excl = [t for t in THEMES if t != theme] + ["nonotif" if notif else "notif", "forcebg"]
        lines.append(f"{p}.excludeAnnotations = {';'.join(excl)}")
(ROOT / "monkey.jungle").write_text("\n".join(lines) + "\n")
print(counts)
