import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Property-based tests for the prayer-time calculator, the Qibla bearing and
// the Hijri table. Inputs come from a seeded generator, so every run is
// reproducible; a failure logs the exact inputs.
//
// These are (:test)-only: they are compiled into the unit-test build that runs
// in the simulator, never into the app that is installed on a watch.

(:test)
module Gen {
    var state as Number = 20261112;

    function seed(s as Number) as Void { state = s; }

    // 31-bit LCG (Numerical Recipes constants); Number overflow wraps, which is what we want.
    function next() as Number {
        state = state * 1664525 + 1013904223;
        return state & 0x7FFFFFFF;
    }

    function unit() as Double { return next().toDouble() / 2147483647.0d; }
    function range(a as Double, b as Double) as Double { return a + (b - a) * unit(); }
    function int(a as Number, b as Number) as Number { return a + next() % (b - a + 1); }
    function bool() as Boolean { return (next() & 1) == 1; }

    // A random case: [year, month, day, lat, lng, tz]
    // tz follows the longitude (like a real place), sometimes on a half hour.
    function place(latMin as Double, latMax as Double) as Array {
        var lng = range(-180.0d, 180.0d);
        var tz = Math.round(lng / 15.0d).toDouble();
        if (int(0, 9) == 0) { tz += 0.5d; }
        return [int(2000, 2099), int(1, 12), int(1, 28), range(latMin, latMax), lng, tz];
    }
}

(:test)
module P {
    const ALL_METHODS = 23;
    const ZERO_TUNE = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    function calc(c as Array, method as Number, asr as Number, hl as Number) as Array<Number> {
        return PrayerCalc.compute(c[0], c[1], c[2], c[3], c[4], c[5], method, ZERO_TUNE, [asr, hl]);
    }

    function describe(c as Array) as String {
        return Lang.format("$1$-$2$-$3$ lat=$4$ lng=$5$ tz=$6$",
            [c[0], c[1], c[2], (c[3] as Double).format("%.3f"), (c[4] as Double).format("%.3f"), c[5]]);
    }

    function check(logger as Test.Logger, ok as Boolean, what as String, c as Array, extra as String) as Boolean {
        if (!ok) { logger.error(what + " failed for " + describe(c) + " " + extra); }
        return ok;
    }

    function sunlen(t as Array<Number>) as Number {
        return t[PrayerCalc.SUNSET] - t[PrayerCalc.SUNRISE];
    }
}

// ---- prayer-time properties ---------------------------------------------------

// For any place up to 55° and any method/school/rule, the day is in order:
// Imsak <= Fajr < Sunrise < Dhuhr < Asr < Sunset <= Maghrib < Isha, Maghrib < Midnight.
(:test)
function propDayIsOrdered(logger as Test.Logger) as Boolean {
    Gen.seed(1);
    var ok = true;
    for (var n = 0; n < 150 && ok; n++) {
        var c = Gen.place(-55.0d, 55.0d);
        var m = Gen.int(0, P.ALL_METHODS - 1);
        var t = P.calc(c, m, Gen.int(1, 2), Gen.int(0, 2));
        var s = "method=" + m + " " + t.toString();
        ok = P.check(logger, t[PrayerCalc.IMSAK] <= t[PrayerCalc.FAJR], "imsak<=fajr", c, s)
            && P.check(logger, t[PrayerCalc.FAJR] < t[PrayerCalc.SUNRISE], "fajr<sunrise", c, s)
            && P.check(logger, t[PrayerCalc.SUNRISE] < t[PrayerCalc.DHUHR], "sunrise<dhuhr", c, s)
            && P.check(logger, t[PrayerCalc.DHUHR] < t[PrayerCalc.ASR], "dhuhr<asr", c, s)
            && P.check(logger, t[PrayerCalc.ASR] < t[PrayerCalc.SUNSET], "asr<sunset", c, s)
            && P.check(logger, t[PrayerCalc.SUNSET] <= t[PrayerCalc.MAGHRIB], "sunset<=maghrib", c, s)
            && P.check(logger, t[PrayerCalc.MAGHRIB] < t[PrayerCalc.ISHA], "maghrib<isha", c, s)
            && P.check(logger, t[PrayerCalc.MAGHRIB] < t[PrayerCalc.MIDNIGHT], "maghrib<midnight", c, s);
    }
    return ok;
}

