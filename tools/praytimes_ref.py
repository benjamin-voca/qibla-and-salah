"""Python mirror of source/PrayerCalc.mc (praytimes.org algorithm, as used by
api.aladhan.com).

This is a line-by-line port of the on-watch calculator, so it can be used to
generate golden data and to test the algorithm on a desktop. The method table,
the Kosovo seasonal corrections and the Ramadan table are parsed from the
Monkey C sources at import time, so they cannot drift apart.

    compute(year, month, day, lat, lng, tz_hours, method_index,
            tune=None, asr_factor=1, high_lat=HL_ANGLE) -> list[int]

returns minutes after local midnight in the order of the PrayerCalc enum:
IMSAK, FAJR, SUNRISE, DHUHR, ASR, SUNSET, MAGHRIB, ISHA, MIDNIGHT
(MIDNIGHT may exceed 1440). `tune` is up to 9 minutes in aladhan TUNE_ORDER
and is ADDED to the method's built-in offsets (aladhan's own `tune=` replaces
them instead).
"""

from __future__ import annotations

import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRAYER_CALC_MC = ROOT / "source" / "PrayerCalc.mc"
RAMADAN_TABLE_MC = ROOT / "source" / "RamadanTable.mc"


def f32(x: float) -> float:
    """Round a double to a Monkey C 32-bit Float."""
    return struct.unpack("f", struct.pack("f", x))[0]


# ---- parse the Monkey C sources ---------------------------------------------------

def _strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return re.sub(r"//[^\n]*", "", src)


def _const(src: str, name: str) -> str:
    m = re.search(r"\bconst\s+" + name + r"\s*=\s*(.*?);", src, flags=re.S)
    if not m:
        raise ValueError(f"const {name} not found in PrayerCalc.mc")
    return m.group(1).strip()


def _parse_prayer_calc(path: Path) -> dict:
    src = _strip_comments(path.read_text(encoding="utf-8"))
    enums = [[n.strip() for n in body.split(",") if n.strip()]
             for body in re.findall(r"\benum\s*\{(.*?)\}", src, flags=re.S)]
    prayer_enum = next(e for e in enums if "IMSAK" in e)
    hl_enum = next(e for e in enums if "HL_MIDDLE" in e)
    idx = {name: i for i, name in enumerate(prayer_enum)}
    idx.update({name: i for i, name in enumerate(hl_enum)})

    def names(expr: str) -> list[int]:
        return [idx[n.strip()] for n in expr.strip("[] \n").split(",") if n.strip()]

    seasonal_rows = re.findall(r"\[([^\[\]]*)\]", _const(src, "SEASONAL_KOSOVO"))
    return {
        "enum": prayer_enum,
        "hl_enum": hl_enum,
        "TUNE_ORDER": names(_const(src, "TUNE_ORDER")),
        "SEASONAL_TARGETS": names(_const(src, "SEASONAL_TARGETS")),
        # Literals without a `d` suffix are 32-bit Floats in Monkey C.
        "SEASONAL_KOSOVO": [[f32(float(v)) for v in r.split(",")] for r in seasonal_rows],
        "METHOD_DATA": "".join(re.findall(r'"([^"]*)"', _const(src, "METHOD_DATA"))),
        "METHOD_COUNT": int(_const(src, "METHOD_COUNT")),
        "ROW_FIELDS": int(_const(src, "ROW_FIELDS")),
        "METHOD_WIDTH": int(_const(src, "METHOD_WIDTH")),
        "KOSOVO": int(_const(src, "KOSOVO")),
        "RISESET": float(_const(src, "RISESET").rstrip("d")),
        "MAX_LAT": float(_const(src, "MAX_LAT").rstrip("d")),
        "POLAR_LAT": float(_const(src, "POLAR_LAT").rstrip("d")),
    }


def _parse_ramadan(path: Path) -> list[int]:
    src = _strip_comments(path.read_text(encoding="utf-8"))
    m = re.search(r"\bconst\s+DAYS\s*=\s*\[(.*?)\]", src, flags=re.S)
    return [int(v) for v in m.group(1).split(",") if v.strip()]


_MC = _parse_prayer_calc(PRAYER_CALC_MC)

ENUM_NAMES: list[str] = _MC["enum"]          # IMSAK .. MIDNIGHT, COUNT
(IMSAK, FAJR, SUNRISE, DHUHR, ASR, SUNSET, MAGHRIB, ISHA, MIDNIGHT, COUNT) = range(10)
assert ENUM_NAMES == ["IMSAK", "FAJR", "SUNRISE", "DHUHR", "ASR", "SUNSET",
                      "MAGHRIB", "ISHA", "MIDNIGHT", "COUNT"], ENUM_NAMES
NAMES = tuple(n.lower() for n in ENUM_NAMES[:COUNT])

