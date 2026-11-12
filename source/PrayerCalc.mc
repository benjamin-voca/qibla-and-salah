import Toybox.Lang;
import Toybox.Math;

// On-device prayer time calculation (praytimes.org algorithm, as used by
// api.aladhan.com). Everything is done in Doubles: 32-bit Floats are not
// precise enough for astronomical day counts.
//
// Result indices (minutes after local midnight of the given date; MIDNIGHT
// can exceed 1440 when Islamic midnight falls after 00:00).
(:background :glance)
module PrayerCalc {
    enum {
        IMSAK, FAJR, SUNRISE, DHUHR, ASR, SUNSET, MAGHRIB, ISHA, MIDNIGHT, COUNT
    }

    // Order of the aladhan `tune=` list.
    const TUNE_ORDER = [IMSAK, FAJR, SUNRISE, DHUHR, ASR, MAGHRIB, SUNSET, ISHA, MIDNIGHT];

    // Seasonal corrections in minutes: c0 + c1*cos(a) + c2*sin(a), a = 2*pi*dayOfYear/365.25,
    // for [Fajr(=Imsak), Sunrise, Dhuhr, Asr, Maghrib, Isha]. Fitted against 32 days of the
    // Islamic Community of Kosovo takvim (2023-2026; see tools/fit_takvim.py): typical error
    // under 1 minute, worst case ~2-3 minutes.
    const SEASONAL_KOSOVO = [
        [-1.855, 1.166, 1.189],
        [-6.179, 2.206, 0.932],
        [4.015, 1.134, -0.472],
        [6.268, 3.009, -2.567],
        [8.132, 0.363, -0.706],
        [21.308, -2.125, -0.497]
    ];
    const SEASONAL_TARGETS = [FAJR, SUNRISE, DHUHR, ASR, MAGHRIB, ISHA];

    // Method table, one fixed-width row per method (kept as text, not
    // nested arrays: building arrays at load time costs several KB, too much
    // for the 32 KB background service on older watches). Fields per row:
    //   fajr angle x100, isha x100 (angle, or minutes after Maghrib), isha-is-minutes,
    //   maghrib x100 (minutes after sunset, or angle), maghrib-is-angle,
    //   imsak minutes before Fajr (0 = Imsak is Fajr), Jafari midnight (sunset..Fajr),
    //   Isha minutes after Maghrib in Ramadan (Umm al-Qura: 120) or 0,
    //   seasonal correction set (1 = Kosovo), then built-in offsets in TUNE_ORDER
    //   (trailing zeros omitted).
    // Indices 0-6 must stay stable: they are stored in users' settings.
    // Parameters/offsets mirror api.aladhan.com (see tools/gen_golden_methods.py).
    const METHOD_DATA =
        /*  0 Diyanet, Turkey        */ "1800,1700,0,0,0,10,0,0,0,0,0,-7,5,4,7,7,,,,,,,,," +
        /*  1 Muslim World League    */ "1800,1700,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /*  2 ISNA (North America)   */ "1500,1500,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /*  3 Egyptian Authority     */ "1950,1750,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /*  4 Karachi                */ "1800,1800,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /*  5 Umm al-Qura, Makkah    */ "1850,9000,1,0,0,10,0,120,0,,,,,,,,,,,,,,,,,,,,,," +
        /*  6 Kosovo (BIK takvim)    */ "1850,1525,0,0,0,0,0,0,1,,,,,,,,,,,,,,,,,,,,,,,,," +
        /*  7 Tehran (Geophysics)    */ "1770,1400,0,450,1,10,1,0,0,,,,,,,,,,,,,,,,,,,,,," +
        /*  8 Shia Ithna-Ashari, Qum */ "1600,1400,0,400,1,10,1,0,0,,,,,,,,,,,,,,,,,,,,,," +
        /*  9 Gulf Region            */ "1950,9000,1,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 10 Kuwait                 */ "1800,1750,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 11 Qatar                  */ "1800,9000,1,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 12 Singapore (MUIS)       */ "2000,1800,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 13 France (UOIF)          */ "1200,1200,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 14 Russia                 */ "1600,1500,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 15 Dubai                  */ "1820,1820,0,0,0,10,0,0,0,0,0,0,3,0,3,3,,,,,,,,,," +
        /* 16 Malaysia (JAKIM)       */ "2000,1800,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 17 Tunisia                */ "1800,1800,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 18 Algeria                */ "1800,1700,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 19 Indonesia (Kemenag)    */ "2000,1800,0,0,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,,," +
        /* 20 Morocco                */ "1900,1700,0,0,0,10,0,0,0,0,0,0,5,0,5,,,,,,,,,,,," +
        /* 21 Portugal (Lisbon)      */ "1800,7700,1,300,0,10,0,0,0,0,0,0,5,,,,,,,,,,,,,," +
        /* 22 Jordan                 */ "1800,1800,0,500,0,10,0,0,0,,,,,,,,,,,,,,,,,,,,,,";
    const METHOD_COUNT = 23;
    const ROW_FIELDS = 18;
    const METHOD_WIDTH = 48;   // every row is padded with ',' to this many characters