// Solar noon: Dhuhr is clock noon corrected for longitude, give or take the
// equation of time (|EoT| <= ~16.5 min), and halfway between sunrise and sunset.
(:test)
function propDhuhrIsSolarNoon(logger as Test.Logger) as Boolean {
    Gen.seed(2);
    var ok = true;
    for (var n = 0; n < 150 && ok; n++) {
        var c = Gen.place(-60.0d, 60.0d);
        var t = P.calc(c, 1, 1, PrayerCalc.HL_ANGLE); // MWL: no built-in offsets
        var meanNoon = 720.0d + 60.0d * ((c[5] as Double) - (c[4] as Double) / 15.0d);
        var eot = t[PrayerCalc.DHUHR] - meanNoon;
        var mid = (t[PrayerCalc.SUNRISE] + t[PrayerCalc.SUNSET]) / 2.0d;
        ok = P.check(logger, eot.abs() <= 17.5d, "|dhuhr - mean noon| <= 17.5", c, "eot=" + eot)
            && P.check(logger, (t[PrayerCalc.DHUHR] - mid).abs() <= 2.0d, "dhuhr = mid(sunrise, sunset)", c,
                       "dhuhr=" + t[PrayerCalc.DHUHR] + " mid=" + mid);
    }
    return ok;
}

// Changing only the UTC offset by one hour moves every time by exactly 60 minutes.
(:test)
function propTimezoneShiftsEverything(logger as Test.Logger) as Boolean {
    Gen.seed(3);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-60.0d, 60.0d);
        var m = Gen.int(0, P.ALL_METHODS - 1);
        var a = P.calc(c, m, 1, PrayerCalc.HL_ANGLE);
        var c2 = [c[0], c[1], c[2], c[3], c[4], (c[5] as Double) + 1.0d];
        var b = P.calc(c2, m, 1, PrayerCalc.HL_ANGLE);
        for (var i = 0; i < PrayerCalc.COUNT && ok; i++) {
            ok = P.check(logger, (b[i] - a[i] - 60).abs() <= 1, "tz+1 => +60 min", c, "method=" + m + " idx=" + i);
        }
    }
    return ok;
}

// Moving 15° east together with the clock (+1 h) describes the same local solar
// day, so times barely change (only the tiny change in the Sun's position).
(:test)
function propLongitudeAndClockCancel(logger as Test.Logger) as Boolean {
    Gen.seed(4);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-50.0d, 50.0d);
        if ((c[4] as Double) > 160.0d) { continue; }
        var a = P.calc(c, 1, 1, PrayerCalc.HL_ANGLE);
        var c2 = [c[0], c[1], c[2], c[3], (c[4] as Double) + 15.0d, (c[5] as Double) + 1.0d];
        var b = P.calc(c2, 1, 1, PrayerCalc.HL_ANGLE);
        for (var i = 0; i < PrayerCalc.COUNT && ok; i++) {
            ok = P.check(logger, (b[i] - a[i]).abs() <= 1, "lng+15 & tz+1 ~ same", c, "idx=" + i + " " + a[i] + " vs " + b[i]);
        }
    }
    return ok;
}

