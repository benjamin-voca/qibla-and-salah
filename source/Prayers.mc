import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Shared between the app, the glance and the background reminder service.
(:background :glance)
module Prayers {
    const WARN_PROPS = ["warnFajr", "warnDhuhr", "warnAsr", "warnMaghrib", "warnIsha"];

    const DAY = 86400;

    // Simulator-only memory/background check: a scratch jungle that excludes
    // (:normalbg) instead of (:forcebg) makes the background service run at once.
    // Normal builds always exclude (:forcebg).
    (:forcebg) const FORCE_BG = true;
    (:normalbg) const FORCE_BG = false;
    const AUTO = -1;

    // Automatic method by region, one fixed-width row each:
    //   latMin, latMax, lngMin, lngMax (all x100), method, hanafiAsr.
    // First match wins, so small/specific regions come first. Users can always
    // override. (Text, not nested arrays, to keep the background service small.)
    const REGIONS =
        "4185,4327,1998,2180,6,0,,,,,,,,," +      // Kosovo -> BIK takvim
        "115,148,10360,10410,12,0,,,,,,,," +     // Singapore
        "2440,2620,5070,5170,11,0,,,,,,,," +     // Qatar
        "2570,2640,5030,5090,9,0,,,,,,,,," +      // Bahrain -> Gulf
        "2850,3010,4650,4850,10,0,,,,,,,," +     // Kuwait
        "2260,2610,5150,5640,15,0,,,,,,,," +     // UAE -> Dubai
        "1660,2640,5200,6000,9,0,,,,,,,,," +      // Oman -> Gulf
        "2920,3340,3490,3930,22,0,,,,,,,," +     // Jordan
        "1200,3220,3450,5570,5,0,,,,,,,,," +      // Saudi Arabia, Yemen -> Umm al-Qura
        "2500,3980,4400,6330,7,0,,,,,,,,," +      // Iran -> Tehran
        "3580,4220,2560,4490,0,0,,,,,,,,," +      // Turkey -> Diyanet
        "3950,4650,1350,2970,0,0,,,,,,,,," +      // Balkans -> Diyanet
        "3690,4220,-960,-620,21,0,,,,,,,," +     // Portugal
        "2760,3595,-1320,-100,20,0,,,,,,," +    // Morocco
        "3020,3760,750,1160,17,0,,,,,,,,," +      // Tunisia
        "1900,3710,-870,1200,18,0,,,,,,,," +     // Algeria
        "870,3730,930,4240,3,0,,,,,,,,,,," +        // Egypt, Sudan, Libya, Levant -> Egyptian
        "590,3850,6050,9740,4,1,,,,,,,,,," +       // South Asia -> Karachi, Hanafi Asr
        "3600,5550,4600,8740,14,1,,,,,,,," +     // Central Asia -> Russia, Hanafi Asr
        "4100,8200,2700,18000,14,0,,,,,,," +    // Russia
        "80,740,9960,11930,16,0,,,,,,,,,," +       // Malaysia, Brunei -> JAKIM
        "-1100,600,9500,14100,19,0,,,,,,," +    // Indonesia -> Kemenag
        "1200,8500,-17000,-5000,2,0,,,,,,";     // North America -> ISNA
    const REGION_COUNT = 23;
    const REGION_WIDTH = 32;   // every row is padded with ',' to this many characters
    const FALLBACK_METHOD = 1;                 // Muslim World League

    // ---- settings --------------------------------------------------------

    function prop(key as String, dflt) {
        try {
            var v = Properties.getValue(key);
            return v == null ? dflt : v;
        } catch (e) {
            return dflt;
        }
    }

    function toD(v, dflt as Double) as Double {
        if (v instanceof Double) { return v; }
        if (v instanceof Float || v instanceof Number || v instanceof Long) { return v.toDouble(); }
        if (v instanceof String) { var d = v.toDouble(); return d == null ? dflt : d; }
        return dflt;
    }

    // "5,3,5,7,9,-1,0,8,-6" -> [5,3,5,7,9,-1,0,8,-6]
    function parseTune(s as String) as Array<Number> {
        var out = [] as Array<Number>;
        var rest = s;
        while (rest.length() > 0 && out.size() < 9) {
            var i = rest.find(",");
            var part = (i == null) ? rest : rest.substring(0, i);
            var n = (part as String).toNumber();
            out.add(n == null ? 0 : n);
            rest = (i == null) ? "" : rest.substring(i + 1, rest.length()) as String;
        }
        while (out.size() < 9) { out.add(0); }
        return out;
    }