    // Parse "a,b,c" into Numbers, padded with zeros to `n` fields.
    function ints(s as String, n as Number) as Array<Number> {
        var out = [] as Array<Number>;
        while (s.length() > 0) {
            var i = s.find(",");
            var part = (i == null) ? s : s.substring(0, i) as String;
            var v = part.toNumber();
            out.add(v == null ? 0 : v);
            s = (i == null) ? "" : s.substring(i + 1, s.length()) as String;
        }
        while (out.size() < n) { out.add(0); }
        return out;
    }

    // Row `index` of a table of fixed-width rows (no copying of the whole table).
    function row(table as String, index as Number, width as Number) as String {
        return table.substring(index * width, (index + 1) * width) as String;
    }

    const KOSOVO = 6;


    const RISESET = 0.833d;
    // Islamic Fiqh Council (Muslim World League): beyond 66° prayer times are
    // estimated from the times at latitude 45° on the same meridian.
    const MAX_LAT = 66.0d;
    const POLAR_LAT = 45.0d;

    function dsin(d as Double) as Double { return Math.sin(Math.toRadians(d)) as Double; }
    function dcos(d as Double) as Double { return Math.cos(Math.toRadians(d)) as Double; }
    function dtan(d as Double) as Double { return Math.tan(Math.toRadians(d)) as Double; }
    function dasin(x as Double) as Double { return Math.toDegrees(Math.asin(x)) as Double; }
    function dacos(x as Double) as Double {
        if (x > 1.0d) { x = 1.0d; } else if (x < -1.0d) { x = -1.0d; }
        return Math.toDegrees(Math.acos(x)) as Double;
    }
    function datan2(y as Double, x as Double) as Double { return Math.toDegrees(Math.atan2(y, x)) as Double; }

    function floorD(x as Double) as Double {
        var t = x.toLong().toDouble();
        return (t > x) ? t - 1.0d : t;
    }

    function fix(a as Double, b as Double) as Double {
        a = a - b * floorD(a / b);
        return (a < 0.0d) ? a + b : a;
    }

    // Days from J2000.0 to 0h UT of the given Gregorian date, i.e. JD - 2451545.
    function daysFromJ2000(year as Number, month as Number, day as Number) as Double {
        if (month <= 2) { year -= 1; month += 12; }
        var a = year / 100;
        var b = 2 - a + a / 4;
        var jdInt = (1461 * (year + 4716)) / 4 + (306001 * (month + 1)) / 10000 + day + b;
        // JD = jdInt - 1524.5
        return (jdInt - 1524 - 2451545).toDouble() - 0.5d;
    }

    // Returns [declination, equationOfTime(hours)] for day count d.
    function sunPosition(d as Double) as Array<Double> {
        var g = fix(357.529d + 0.98560028d * d, 360.0d);
        var q = fix(280.459d + 0.98564736d * d, 360.0d);
        var l = fix(q + 1.915d * dsin(g) + 0.020d * dsin(2.0d * g), 360.0d);
        var e = 23.439d - 0.00000036d * d;
        var ra = fix(datan2(dcos(e) * dsin(l), dcos(l)) / 15.0d, 24.0d);
        return [dasin(dsin(e) * dsin(l)), q / 15.0d - ra];
    }