// Fine-tune minutes are added exactly to their own time and nothing else.
(:test)
function propTuneIsAdditive(logger as Test.Logger) as Boolean {
    Gen.seed(5);
    // TUNE_ORDER position -> result index
    var order = PrayerCalc.TUNE_ORDER;
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-55.0d, 55.0d);
        var m = Gen.int(0, P.ALL_METHODS - 1);
        var tune = [];
        for (var i = 0; i < 9; i++) { tune.add(Gen.int(-30, 30)); }
        var base = P.calc(c, m, 1, PrayerCalc.HL_ANGLE);
        var tuned = PrayerCalc.compute(c[0], c[1], c[2], c[3], c[4], c[5], m, tune, [1, PrayerCalc.HL_ANGLE]);
        for (var i = 0; i < 9 && ok; i++) {
            var k = order[i];
            ok = P.check(logger, (tuned[k] - base[k] - tune[i]).abs() <= 1, "tune adds exactly", c,
                         "method=" + m + " idx=" + k + " tune=" + tune[i]);
        }
    }
    return ok;
}

// Hanafi Asr (shadow = 2x) is always later than standard Asr, and before sunset.
(:test)
function propHanafiAsrIsLater(logger as Test.Logger) as Boolean {
    Gen.seed(6);
    var ok = true;
    for (var n = 0; n < 150 && ok; n++) {
        var c = Gen.place(-50.0d, 50.0d);
        var m = Gen.int(0, P.ALL_METHODS - 1);
        var std = P.calc(c, m, 1, PrayerCalc.HL_ANGLE);
        var han = P.calc(c, m, 2, PrayerCalc.HL_ANGLE);
        ok = P.check(logger, han[PrayerCalc.ASR] > std[PrayerCalc.ASR], "hanafi asr > standard asr", c, "method=" + m)
            && P.check(logger, han[PrayerCalc.ASR] < han[PrayerCalc.SUNSET], "hanafi asr < sunset", c, "method=" + m);
    }
    return ok;
}

// Methods defined in fixed minutes keep them exactly (Umm al-Qura: 120 min in Ramadan);
// Imsak is 10 min before Fajr
// (or equal to Fajr for the Kosovo takvim).
(:test)
function propFixedMinuteRules(logger as Test.Logger) as Boolean {
    Gen.seed(7);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-55.0d, 55.0d);
        var uaq = P.calc(c, 5, 1, PrayerCalc.HL_ANGLE);
        var gulf = P.calc(c, 9, 1, PrayerCalc.HL_ANGLE);
        var qatar = P.calc(c, 11, 1, PrayerCalc.HL_ANGLE);
        var lisbon = P.calc(c, 21, 1, PrayerCalc.HL_ANGLE);
        var jordan = P.calc(c, 22, 1, PrayerCalc.HL_ANGLE);
        var kosovo = P.calc(c, PrayerCalc.KOSOVO, 1, PrayerCalc.HL_ANGLE);
        var mwl = P.calc(c, 1, 1, PrayerCalc.HL_ANGLE);
        var uaqIsha = PrayerCalc.isRamadan(c[0], c[1], c[2]) ? 120 : 90;
        ok = P.check(logger, (uaq[PrayerCalc.ISHA] - uaq[PrayerCalc.MAGHRIB] - uaqIsha).abs() <= 1, "UAQ isha = maghrib+90 (120 in Ramadan)", c, "")
            && P.check(logger, (gulf[PrayerCalc.ISHA] - gulf[PrayerCalc.MAGHRIB] - 90).abs() <= 1, "Gulf isha = maghrib+90", c, "")
            && P.check(logger, (qatar[PrayerCalc.ISHA] - qatar[PrayerCalc.MAGHRIB] - 90).abs() <= 1, "Qatar isha = maghrib+90", c, "")
            && P.check(logger, (lisbon[PrayerCalc.MAGHRIB] - lisbon[PrayerCalc.SUNSET] - 3).abs() <= 1, "Lisbon maghrib = sunset+3", c, "")
            && P.check(logger, (lisbon[PrayerCalc.ISHA] - lisbon[PrayerCalc.MAGHRIB] - 77).abs() <= 1, "Lisbon isha = maghrib+77", c, "")
            && P.check(logger, (jordan[PrayerCalc.MAGHRIB] - jordan[PrayerCalc.SUNSET] - 5).abs() <= 1, "Jordan maghrib = sunset+5", c, "")
            && P.check(logger, (mwl[PrayerCalc.FAJR] - mwl[PrayerCalc.IMSAK] - 10).abs() <= 1, "imsak = fajr-10", c, "")
            && P.check(logger, kosovo[PrayerCalc.IMSAK] == kosovo[PrayerCalc.FAJR], "kosovo imsak = fajr", c, "");
    }
    return ok;
}

