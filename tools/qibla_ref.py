"""Python mirror of `Qibla.bearing` in source/Draw.mc.

The Kaaba coordinates are parsed from Draw.mc at import time. The result is
rounded to a 32-bit Float like on the watch (Math.toDegrees(...).toFloat()).
"""

from __future__ import annotations

import math
import re
from pathlib import Path

from praytimes_ref import f32

DRAW_MC = Path(__file__).resolve().parent.parent / "source" / "Draw.mc"

_src = DRAW_MC.read_text(encoding="utf-8")
_qibla = _src[_src.index("module Qibla"):]
KAABA_LAT = float(re.search(r"const\s+KAABA_LAT\s*=\s*([-\d.]+)d?", _qibla).group(1))
KAABA_LNG = float(re.search(r"const\s+KAABA_LNG\s*=\s*([-\d.]+)d?", _qibla).group(1))


def bearing(lat: float, lng: float) -> float:
    """Initial great-circle bearing (degrees from true north, [0, 360)) towards the Kaaba."""
    p1 = math.radians(lat)
    p2 = math.radians(KAABA_LAT)
    dl = math.radians(KAABA_LNG - lng)
    y = math.sin(dl)
    x = math.cos(p1) * math.tan(p2) - math.sin(p1) * math.cos(dl)
    b = f32(math.degrees(math.atan2(y, x)))
    return f32(b + 360.0) if b < 0 else b
