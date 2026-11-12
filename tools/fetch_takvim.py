"""Slowly fetch archived takvimi-ks.com snapshots from the Wayback Machine; resumable.

Usage: python3 tools/fetch_takvim.py rows.json
The fetched times are only used to fit parameters (tools/fit_takvim.py); the
takvim itself is not redistributed with the app.
"""
import json, re, urllib.request, html, time, os, sys
OUT = sys.argv[1]
ts = ['20230429231834','20230502143725','20230529091715','20240305074750','20240316014653','20240421023612','20240514224716','20240529152017','20240619141244','20240713182246','20240725100417','20240805191700','20240822045538','20240915232221','20241015095857','20241109103516','20241209200938','20241226091937','20250126122604','20250215072511','20250320213916','20250425060428','20250523114319','20250616192047','20250709094850','20250810133001','20250907084526','20251010092425','20251111202728','20251213224714','20260208082148','20260308180655','20260419085008','20260516235654','20260618174503','20260711023701']
MONTHS = {"janar":1,"shkurt":2,"mars":3,"prill":4,"maj":5,"qershor":6,"korrik":7,"gusht":8,"shtator":9,"tetor":10,"nëntor":11,"nentor":11,"dhjetor":12}
labels = {"imsaku":"imsak","lindja e diellit":"sunrise","dreka":"dhuhr","ikindia":"asr","akshami":"maghrib","jacia":"isha"}
rows = json.load(open(OUT)) if os.path.exists(OUT) else []
done = {r.get("ts") for r in rows}
for t in ts:
    if t in done: continue
    for attempt in range(4):
        try:
            raw = urllib.request.urlopen(urllib.request.Request(f"https://web.archive.org/web/{t}id_/https://takvimi-ks.com/", headers={"User-Agent":"Mozilla/5.0 (research; low rate)"}), timeout=60).read().decode("utf-8","ignore")
            break
        except Exception as e:
            print(t, "retry", e, flush=True); time.sleep(180)
    else:
        continue
    lines = [l.strip() for l in html.unescape(re.sub(r"<[^>]+>", "\n", raw)).split("\n") if l.strip()]
    m = re.search(r"(\d{1,2}) (\w+) (20\d\d)", " ".join(lines[:200]))
    vals = {}
    for i,l in enumerate(lines):
        k = re.sub(r"\s+"," ",l.lower())
        if k in labels and i+1 < len(lines) and re.fullmatch(r"\d\d:\d\d", lines[i+1]):
            vals[labels[k]] = lines[i+1]
    if m and m.group(2).lower() in MONTHS and len(vals)==6:
        rows.append({"ts":t,"date":f"{m.group(3)}-{MONTHS[m.group(2).lower()]:02d}-{int(m.group(1)):02d}", **vals})
        print(rows[-1], flush=True)
        json.dump(rows, open(OUT,"w"), indent=1)
    else:
        print(t, "unparsed", vals, flush=True)
    time.sleep(30)
print("done", len(rows))