// Standard midnight is halfway from sunset to sunrise; Jafari midnight is
// halfway from sunset to Fajr.
(:test)
function propMidnightRules(logger as Test.Logger) as Boolean {
    Gen.seed(8);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-55.0d, 55.0d);
        var std = P.calc(c, 1, 1, PrayerCalc.HL_ANGLE);
        var jaf = P.calc(c, 7, 1, PrayerCalc.HL_ANGLE);
        var stdMid = (std[PrayerCalc.SUNSET] + std[PrayerCalc.SUNRISE] + 1440) / 2.0d;
        var jafMid = (jaf[PrayerCalc.SUNSET] + jaf[PrayerCalc.FAJR] + 1440) / 2.0d;
        ok = P.check(logger, (std[PrayerCalc.MIDNIGHT] - stdMid).abs() <= 1.0d, "standard midnight", c, "")
            && P.check(logger, (jaf[PrayerCalc.MIDNIGHT] - jafMid).abs() <= 1.0d, "jafari midnight", c, "");
    }
    return ok;
}

// A deeper twilight angle means an earlier Fajr and a later Isha:
// Fajr: ISNA 15° >= MWL 18° >= Egypt 19.5° >= Singapore 20°; Isha: ISNA 15° <= MWL 17° <= Egypt 17.5° <= Karachi 18°.
(:test)
function propTwilightAngleIsMonotonic(logger as Test.Logger) as Boolean {
    Gen.seed(9);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var c = Gen.place(-45.0d, 45.0d);
        var isna = P.calc(c, 2, 1, PrayerCalc.HL_ANGLE);
        var mwl = P.calc(c, 1, 1, PrayerCalc.HL_ANGLE);
        var egypt = P.calc(c, 3, 1, PrayerCalc.HL_ANGLE);
        var sing = P.calc(c, 12, 1, PrayerCalc.HL_ANGLE);
        var kar = P.calc(c, 4, 1, PrayerCalc.HL_ANGLE);
        ok = P.check(logger, isna[PrayerCalc.FAJR] >= mwl[PrayerCalc.FAJR] && mwl[PrayerCalc.FAJR] >= egypt[PrayerCalc.FAJR]
                             && egypt[PrayerCalc.FAJR] >= sing[PrayerCalc.FAJR], "fajr monotonic in angle", c, "")
            && P.check(logger, isna[PrayerCalc.ISHA] <= mwl[PrayerCalc.ISHA] && mwl[PrayerCalc.ISHA] <= egypt[PrayerCalc.ISHA]
                             && egypt[PrayerCalc.ISHA] <= kar[PrayerCalc.ISHA], "isha monotonic in angle", c, "");
    }
    return ok;
}