HL_MIDDLE, HL_SEVENTH, HL_ANGLE = range(3)
assert _MC["hl_enum"] == ["HL_MIDDLE", "HL_SEVENTH", "HL_ANGLE"], _MC["hl_enum"]

TUNE_ORDER: list[int] = _MC["TUNE_ORDER"]
SEASONAL_KOSOVO: list[list[float]] = _MC["SEASONAL_KOSOVO"]
SEASONAL_TARGETS: list[int] = _MC["SEASONAL_TARGETS"]
METHOD_DATA: str = _MC["METHOD_DATA"]
METHOD_COUNT: int = _MC["METHOD_COUNT"]
ROW_FIELDS: int = _MC["ROW_FIELDS"]
METHOD_WIDTH: int = _MC["METHOD_WIDTH"]
KOSOVO: int = _MC["KOSOVO"]
RISESET: float = _MC["RISESET"]
MAX_LAT: float = _MC["MAX_LAT"]      # beyond this latitude ...
POLAR_LAT: float = _MC["POLAR_LAT"]  # ... use the times at this one (Islamic Fiqh Council)
RAMADAN_DAYS: list[int] = _parse_ramadan(RAMADAN_TABLE_MC)

# Toybox.Math.PI is a 32-bit Float.
MATH_PI = f32(math.pi)


# ---- port of PrayerCalc.mc --------------------------------------------------------

def ints(s: str, n: int) -> list[int]:
    """PrayerCalc.ints: "a,b,c" -> numbers (empty -> 0), padded with zeros to n."""
    out = []
    while len(s) > 0:
        i = s.find(",")
        part = s if i < 0 else s[:i]
        try:
            v = int(part)
        except ValueError:
            v = 0
        out.append(v)
        s = "" if i < 0 else s[i + 1:]
    while len(out) < n:
        out.append(0)
    return out


def row(table: str, index: int, width: int) -> str:
    return table[index * width:(index + 1) * width]


def method_row(method: int) -> list[int]:
    return ints(row(METHOD_DATA, method, METHOD_WIDTH), ROW_FIELDS)


def dsin(d): return math.sin(math.radians(d))
def dcos(d): return math.cos(math.radians(d))
def dtan(d): return math.tan(math.radians(d))
def dasin(x): return math.degrees(math.asin(x))
def dacos(x): return math.degrees(math.acos(max(-1.0, min(1.0, x))))
def datan2(y, x): return math.degrees(math.atan2(y, x))


def floor_d(x: float) -> float:
    return float(math.floor(x))


def fix(a: float, b: float) -> float:
    a = a - b * floor_d(a / b)
    return a + b if a < 0.0 else a


def days_from_j2000(year: int, month: int, day: int) -> float:
    """Days from J2000.0 to 0h UT of the given Gregorian date (JD - 2451545)."""
    if month <= 2:
        year -= 1
        month += 12
    a = int(year / 100)          # Monkey C integer division truncates
    b = 2 - a + int(a / 4)
    jd_int = int(1461 * (year + 4716) / 4) + int(306001 * (month + 1) / 10000) + day + b
    return float(jd_int - 1524 - 2451545) - 0.5


def sun_position(d: float) -> tuple[float, float]:
    """(declination, equation of time in hours) for day count d."""
    g = fix(357.529 + 0.98560028 * d, 360.0)
    q = fix(280.459 + 0.98564736 * d, 360.0)
    l = fix(q + 1.915 * dsin(g) + 0.020 * dsin(2.0 * g), 360.0)
    e = 23.439 - 0.00000036 * d
    ra = fix(datan2(dcos(e) * dsin(l), dcos(l)) / 15.0, 24.0)
    return dasin(dsin(e) * dsin(l)), q / 15.0 - ra


def no_sunrise_or_sunset(jd: float, lat: float) -> bool:
    """Mirror of PrayerCalc.noSunriseOrSunset: the Sun stays up or down all day."""
    decl = sun_position(jd + 0.5)[0]
    x = (-dsin(RISESET) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat))
    return x > 1.0 or x < -1.0


def mid_day(jd: float, t: float) -> float:
    eqt = sun_position(jd + t / 24.0)[1]
    return fix(12.0 - eqt, 24.0)


def angle_time(jd: float, lat: float, angle: float, t: float, ccw: bool) -> float:
    decl = sun_position(jd + t / 24.0)[0]
    noon = mid_day(jd, t)
    x = (-dsin(angle) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat))
    h = dacos(x) / 15.0
    return noon - h if ccw else noon + h


def asr_time(jd: float, lat: float, factor: float, t: float) -> float:
    decl = sun_position(jd + t / 24.0)[0]
    diff = abs(lat - decl)
    acot = math.degrees(math.atan(1.0 / (factor + dtan(diff))))
    return angle_time(jd, lat, 0.0 - acot, t, False)


