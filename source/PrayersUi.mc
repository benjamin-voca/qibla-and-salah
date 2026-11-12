import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Helpers only the screens need. Kept out of Prayers so the background
// reminder service (32 KB on older watches) doesn't have to load them.
(:glance)
module PrayersUi {
    // Human-readable name of the location in use.
    function locationName() as String {
        if (Prayers.prop("useGps", true) as Boolean && Storage.getValue("loc") instanceof Array) {
            return Prayers.res(Rez.Strings.WatchLocation, "Watch location");
        }
        var name = Storage.getValue("cityName");
        if (name instanceof String) { return name; }
        var loc = Prayers.location();
        if (loc == null) { return Prayers.res(Rez.Strings.NotSet, "Not set"); }
        return loc[0].format("%.2f") + ", " + loc[1].format("%.2f");
    }

    // Returns [dayMidnight, index, start, end] of the window containing `now`,
    // checking yesterday's Isha too. null between Sunrise and Dhuhr etc.
    function current(now as Moment) as Array? {
        var today = Time.today();
        var days = [today.subtract(new Time.Duration(Prayers.DAY)), today];
        for (var d = 0; d < days.size(); d++) {
            var ws = Prayers.windows(days[d] as Moment);
            for (var i = 0; i < ws.size(); i++) {
                var w = ws[i];
                if (now.compare(w[0]) >= 0 && now.compare(w[1]) < 0) {
                    return [days[d], i, w[0], w[1]];
                }
            }
        }
        return null;
    }

    // [dayMidnight, index, start, end] of the next prayer to begin after `now`.
    function upcoming(now as Moment) as Array {
        var today = Time.today();
        var days = [today, today.add(new Time.Duration(Prayers.DAY))];
        for (var d = 0; d < days.size(); d++) {
            var ws = Prayers.windows(days[d] as Moment);
            for (var i = 0; i < ws.size(); i++) {
                if (ws[i][0].compare(now) > 0) { return [days[d], i, ws[i][0], ws[i][1]]; }
            }
        }
        return [today, 0, now, now]; // unreachable in practice
    }

    function isDone(dayMidnight as Moment, i as Number) as Boolean {
        return Prayers.isDoneKey(Prayers.doneKey(dayMidnight, i));
    }

    function setDone(dayMidnight as Moment, i as Number, done as Boolean) as Void {
        var key = Prayers.doneKey(dayMidnight, i);
        var d = Storage.getValue("done");
        if (!(d instanceof Dictionary)) { d = {}; }
        if (done) { d.put(key, true); } else { d.remove(key); }
        // Keep only the last ~8 days of entries (for the week view); also drops
        // keys in the old text format.
        var keys = d.keys();
        if (keys.size() > 45) {
            var cutoff = Prayers.dayKey(Time.today().value() - 8 * Prayers.DAY, 0);
            for (var k = 0; k < keys.size(); k++) {
                if (!(keys[k] instanceof Number) || keys[k] < cutoff) { d.remove(keys[k]); }
            }
        }
        Storage.setValue("done", d);
    }
}