// Day length: ~12 h at the equator all year and everywhere at the equinoxes
// (refraction adds a few minutes); in June it grows towards the north pole and
// shrinks towards the south, and the other way round in December.
(:test)
function propDayLength(logger as Test.Logger) as Boolean {
    Gen.seed(10);
    var ok = true;
    for (var n = 0; n < 60 && ok; n++) {
        var c = Gen.place(-0.5d, 0.5d);
        var len = P.sunlen(P.calc(c, 1, 1, PrayerCalc.HL_ANGLE));
        ok = P.check(logger, len >= 715 && len <= 745, "equator day ~12h", c, "len=" + len);
    }
    for (var n = 0; n < 60 && ok; n++) {
        var c = Gen.place(-60.0d, 60.0d);
        c[1] = Gen.bool() ? 3 : 9;
        c[2] = c[1] == 3 ? 20 : 22;
        var len = P.sunlen(P.calc(c, 1, 1, PrayerCalc.HL_ANGLE));
        ok = P.check(logger, len >= 705 && len <= 775, "equinox day ~12h", c, "len=" + len);
    }
    for (var n = 0; n < 60 && ok; n++) {
        var a = Gen.range(-60.0d, 59.0d);
        var b = Gen.range(a, 60.0d);
        var lng = Gen.range(-180.0d, 180.0d);
        var tz = Math.round(lng / 15.0d).toDouble();
        var y = Gen.int(2000, 2099);
        var junA = P.sunlen(PrayerCalc.compute(y, 6, 21, a, lng, tz, 1, P.ZERO_TUNE, [1, PrayerCalc.HL_ANGLE]));
        var junB = P.sunlen(PrayerCalc.compute(y, 6, 21, b, lng, tz, 1, P.ZERO_TUNE, [1, PrayerCalc.HL_ANGLE]));
        var decA = P.sunlen(PrayerCalc.compute(y, 12, 21, a, lng, tz, 1, P.ZERO_TUNE, [1, PrayerCalc.HL_ANGLE]));
        var decB = P.sunlen(PrayerCalc.compute(y, 12, 21, b, lng, tz, 1, P.ZERO_TUNE, [1, PrayerCalc.HL_ANGLE]));
        var c = [y, 6, 21, a, lng, tz];
        ok = P.check(logger, junA <= junB + 1, "June days longer further north", c, "b=" + b + " " + junA + " vs " + junB)
            && P.check(logger, decA + 1 >= decB, "December days shorter further north", c, "b=" + b + " " + decA + " vs " + decB);
    }
    return ok;
}

// Beyond 66° the calculation uses latitude 45° (Islamic Fiqh Council): it never
// breaks, stays ordered, and equals the 45° result.
(:test)
function propPolarClamp(logger as Test.Logger) as Boolean {
    Gen.seed(11);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var north = Gen.bool();
        var c = Gen.place(66.01d, 90.0d);
        if (!north) { c[3] = -(c[3] as Double); }
        var m = Gen.int(0, P.ALL_METHODS - 1);
        var t = P.calc(c, m, 1, Gen.int(0, 2));
        var c65 = [c[0], c[1], c[2], north ? 45.0d : -45.0d, c[4], c[5]];
        var hl = Gen.int(0, 2);
        var a = P.calc(c, m, 1, hl);
        var b = P.calc(c65, m, 1, hl);
        var inRange = true;
        for (var i = 0; i < PrayerCalc.COUNT; i++) { inRange = inRange && t[i] > -1440 && t[i] < 2 * 1440; }
        ok = P.check(logger, inRange, "times are finite", c, t.toString())
            && P.check(logger, t[PrayerCalc.FAJR] <= t[PrayerCalc.SUNRISE] && t[PrayerCalc.SUNRISE] <= t[PrayerCalc.DHUHR]
                             && t[PrayerCalc.DHUHR] <= t[PrayerCalc.SUNSET], "polar day still ordered", c, t.toString())
            && P.check(logger, a.toString().equals(b.toString()), "beyond 66° equals 45°", c, "method=" + m);
    }
    return ok;
}

// ---- Qibla properties -----------------------------------------------------------

(:test)
module Geo {
    const R = 6371.0d; // km

    function rad(d as Double) as Double { return Math.toRadians(d) as Double; }

