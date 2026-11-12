import Toybox.Lang;
import Toybox.Test;

// Checks the on-device calculator against values from api.aladhan.com.
// Asr may differ by 1 minute (rounding) on some winter days.
(:test)
function prayerCalcMatchesAladhan(logger as Test.Logger) as Boolean {
    // aladhan's tune *replaces* Diyanet's built-in offsets; ours adds to them,
    // so this is the API's 5,3,5,7,9,-1,0,8,-6 minus Diyanet's own offsets.
    var tune = [5, 3, 12, 2, 5, -8, 0, 8, -6];
    var ok = true;
    var rows = Golden.ROWS;
    for (var r = 0; r < rows.size(); r++) {
        var row = rows[r] as Array;
        var got = PrayerCalc.compute(row[0], row[1], row[2], 42.6629d, 21.1655d,
                                     (row[3] as Number).toDouble(), 0, tune, [1, PrayerCalc.HL_MIDDLE]);
        var exp = row[4] as Array<Number>;
        for (var i = 0; i < exp.size(); i++) {
            var diff = (got[i] - exp[i]).abs();
            var allowed = (i == PrayerCalc.ASR) ? 1 : 0;
            if (diff > allowed) {
                logger.error(Lang.format("$1$-$2$-$3$ idx $4$: got $5$ expected $6$",
                    [row[0], row[1], row[2], i, got[i], exp[i]]));
                ok = false;
            }
        }
    }
    return ok;
}

(:test)
function tuneParsing(logger as Test.Logger) as Boolean {
    var t = Prayers.parseTune("5,3,5,7,9,-1,0,8,-6");
    Test.assertEqual(t.size(), 9);
    Test.assertEqual(t[5], -1);
    Test.assertEqual(Prayers.parseTune("").size(), 9);
    return true;
}

// The Kosovo (BIK) method must match the Python reference it was fitted with.
(:test)
function kosovoMatchesReference(logger as Test.Logger) as Boolean {
    var ok = true;
    var rows = GoldenKosovo.ROWS;
    for (var r = 0; r < rows.size(); r++) {
        var row = rows[r] as Array;
        var got = PrayerCalc.compute(row[0], row[1], row[2], 42.6629d, 21.1655d,
                                     (row[3] as Number).toDouble(), PrayerCalc.KOSOVO, [], [1, PrayerCalc.HL_MIDDLE]);
        var exp = row[4] as Array<Number>;
        for (var i = 0; i < exp.size(); i++) {
            if ((got[i] - exp[i]).abs() > 1) {
                logger.error(Lang.format("$1$-$2$-$3$ idx $4$: got $5$ expected $6$",
                    [row[0], row[1], row[2], i, got[i], exp[i]]));
                ok = false;
            }
        }
    }
    return ok;
}

// Isha must never get an empty window (high-latitude summer).
(:test)
function londonSummerIshaWindow(logger as Test.Logger) as Boolean {
    var t = PrayerCalc.compute(2026, 6, 21, 51.51d, -0.13d, 1.0d, 1, [], [1, PrayerCalc.HL_ANGLE]);
    logger.debug("London 21 Jun isha=" + t[PrayerCalc.ISHA] + " midnight=" + t[PrayerCalc.MIDNIGHT]);
    return t[PrayerCalc.ISHA] > t[PrayerCalc.MAGHRIB];
}

// Every method against api.aladhan.com at a city where it is used (angle-based high latitudes).
// Asr may differ by up to 2 minutes at high latitudes: checked against a precise
// NOAA-based solar calculation, our Asr is within 0.4 min while aladhan's is off
// by up to ~3 min (London, Kazan), so the extra minute is aladhan's.
(:test)
function allMethodsMatchAladhan(logger as Test.Logger) as Boolean {
    var bad = 0;
    var rows = GoldenMethods.ROWS;
    for (var r = 0; r < rows.size(); r++) {
        var row = rows[r] as Array;
        var got = PrayerCalc.compute(row[3], row[4], row[5], row[1], row[2], row[6],
                                     row[0], [], [1, PrayerCalc.HL_ANGLE]);
        var exp = row[7] as Array<Number>;
        for (var i = 0; i < exp.size(); i++) {
            var allowed = i == PrayerCalc.ASR ? 2 : 1;
            if ((got[i] - exp[i]).abs() > allowed) {
                if (bad < 25) {
                    logger.error(Lang.format("method $1$ $2$-$3$ idx $4$: got $5$ expected $6$",
                        [row[0], row[4], row[5], i, got[i], exp[i]]));
                }
                bad++;
            }
        }
    }
    logger.debug("values outside tolerance: " + bad + " of " + rows.size() * 9);
    return bad == 0;
}
