"""Fit the Kosovo (BIK) method to takvim days fetched by fetch_takvim.py.

Usage: python3 tools/fit_takvim.py rows.json fit.json   (needs numpy)
Models each time as: astronomical time (twilight angle searched on a grid)
+ c0 + c1*cos(a) + c2*sin(a) [+ 2nd harmonic], a = 2*pi*dayOfYear/365.25,
and reports in-sample and leave-one-out errors. The k=3 coefficients go into
SEASONAL_KOSOVO in source/PrayerCalc.mc and tools/praytimes_ref.py.
"""
import json, sys, math
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from datetime import date, datetime
from zoneinfo import ZoneInfo
import praytimes_ref as A
rows = json.load(open(sys.argv[1]))
tz = ZoneInfo("Europe/Belgrade")
LAT, LNG = 42.6629, 21.1655
mins = lambda s: int(s[:2]) * 60 + int(s[3:])
days = []
for r in rows:
    d = date.fromisoformat(r["date"])
    off = datetime(d.year, d.month, d.day, 12, tzinfo=tz).utcoffset().total_seconds() / 3600
    days.append((d, off, r))

def base(d, off, which, p):
    jd = A.days_from_j2000(d.year, d.month, d.day) - LNG / 360
    shift = off - LNG / 15
    h = {"dhuhr": lambda: A.mid_day(jd, 12),
         "sunrise": lambda: A.angle_time(jd, LAT, A.RISESET, 6, True),
         "maghrib": lambda: A.angle_time(jd, LAT, A.RISESET, 18, False),
         "imsak": lambda: A.angle_time(jd, LAT, p, 5, True),
         "isha": lambda: A.angle_time(jd, LAT, p, 18, False),
         "asr": lambda: A.asr_time(jd, LAT, p, 13)}[which]()
    return (h + shift) * 60

def design(d):
    a = 2 * math.pi * (d.timetuple().tm_yday - 1) / 365.25
    return [1, math.cos(a), math.sin(a), math.cos(2*a), math.sin(2*a)]

def evaluate(which, p, k):
    X = np.array([design(d)[:k] for d, o, r in days])
    y = np.array([mins(r[which]) - base(d, o, which, p) for d, o, r in days])
    coef, *_ = np.linalg.lstsq(X, y, rcond=None)
    ins = np.abs(X @ coef - y).max()
    loo = []
    for i in range(len(y)):
        m = np.ones(len(y), bool); m[i] = False
        c2, *_ = np.linalg.lstsq(X[m], y[m], rcond=None)
        loo.append(abs(X[i] @ c2 - y[i]))
    return ins, max(loo), float(np.mean(loo)), coef

grids = {"imsak": [x / 4 for x in range(56, 84)], "isha": [x / 4 for x in range(56, 80)],
         "asr": [1.0], "dhuhr": [None], "sunrise": [None], "maghrib": [None]}
result = {}
for which, grid in grids.items():
    for k in (1, 3, 5):
        best = min((evaluate(which, p, k) + (p,) for p in grid), key=lambda t: t[1])
        ins, loo, mean, coef, p = best
        print(f"{which:8} harmonics={k}: param={p}  in-sample max {ins:.2f}  LOO max {loo:.2f}  LOO mean {mean:.2f}  coef={np.round(coef,3).tolist()}")
        result.setdefault(which, {})[k] = {"param": p, "coef": [float(c) for c in coef], "loo_max": loo}
json.dump(result, open(sys.argv[2], "w"), indent=1)