    // Great-circle distance in km.
    function dist(lat1 as Double, lng1 as Double, lat2 as Double, lng2 as Double) as Double {
        var p1 = rad(lat1);
        var p2 = rad(lat2);
        var dp = p2 - p1;
        var dl = rad(lng2 - lng1);
        var a = Math.sin(dp / 2) * Math.sin(dp / 2) + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
        return (2.0d * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toDouble();
    }

    // Point reached after travelling `km` from (lat, lng) on initial bearing `deg`.
    function travel(lat as Double, lng as Double, deg as Double, km as Double) as Array<Double> {
        var p1 = rad(lat);
        var l1 = rad(lng);
        var b = rad(deg);
        var d = km / R;
        var p2 = Math.asin(Math.sin(p1) * Math.cos(d) + Math.cos(p1) * Math.sin(d) * Math.cos(b));
        var l2 = l1 + Math.atan2(Math.sin(b) * Math.sin(d) * Math.cos(p1), Math.cos(d) - Math.sin(p1) * Math.sin(p2));
        return [Math.toDegrees(p2).toDouble(), Math.toDegrees(l2).toDouble()];
    }
}

// The bearing is always a compass direction in [0, 360).
(:test)
function propQiblaRange(logger as Test.Logger) as Boolean {
    Gen.seed(21);
    var ok = true;
    for (var n = 0; n < 300 && ok; n++) {
        var lat = Gen.range(-89.0d, 89.0d);
        var lng = Gen.range(-180.0d, 180.0d);
        var b = Qibla.bearing(lat, lng);
        ok = P.check(logger, b >= 0.0 && b < 360.0, "0 <= qibla < 360", [0, 0, 0, lat, lng, 0], "b=" + b);
    }
    return ok;
}

// On the Kaaba's meridian the Qibla is due south (from the north) or due north (from the south).
(:test)
function propQiblaOnMeridian(logger as Test.Logger) as Boolean {
    Gen.seed(22);
    var ok = true;
    for (var n = 0; n < 100 && ok; n++) {
        var north = Gen.range(Qibla.KAABA_LAT + 0.5d, 85.0d);
        var south = Gen.range(-85.0d, Qibla.KAABA_LAT - 0.5d);
        var bn = Qibla.bearing(north, Qibla.KAABA_LNG);
        var bs = Qibla.bearing(south, Qibla.KAABA_LNG);
        var fromNorth = (bs < 180.0 ? bs : bs - 360.0);
        ok = P.check(logger, (bn - 180.0).abs() < 0.01, "due south from the north", [0, 0, 0, north, Qibla.KAABA_LNG, 0], "b=" + bn)
            && P.check(logger, fromNorth.abs() < 0.01, "due north from the south", [0, 0, 0, south, Qibla.KAABA_LNG, 0], "b=" + bs);
    }
    return ok;
}

// Walking 10 km in the Qibla direction brings you ~10 km closer to the Kaaba
// (the bearing is the start of the shortest path). Skips points very close to
// the Kaaba or its antipode, where the direction is ill-defined.
(:test)
function propQiblaPointsTowardsKaaba(logger as Test.Logger) as Boolean {
    Gen.seed(23);
    var ok = true;
    var tested = 0;
    for (var n = 0; n < 400 && ok && tested < 200; n++) {
        var lat = Gen.range(-80.0d, 80.0d);
        var lng = Gen.range(-180.0d, 180.0d);
        var d0 = Geo.dist(lat, lng, Qibla.KAABA_LAT, Qibla.KAABA_LNG);
        if (d0 < 300.0d || d0 > 19700.0d) { continue; }
        tested++;
        var p = Geo.travel(lat, lng, Qibla.bearing(lat, lng).toDouble(), 10.0d);
        var d1 = Geo.dist(p[0], p[1], Qibla.KAABA_LAT, Qibla.KAABA_LNG);
        ok = P.check(logger, d0 - d1 > 9.9d && d0 - d1 <= 10.01d, "10 km along the Qibla = 10 km closer",
                     [0, 0, 0, lat, lng, 0], "closer by " + (d0 - d1));
    }
    return ok;
}

// Published Qibla bearings for a few cities (to within 0.5°).
(:test)
function propQiblaKnownCities(logger as Test.Logger) as Boolean {
    var cases = [
        ["Prishtina", 42.6629d, 21.1655d, 137.85d],
        ["London", 51.5074d, -0.1278d, 119.0d],
        ["New York", 40.7128d, -74.0060d, 58.5d],
        ["Jakarta", -6.2088d, 106.8456d, 295.2d],
        ["Sydney", -33.8688d, 151.2093d, 277.5d],
        ["Cape Town", -33.9249d, 18.4241d, 23.3d]
    ];
    var ok = true;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var b = Qibla.bearing(c[1], c[2]);
        ok = P.check(logger, (b - c[3]).abs() < 0.5, "known qibla " + c[0], [0, 0, 0, c[1], c[2], 0],
                     "got " + b + " expected " + c[3]) && ok;
    }
    return ok;
}