def adjust_hl(time: float, base: float, angle: float, night: float, ccw: bool, rule: int) -> float:
    if rule == HL_ANGLE:
        portion = angle / 60.0 * night
    elif rule == HL_SEVENTH:
        portion = night / 7.0
    else:
        portion = night / 2.0
    diff = fix(base - time, 24.0) if ccw else fix(time - base, 24.0)
    if time != time or diff > portion:
        return base - portion if ccw else base + portion
    return time


def day_number(year: int, month: int, day: int) -> int:
    """Days since 1970-01-01."""
    return int(days_from_j2000(year, month, day) + 0.5) + 10957


def is_ramadan(year: int, month: int, day: int) -> bool:
    n = day_number(year, month, day)
    r = RAMADAN_DAYS
    return any(r[i] <= n < r[i + 1] for i in range(0, len(r) - 1, 2))


def compute_hours(year: int, month: int, day: int, lat: float, lng: float, tz_hours: float,
                  method_index: int, tune=None, asr_factor: int = 1,
                  high_lat: int = HL_ANGLE) -> list[float]:
    """Like compute(), but returns unrounded local hours."""
    m = method_row(method_index)
    fajr_angle = m[0] / 100.0
    isha_param = m[1] / 100.0
    isha_minutes = m[2] == 1
    maghrib_param = m[3] / 100.0
    maghrib_angle = m[4] == 1
    imsak_minutes = float(m[5])
    jafari = m[6] == 1
    ramadan_isha = m[7]
    seasonal = SEASONAL_KOSOVO if m[8] == 1 else None
    offsets = m[9:18]
    if ramadan_isha > 0 and is_ramadan(year, month, day):
        isha_param = float(ramadan_isha)


    jd = days_from_j2000(year, month, day) - lng / 360.0
    # Same rule just below 66° when the Sun doesn't rise or set that day (~65.7°+).
    if abs(lat) > MAX_LAT or no_sunrise_or_sunset(jd, lat):
        lat = -POLAR_LAT if lat < 0 else POLAR_LAT

    fajr = angle_time(jd, lat, fajr_angle, 5.0, True)
    sunrise = angle_time(jd, lat, RISESET, 6.0, True)
    dhuhr = mid_day(jd, 12.0)
    asr = asr_time(jd, lat, float(asr_factor), 13.0)
    sunset = angle_time(jd, lat, RISESET, 18.0, False)
    maghrib = angle_time(jd, lat, maghrib_param, 18.0, False) if maghrib_angle else sunset
    isha = 18.0 if isha_minutes else angle_time(jd, lat, isha_param, 18.0, False)

    shift = tz_hours - lng / 15.0
    fajr += shift; sunrise += shift; dhuhr += shift; asr += shift
    sunset += shift; maghrib += shift; isha += shift

    night = fix(sunrise - sunset, 24.0)
    fajr = adjust_hl(fajr, sunrise, fajr_angle, night, True, high_lat)
    if maghrib_angle:
        maghrib = adjust_hl(maghrib, sunset, maghrib_param, night, False, high_lat)
    else:
        maghrib = sunset + maghrib_param / 60.0
    if isha_minutes:
        isha = maghrib + isha_param / 60.0
    else:
        isha = adjust_hl(isha, sunset, isha_param, night, False, high_lat)

    imsak = fajr - imsak_minutes / 60.0
    midnight = (sunset + fix(fajr - sunset, 24.0) / 2.0) if jafari else (sunset + night / 2.0)

    t = [imsak, fajr, sunrise, dhuhr, asr, sunset, maghrib, isha, midnight]

    if seasonal is not None:
        doy = days_from_j2000(year, month, day) - days_from_j2000(year, 1, 1)
        a = 2.0 * MATH_PI * doy / 365.25
        ca, sa = math.cos(a), math.sin(a)
        for c, k in zip(seasonal, SEASONAL_TARGETS):
            t[k] = t[k] + (c[0] + c[1] * ca + c[2] * sa) / 60.0
        if imsak_minutes == 0.0:
            t[IMSAK] = t[FAJR]

    for i, k in enumerate(TUNE_ORDER):
        adj = tune[i] if (tune is not None and i < len(tune)) else 0
        adj += offsets[i]
        t[k] = t[k] + float(adj) / 60.0
    return t


def compute(year: int, month: int, day: int, lat: float, lng: float, tz_hours: float,
            method_index: int, tune=None, asr_factor: int = 1,
            high_lat: int = HL_ANGLE) -> list[int]:
    """Minutes after local midnight, indexed IMSAK..MIDNIGHT (see module docstring)."""
    hours = compute_hours(year, month, day, lat, lng, tz_hours, method_index,
                          tune, asr_factor, high_lat)
    return [int(floor_d(h * 60.0 + 0.5)) for h in hours]