    const EN_NAMES = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

    // True inside the background service. Before API 3.1 the background process
    // cannot touch resources (Rez) at all, so it must use the English fallbacks.
    var inBackground as Boolean = false;

    function noResources() as Boolean {
        return inBackground && !(Application has :loadResource);
    }

    // Load a string resource. Application.loadResource exists from API 3.1 (and
    // works in the background); older watches only have WatchUi.loadResource,
    // which the background process cannot use, so callers pass an English fallback.
    (:typecheck(false))
    function res(id, fallback as String) as String {
        if (Application has :loadResource) { return Application.loadResource(id) as String; }
        try {
            return WatchUi.loadResource(id) as String;
        } catch (e) {
            return fallback;
        }
    }

    // Localised prayer name (0 = Fajr .. 4 = Isha).
    function name(i as Number) as String {
        if (noResources()) { return EN_NAMES[i]; }
        var ids = [Rez.Strings.Fajr, Rez.Strings.Dhuhr, Rez.Strings.Asr, Rez.Strings.Maghrib, Rez.Strings.Isha];
        return res(ids[i], EN_NAMES[i]);
    }

    // Storage write that tolerates background processes on watches older than
    // API 3.2 (which may only read storage there).
    function store(key as String, value) as Boolean {
        try {
            Storage.setValue(key, value);
            return true;
        } catch (e) {
            return false;
        }
    }

    // The location in use, or null if none is known yet.
    function location() as Array<Double>? {
        if (prop("useGps", true) as Boolean) {
            var saved = Storage.getValue("loc");
            if (saved instanceof Array && saved.size() == 2) {
                return [toD(saved[0], 0.0d), toD(saved[1], 0.0d)];
            }
        }
        var lat = toD(prop("latitude", 0.0d), 0.0d);
        var lng = toD(prop("longitude", 0.0d), 0.0d);
        if (lat == 0.0d && lng == 0.0d) { return null; }
        return [lat, lng];
    }

    function hasLocation() as Boolean {
        return location() != null;
    }


    // [.., .., .., .., method, hanafiAsr] of the first region containing the point, or null.
    function regionFor(lat as Double, lng as Double) as Array<Number>? {
        var la = (lat * 100).toNumber();
        var lo = (lng * 100).toNumber();
        for (var i = 0; i < REGION_COUNT; i++) {
            var r = PrayerCalc.ints(PrayerCalc.row(REGIONS, i, REGION_WIDTH), 6);
            if (la >= r[0] && la <= r[1] && lo >= r[2] && lo <= r[3]) { return r; }
        }
        return null;
    }

    // Method actually used (resolves "Auto" from the location).
    function method() as Number {
        var m = prop("method", AUTO) as Number;
        if (m >= 0 && m < PrayerCalc.METHOD_COUNT) { return m; }
        var loc = location();
        if (loc == null) { return FALLBACK_METHOD; }
        var r = regionFor(loc[0], loc[1]);
        return r == null ? FALLBACK_METHOD : r[4];
    }

    // Asr shadow factor: setting 0 = auto (Hanafi in South/Central Asia), 1 standard, 2 Hanafi.
    function asrFactor() as Number {
        var a = prop("asrSchool", 0) as Number;
        if (a == 1 || a == 2) { return a; }
        if ((prop("method", AUTO) as Number) != AUTO) { return 1; }
        var loc = location();
        if (loc == null) { return 1; }
        var r = regionFor(loc[0], loc[1]);
        return (r != null && r[5] == 1) ? 2 : 1;
    }

    // High-latitude rule: setting 0 = auto (angle-based), 1 middle of night, 2 one-seventh, 3 angle-based.
    function highLatRule() as Number {
        var h = prop("highLat", 0) as Number;
        if (h == 1) { return PrayerCalc.HL_MIDDLE; }
        if (h == 2) { return PrayerCalc.HL_SEVENTH; }
        return PrayerCalc.HL_ANGLE;
    }