// The 8-point compass label matches the bearing's sector.
(:test)
function propCompassPoint(logger as Test.Logger) as Boolean {
    Gen.seed(24);
    var names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]; // English resources in the test build
    var ok = true;
    for (var n = 0; n < 200 && ok; n++) {
        var k = Gen.int(0, 7);
        var deg = (k * 45.0d + Gen.range(-22.4d, 22.4d)).toFloat();
        if (deg < 0) { deg += 360.0; }
        var got = Qibla.compassPoint(deg);
        ok = P.check(logger, got.equals(names[k]), "compass point", [0, 0, 0, 0, 0, 0], "deg=" + deg + " got " + got);
    }
    return ok;
}

// ---- Hijri table properties -------------------------------------------------------

// Walking day by day through the whole table: each day advances the Hijri date
// by exactly one, months have 29 or 30 days, and months/years roll over in order.
(:test)
function propHijriDaysAdvance(logger as Test.Logger) as Boolean {
    var s = HijriTable.STARTS;
    var first = s[0];
    var last = s[s.size() - 1] + 28;
    var prev = Hijri.fromDay(first);
    var ok = P.check(logger, prev != null && prev[0] == 1, "table starts on day 1", [0, 0, 0, 0, 0, 0], "");
    var len = 1;
    for (var day = first + 1; day <= last && ok; day++) {
        var h = Hijri.fromDay(day);
        if (h == null) { ok = P.check(logger, false, "day inside table", [0, 0, 0, 0, 0, 0], "day=" + day); break; }
        if (h[0] == prev[0] + 1) {
            ok = P.check(logger, h[1] == prev[1] && h[2] == prev[2], "same month continues", [0, 0, 0, 0, 0, 0], "day=" + day);
            len++;
        } else {
            var nextMonth = (prev[1] + 1) % 12;
            var nextYear = prev[2] + (prev[1] == 11 ? 1 : 0);
            ok = P.check(logger, h[0] == 1 && h[1] == nextMonth && h[2] == nextYear, "new month starts at 1",
                         [0, 0, 0, 0, 0, 0], "day=" + day + " " + prev.toString() + " -> " + h.toString())
                && P.check(logger, len == 29 || len == 30, "month has 29 or 30 days", [0, 0, 0, 0, 0, 0],
                           "len=" + len + " at " + prev.toString());
            len = 1;
        }
        prev = h;
    }
    ok = ok && P.check(logger, Hijri.fromDay(first - 1) == null, "null before table", [0, 0, 0, 0, 0, 0], "");
    return ok;
}

// The automatic method follows the region table.
(:test)
function regionTableLookup(logger as Test.Logger) as Boolean {
    var cases = [[42.66d, 21.17d, 6], [41.01d, 28.98d, 0], [51.51d, -0.13d, -1], [40.71d, -74.0d, 2],
                 [21.42d, 39.83d, 5], [-6.21d, 106.85d, 19], [3.14d, 101.69d, 16], [24.86d, 67.0d, 4],
                 [35.69d, 51.39d, 7], [25.20d, 55.27d, 15], [30.04d, 31.24d, 3], [-33.87d, 151.21d, -1]];
    var ok = true;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var r = Prayers.regionFor(c[0], c[1]);
        var m = r == null ? -1 : r[4];
        if (m != c[2]) { logger.error("region for " + c[0] + "," + c[1] + ": got " + m + " expected " + c[2]); ok = false; }
    }
    return ok;
}
