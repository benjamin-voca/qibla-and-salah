import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Time formatting shared by the app and the glance. Kept tiny on purpose:
// glances on some watches (Instinct E / 3 Solar) only get 32 KB.
(:glance)
module Fmt {
    function hhmm(m as Time.Moment) as String {
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        return i.hour.format("%02d") + ":" + i.min.format("%02d");
    }

    // 5025 s -> "1:24", 300 s -> "5" (minutes), rounded up.
    function countdown(secs as Number) as String {
        if (secs < 0) { secs = 0; }
        var mins = (secs + 59) / 60;
        var h = mins / 60;
        var m = mins % 60;
        return h > 0 ? h + ":" + m.format("%02d") : m.toString();
    }
}