    function warnMinutes(i as Number) as Number {
        var v = prop(WARN_PROPS[i], 20);
        return (v instanceof Number) ? v : 20;
    }

    // ---- times -----------------------------------------------------------

    var cacheKeys as Array = [];
    var cacheVals as Array = [];

    function invalidate() as Void {
        cacheKeys = [];
        cacheVals = [];
    }

    // Raw minutes-after-midnight for the local day starting at `midnight`.
    function rawTimes(midnight as Moment) as Array<Number> {
        var key = midnight.value();
        var hit = cacheKeys.indexOf(key);
        if (hit >= 0) { return cacheVals[hit] as Array<Number>; }

        var info = Gregorian.info(midnight.add(new Time.Duration(12 * 3600)), Time.FORMAT_SHORT);
        var tz = System.getClockTime().timeZoneOffset.toDouble() / 3600.0d;
        var loc = location();
        if (loc == null) { loc = [21.4225d, 39.8262d]; } // never shown: UI asks for a location first
        var tune = parseTune(prop("tune", "") as String);
        var t = PrayerCalc.compute(info.year as Number, info.month as Number, info.day as Number,
                                   loc[0], loc[1], tz, method(), tune, [asrFactor(), highLatRule()]);
        if (cacheKeys.size() >= 4) { cacheKeys = cacheKeys.slice(1, null); cacheVals = cacheVals.slice(1, null); }
        cacheKeys.add(key);
        cacheVals.add(t);
        return t;
    }

    function at(midnight as Moment, minutes as Number) as Moment {
        return midnight.add(new Time.Duration(minutes * 60));
    }

    // Prayer windows for a local day as epoch seconds:
    // [fajrStart, fajrEnd, dhuhrStart, dhuhrEnd, ..., ishaStart, ishaEnd].
    // (Plain Numbers, no Moment objects: the background service on older watches
    // has very little memory.)
    function daySecs(midnight as Number) as Array<Number> {
        var t = rawTimes(new Time.Moment(midnight));
        var ishaEnd = midnight + t[PrayerCalc.MIDNIGHT] * 60;
        // Isha until Fajr if chosen, or when Isha starts at/after Islamic midnight
        // (high-latitude summers), so the window is never empty.
        if ((prop("ishaEnd", 0) as Number) == 1 || t[PrayerCalc.MIDNIGHT] - t[PrayerCalc.ISHA] < 20) {
            ishaEnd = midnight + DAY + rawTimes(new Time.Moment(midnight + DAY))[PrayerCalc.FAJR] * 60;
        }
        return [
            midnight + t[PrayerCalc.FAJR] * 60,    midnight + t[PrayerCalc.SUNRISE] * 60,
            midnight + t[PrayerCalc.DHUHR] * 60,   midnight + t[PrayerCalc.ASR] * 60,
            midnight + t[PrayerCalc.ASR] * 60,     midnight + t[PrayerCalc.MAGHRIB] * 60,
            midnight + t[PrayerCalc.MAGHRIB] * 60, midnight + t[PrayerCalc.ISHA] * 60,
            midnight + t[PrayerCalc.ISHA] * 60,    ishaEnd
        ];
    }

    // Prayer windows for a local day: Array of [startMoment, endMoment] for the 5 prayers.
    function windows(midnight as Moment) as Array<Array<Moment>> {
        var s = daySecs(midnight.value());
        var out = [] as Array<Array<Moment>>;
        for (var i = 0; i < 5; i++) {
            out.add([new Time.Moment(s[2 * i]), new Time.Moment(s[2 * i + 1])]);
        }
        return out;
    }

    // ---- done tracking ---------------------------------------------------

    // Key of "prayer i on the local day starting at `midnight`" in the "done"
    // dictionary: dayNumber * 10 + i (a Number, cheap to build in the background).
    function dayKey(midnight as Number, i as Number) as Number {
        return (midnight + DAY / 2) / DAY * 10 + i;
    }

    function doneKey(dayMidnight as Moment, i as Number) as Number {
        return dayKey(dayMidnight.value(), i);
    }

    function isDoneKey(key as Number) as Boolean {
        var d = Storage.getValue("done");
        return (d instanceof Dictionary) && d.hasKey(key);
    }

    // ---- reminder events -------------------------------------------------

    // Event kinds.
    const EV_START = 0;
    const EV_WARN = 1;
    const EV_SNOOZE = 2;

