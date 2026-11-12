import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

(:glance)
class NamazGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    (:typecheck(false))
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var now = Time.now();
        if (!Prayers.hasLocation()) {
            dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, h * 30 / 100, Graphics.FONT_GLANCE, WatchUi.loadResource(Rez.Strings.AppName),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, h * 72 / 100, Graphics.FONT_GLANCE, WatchUi.loadResource(Rez.Strings.GlNoLocation),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var cur = PrayersUi.current(now);

        var name;
        var right;
        var sub;
        var color;
        var fill;
        if (cur != null) {
            var idx = cur[1];
            var left = cur[3].value() - now.value();
            var total = (cur[3].value() - cur[2].value()).toFloat();
            var done = PrayersUi.isDone(cur[0], idx);
            name = Prayers.name(idx);
            right = done ? WatchUi.loadResource(Rez.Strings.GlPrayed) : Fmt.countdown(left) + (left >= 3600 ? "h" : "m");
            sub = Lang.format(WatchUi.loadResource(Rez.Strings.GlEnds), [Fmt.hhmm(cur[3])]);
            color = Theme.urgency(left, Prayers.warnMinutes(idx) * 60, done);
            fill = left / total;
        } else {
            var nx = PrayersUi.upcoming(now);
            var left = nx[2].value() - now.value();
            name = Prayers.name(nx[1]);
            right = Lang.format(WatchUi.loadResource(Rez.Strings.GlIn), [Fmt.countdown(left) + (left >= 3600 ? "h" : "m")]);
            sub = Lang.format(WatchUi.loadResource(Rez.Strings.GlStarts), [Fmt.hhmm(nx[2])]);
            color = Theme.BLUE;
            fill = 0.0;
        }

        var f = Graphics.FONT_GLANCE;
        var y1 = h * 28 / 100;
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, y1, f, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var nw = dc.getTextWidthInPixels(name + "  ", f);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(nw, y1, f, right, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        // The glance area can be wider than what is visible; keep the bar compact.
        w = w * 70 / 100;

        // Progress bar.
        var by = h * 55 / 100;
        var bh = 5;
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(0, by, w, bh, 2);
        if (Theme.MONO) {
            dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(0, by, w, bh, 2);
        }
        if (fill > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(0, by, (w * fill).toNumber() + 1, bh, 2);
        }

        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 82 / 100, Graphics.FONT_GLANCE, sub, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