    // High-latitude rules for when Fajr/Isha twilight never ends (or is very late).
    enum { HL_MIDDLE, HL_SEVENTH, HL_ANGLE }

    // Compute times for a date.
    //   tzHours  : UTC offset of that date in hours (e.g. 1.0 for CET)
    //   method   : row of METHOD_DATA
    //   tune     : Array of up to 9 Numbers in aladhan TUNE_ORDER, added to the method's own offsets
    //   opts     : [asrFactor (1 standard, 2 Hanafi), highLat (HL_MIDDLE, HL_SEVENTH or HL_ANGLE)]
    //              (one argument: older watches allow at most 9 parameters)
    // Returns Array<Number> of minutes after local midnight, indexed by the enum.
    function compute(year as Number, month as Number, day as Number,
                     lat as Double, lng as Double, tzHours as Double,
                     method as Number, tune as Array<Number>, opts as Array<Number>) as Array<Number> {
        var asrFactor = opts[0];
        var highLat = opts[1];
        var m = ints(row(METHOD_DATA, method, METHOD_WIDTH), ROW_FIELDS);
        var fajrAngle = m[0] / 100.0d;
        var ishaParam = m[1] / 100.0d;
        var ishaMinutes = m[2] == 1;
        var maghribParam = m[3] / 100.0d;
        var maghribAngle = m[4] == 1;
        var imsakMinutes = m[5].toDouble();
        var jafari = m[6] == 1;
        var ramadanIsha = m[7];
        var seasonal = m[8] == 1 ? SEASONAL_KOSOVO : null;
        var offsets = m.slice(9, 18);
        if (ramadanIsha > 0 && isRamadan(year, month, day)) { ishaParam = ramadanIsha.toDouble(); }

        // Beyond 66° (polar day/night) use the times of latitude 45° on the same
        // meridian (Islamic Fiqh Council resolution); between 48° and 66° Fajr/Isha
        // are handled by the high-latitude rule (adjustHL).
        var jd = daysFromJ2000(year, month, day) - lng / 360.0d;
        // The same applies just below 66° when the Sun doesn't rise or set that day
        // (refraction moves the polar day/night edge to ~65.7°).
        if (lat.abs() > MAX_LAT || noSunriseOrSunset(jd, lat)) {
            lat = lat < 0 ? -POLAR_LAT : POLAR_LAT;
        }

        // Initial guesses in hours (praytimes: one refinement pass).
        var fajr    = angleTime(jd, lat, fajrAngle, 5.0d, true);
        var sunrise = angleTime(jd, lat, RISESET, 6.0d, true);
        var dhuhr   = midDay(jd, 12.0d);
        var asr     = asrTime(jd, lat, asrFactor.toDouble(), 13.0d);
        var sunset  = angleTime(jd, lat, RISESET, 18.0d, false);
        var maghrib = maghribAngle ? angleTime(jd, lat, maghribParam, 18.0d, false) : sunset;
        var isha    = ishaMinutes ? 18.0d : angleTime(jd, lat, ishaParam, 18.0d, false);

        var shift = tzHours - lng / 15.0d;
        fajr += shift; sunrise += shift; dhuhr += shift; asr += shift;
        sunset += shift; maghrib += shift; isha += shift;

        // High-latitude safeguard (praytimes.org adjustHighLats).
        var night = fix(sunrise - sunset, 24.0d);
        fajr = adjustHL(fajr, sunrise, fajrAngle, night, true, highLat);
        if (maghribAngle) { maghrib = adjustHL(maghrib, sunset, maghribParam, night, false, highLat); }
        else { maghrib = sunset + maghribParam / 60.0d; }
        if (ishaMinutes) { isha = maghrib + ishaParam / 60.0d; }
        else { isha = adjustHL(isha, sunset, ishaParam, night, false, highLat); }

        var imsak = fajr - imsakMinutes / 60.0d;
        var midnight = jafari ? sunset + fix(fajr - sunset, 24.0d) / 2.0d
                              : sunset + night / 2.0d;

        var t = new [COUNT] as Array<Double>;
        t[IMSAK] = imsak; t[FAJR] = fajr; t[SUNRISE] = sunrise; t[DHUHR] = dhuhr; t[ASR] = asr;
        t[SUNSET] = sunset; t[MAGHRIB] = maghrib; t[ISHA] = isha; t[MIDNIGHT] = midnight;

        if (seasonal != null) {
            var doy = daysFromJ2000(year, month, day) - daysFromJ2000(year, 1, 1);
            var a = 2.0d * Math.PI * doy / 365.25d;
            var ca = Math.cos(a);
            var sa = Math.sin(a);
            for (var i = 0; i < SEASONAL_TARGETS.size(); i++) {
                var c = seasonal[i] as Array<Float>;
                var k = SEASONAL_TARGETS[i] as Number;
                t[k] = t[k] + (c[0].toDouble() + c[1].toDouble() * ca + c[2].toDouble() * sa) / 60.0d;
            }
            if (imsakMinutes == 0.0d) { t[IMSAK] = t[FAJR]; }
        }

        // Method offsets, plus the user's own fine-tune minutes on top.
        for (var i = 0; i < TUNE_ORDER.size(); i++) {
            var k = TUNE_ORDER[i] as Number;
            var adj = (tune != null && i < tune.size()) ? tune[i] : 0;
            adj += offsets[i];
            t[k] = t[k] + adj.toDouble() / 60.0d;
        }

        var out = new [COUNT] as Array<Number>;
        for (var i = 0; i < COUNT; i++) {
            out[i] = floorD(t[i] * 60.0d + 0.5d).toNumber();
        }
        return out;
    }