    const SNOOZE_MIN = 5;

    // All reminder events with from < time <= to (epoch seconds):
    // Array of [epochSeconds, kind, prayerIndex, doneKey, minutes].
    function events(from as Number, to as Number) as Array<Array<Number>> {
        var out = [] as Array<Array<Number>>;
        var atStart = prop("notifyAtStart", true) as Boolean;
        var done = Storage.getValue("done");
        if (!(done instanceof Dictionary)) { done = {}; }
        var today = Time.today().value();
        for (var d = -1; d <= 1; d++) {
            var day = today + d * DAY;
            // A day's windows run from its Fajr to (at most) the next day's Fajr:
            // skip days that can't overlap [from, to].
            if (day > to || day + 2 * DAY < from) { continue; }
            var w = daySecs(day);
            for (var i = 0; i < 5; i++) {
                var key = dayKey(day, i);
                if (done.hasKey(key)) { continue; }
                var start = w[2 * i];
                var end = w[2 * i + 1];
                if (atStart && start > from && start <= to) {
                    out.add([start, EV_START, i, key, (end - start) / 60]);
                }
                var mins = warnMinutes(i);
                var warn = end - mins * 60;
                if (mins > 0 && warn > from && warn <= to) {
                    out.add([warn, EV_WARN, i, key, mins]);
                }
            }
        }
        // A pending "Not yet" snooze: [epochSeconds, prayerIndex, doneKey, endEpochSeconds].
        var sn = Storage.getValue("snooze");
        if (sn instanceof Array && sn.size() == 4) {
            var at = sn[0] as Number;
            var left = ((sn[3] as Number) - at) / 60;
            if (!done.hasKey(sn[2]) && left > 0 && at > from && at <= to) {
                out.add([at, EV_SNOOZE, sn[1] as Number, sn[2] as Number, left]);
            }
        }
        return out;
    }

    // ---- notification actions (only on watches with the Notifications API) --

    // Notifications.NotificationMessage callback (type 2 = action selected).
    (:notif)
    function handleNotification(msg) as Void {
        if (msg != null && msg.type == 2) {
            handleAction(msg.action, msg.data);
        }
    }

    // Handle a tap on a notification action ("done" / "snooze").
    // Works in both the foreground app and the background service.
    (:notif)
    function handleAction(action, data) as Void {
        if (action == null || !(data instanceof Array) || data.size() != 3) { return; }
        var key = data[0] as Number;
        if (action.equals("done")) {
            var d = Storage.getValue("done");
            if (!(d instanceof Dictionary)) { d = {}; }
            d.put(key, true);
            store("done", d);
            Storage.deleteValue("snooze");
        } else if (action.equals("snooze")) {
            var now = Time.now().value();
            var end = data[2] as Number;
            var at = now + SNOOZE_MIN * 60;
            if (at < end) {
                store("snooze", [at, data[1], key, end]);
            }
        }
        schedule();
    }

    // Earliest reminder strictly after `after` (epoch seconds), or null.
    // Looks one day ahead first, then two (keeps the background light).
    function nextEvent(after as Number) as Number? {
        for (var span = 1; span <= 2; span++) {
            var evs = events(after, after + span * DAY);
            var best = null;
            for (var i = 0; i < evs.size(); i++) {
                var t = evs[i][0];
                if (best == null || t < best) { best = t; }
            }
            if (best != null) { return best; }
        }
        return null;
    }

    // Register the single temporal event for the next reminder.
    function schedule() as Void {
        var now = Time.now().value();
        var last = Background.getLastTemporalEventTime();
        // Respect the 5-minute minimum between temporal events.
        var earliest = last == null ? now : last.value() + 5 * 60;
        if (FORCE_BG) {
            Background.registerForTemporalEvent(new Time.Moment(earliest > now ? earliest : now));
            return;
        }
        if (!hasLocation()) { Background.deleteTemporalEvent(); return; }
        var handled = Storage.getValue("handled");
        var after = (handled instanceof Number && handled > now) ? handled : now;
        var next = nextEvent(after);
        if (next == null) { Background.deleteTemporalEvent(); return; }
        Background.registerForTemporalEvent(new Time.Moment(next > earliest ? next : earliest));
    }
}