    // Whether the date falls in Ramadan on the Umm al-Qura calendar (inside the table range).
    function isRamadan(year as Number, month as Number, day as Number) as Boolean {
        // Days since 1970-01-01: J2000 is 2000-01-01 12:00, which is day 10957.5.
        var n = (daysFromJ2000(year, month, day) + 0.5d).toNumber() + 10957;
        var r = RamadanTable.DAYS;
        for (var i = 0; i + 1 < r.size(); i += 2) {
            if (n >= r[i] && n < r[i + 1]) { return true; }
        }
        return false;
    }

    // Clamp a twilight time so it is no further than a portion of the night
    // from `base` (sunrise for Fajr, sunset for Maghrib/Isha).
    function adjustHL(time as Double, base as Double, angle as Double, night as Double,
                      ccw as Boolean, rule as Number) as Double {
        var portion;
        if (rule == HL_ANGLE) { portion = angle / 60.0d * night; }
        else if (rule == HL_SEVENTH) { portion = night / 7.0d; }
        else { portion = night / 2.0d; }
        var diff = ccw ? fix(base - time, 24.0d) : fix(time - base, 24.0d);
        if (time != time || diff > portion) {
            return ccw ? base - portion : base + portion;
        }
        return time;
    }

    // True when the Sun stays above (or below) the horizon all day at this latitude.
    function noSunriseOrSunset(jd as Double, lat as Double) as Boolean {
        var decl = sunPosition(jd + 0.5d)[0];
        var x = (-dsin(RISESET) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat));
        return x > 1.0d || x < -1.0d;
    }

    function midDay(jd as Double, t as Double) as Double {
        var eqt = sunPosition(jd + t / 24.0d)[1];
        return fix(12.0d - eqt, 24.0d);
    }

    function angleTime(jd as Double, lat as Double, angle as Double, t as Double, ccw as Boolean) as Double {
        var decl = sunPosition(jd + t / 24.0d)[0];
        var noon = midDay(jd, t);
        var x = (-dsin(angle) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat));
        var h = dacos(x) / 15.0d;
        return ccw ? noon - h : noon + h;
    }

    function asrTime(jd as Double, lat as Double, factor as Double, t as Double) as Double {
        var decl = sunPosition(jd + t / 24.0d)[0];
        var diff = lat - decl;
        if (diff < 0.0d) { diff = -diff; }
        var acot = Math.toDegrees(Math.atan(1.0d / (factor + dtan(diff)))).toDouble();
        return angleTime(jd, lat, 0.0d - acot, t, false);
    }
}
