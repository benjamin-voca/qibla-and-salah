import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class NamazView extends WatchUi.View {
    enum { PAGE_NOW, PAGE_TODAY, PAGE_QIBLA, PAGE_WEEK, PAGE_COUNT }

    var page as Number = PAGE_NOW;
    var timer as Timer.Timer?;
    var wasAligned as Boolean = false;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        restartTimer();
    }

    function onHide() as Void {
        if (timer != null) { timer.stop(); timer = null; }
    }

    // The Qibla compass needs fast refresh; the rest only every 10 s.
    function restartTimer() as Void {
        if (timer != null) { timer.stop(); }
        timer = new Timer.Timer();
        timer.start(method(:tick), page == PAGE_QIBLA ? 200 : 10000, true);
    }

    function tick() as Void {
        WatchUi.requestUpdate();
    }

    function setPage(p as Number) as Void {
        page = (p + PAGE_COUNT) % PAGE_COUNT;
        wasAligned = false;
        restartTimer();
        WatchUi.requestUpdate();
    }

    function S(id) as String {
        return WatchUi.loadResource(id) as String;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        if (!Prayers.hasLocation()) { drawNoLocation(dc); return; }
        if (page == PAGE_NOW) { drawNow(dc); }
        else if (page == PAGE_TODAY) { drawToday(dc); }
        else if (page == PAGE_QIBLA) { drawQibla(dc); }
        else { drawWeek(dc); }
        Draw.pageDots(dc, page, PAGE_COUNT);
    }

    // ---- no location yet ----------------------------------------------------

    (:typecheck(false))
    function drawNoLocation(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Draw.moon(dc, w / 2, h * 24 / 100, w / 12, Theme.GOLD);
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 40 / 100, Graphics.FONT_SMALL, S(Rez.Strings.NeedLocation),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        Draw.wrapped(dc, S(Rez.Strings.NeedLocationHint), w / 2, h * 50 / 100, w * 70 / 100,
                     Graphics.FONT_XTINY, Theme.MUTED);
    }

    // ---- page 1: now -----------------------------------------------------------

    (:typecheck(false))
    function drawNow(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var now = Time.now();
        var cur = PrayersUi.current(now);

        var label;
        var name;
        var left;
        var sub;
        var color;
        var fill;
        var marker = -1.0;
        var done = false;

        if (cur != null) {
            var idx = cur[1];
            var total = (cur[3].value() - cur[2].value()).toFloat();
            left = cur[3].value() - now.value();
            var warn = Prayers.warnMinutes(idx) * 60;
            done = PrayersUi.isDone(cur[0], idx);
            label = done ? S(Rez.Strings.LblPrayed) : S(Rez.Strings.LblTimeLeft);
            name = Prayers.name(idx);
            sub = Lang.format(S(Rez.Strings.Ends), [Fmt.hhmm(cur[3])]);
            fill = left / total;
            if (warn > 0 && warn < total) { marker = warn / total; }
            color = Theme.urgency(left, warn, done);
        } else {
            // Between prayers (e.g. after sunrise): count down to the next one.
            var nx = PrayersUi.upcoming(now);
            var prevEnd = previousEnd(now);
            left = nx[2].value() - now.value();
            var total = (nx[2].value() - prevEnd).toFloat();
            label = S(Rez.Strings.LblNext);
            name = Prayers.name(nx[1]);
            sub = Lang.format(S(Rez.Strings.Starts), [Fmt.hhmm(nx[2])]);
            fill = total > 0 ? 1.0 - left / total : 0.0;
            color = Theme.BLUE;
        }

        Draw.crescent(dc, fill, color, marker);

        // Label + name.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 20 / 100, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 29 / 100, Graphics.FONT_MEDIUM, name, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Big countdown with its unit to the right.
        var big = Fmt.countdown(left);
        var unit = left >= 3600 ? S(Rez.Strings.UnitHours) : S(Rez.Strings.UnitMinutes);
        var bigFont = Graphics.FONT_NUMBER_MEDIUM;
        var bigY = h * 45 / 100;
        var bw = dc.getTextWidthInPixels(big, bigFont);
        var uw = dc.getTextWidthInPixels(unit, Graphics.FONT_XTINY);
        var x0 = cx - (bw + 8 + uw) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, bigY, bigFont, big, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.SOFT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + bw + 8, bigY + h * 3 / 100, Graphics.FONT_XTINY, unit,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // "ends 16:15" pill (or prayed badge).
        var pillY = h * 57 / 100;
        var pw = dc.getTextWidthInPixels(sub, Graphics.FONT_XTINY) + 28 + (done ? 22 : 0);
        var ph = dc.getFontHeight(Graphics.FONT_XTINY) + 4;
        dc.setColor(done ? Theme.GOLD_BG : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw / 2, pillY - ph / 2, pw, ph, ph / 2);
        if (Theme.MONO) {
            dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - pw / 2, pillY - ph / 2, pw, ph, ph / 2);
        }
        dc.setColor(done ? Theme.GOLD : Theme.SOFT, Graphics.COLOR_TRANSPARENT);
        if (done) {
            Draw.check(dc, cx - pw / 2 + 20, pillY, 14, Theme.GOLD);
            dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 11, pillY, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(cx, pillY, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Next prayers.
        var list = nextPrayers(now, 3);
        var y = h * 68 / 100;
        var rowH = h * 75 / 1000;
        for (var i = 0; i < list.size(); i++) {
            var item = list[i];
            var c = i == 0 ? Theme.TEXT : Theme.MUTED;
            dc.setColor(i == 0 ? Theme.GOLD : Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - w * 27 / 100, y, 3);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - w * 23 / 100, y, Graphics.FONT_XTINY, Prayers.name(item[1]),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx + w * 26 / 100, y, Graphics.FONT_XTINY, Fmt.hhmm(item[2]),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            y += rowH;
        }
    }

    // End of the most recent prayer window before `now` (for the "waiting" arc).
    (:typecheck(false))
    function previousEnd(now as Time.Moment) as Number {
        var today = Time.today();
        var best = null;
        var days = [today.subtract(new Time.Duration(Prayers.DAY)), today];
        for (var d = 0; d < days.size(); d++) {
            var ws = Prayers.windows(days[d]);
            for (var i = 0; i < ws.size(); i++) {
                var e = ws[i][1].value();
                if (e <= now.value() && (best == null || e > best)) { best = e; }
            }
        }
        return best == null ? now.value() - 3600 : best;
    }

    // Up to `count` prayers starting after `now`: [day, index, start, end].
    (:typecheck(false))
    function nextPrayers(now as Time.Moment, count as Number) as Array {
        var out = [];
        var today = Time.today();
        var days = [today, today.add(new Time.Duration(Prayers.DAY))];
        for (var d = 0; d < days.size() && out.size() < count; d++) {
            var ws = Prayers.windows(days[d]);
            for (var i = 0; i < ws.size() && out.size() < count; i++) {
                if (ws[i][0].compare(now) > 0) { out.add([days[d], i, ws[i][0], ws[i][1]]); }
            }
        }
        return out;
    }

    // ---- page 2: today's full schedule ----------------------------------------

    (:typecheck(false))
    function drawToday(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var today = Time.today();
        var now = Time.now();
        var t = Prayers.rawTimes(today);
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);

        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 9 / 100, Graphics.FONT_XTINY, info.day_of_week + ", " + info.day + " " + info.month,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var hijri = Hijri.today();
        if (hijri != null) {
            var hw = dc.getTextWidthInPixels(hijri, Graphics.FONT_XTINY);
            Draw.moon(dc, cx - hw / 2 - 12, h * 155 / 1000, 7, Theme.GOLD);
            dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 6, h * 155 / 1000, Graphics.FONT_XTINY, hijri,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // [label, minutes, prayerIndex or -1]
        var rows = [
            [S(Rez.Strings.Imsak), t[PrayerCalc.IMSAK], -1],
            [Prayers.name(0), t[PrayerCalc.FAJR], 0],
            [S(Rez.Strings.Sunrise), t[PrayerCalc.SUNRISE], -1],
            [Prayers.name(1), t[PrayerCalc.DHUHR], 1],
            [Prayers.name(2), t[PrayerCalc.ASR], 2],
            [Prayers.name(3), t[PrayerCalc.MAGHRIB], 3],
            [Prayers.name(4), t[PrayerCalc.ISHA], 4],
            [S(Rez.Strings.Midnight), t[PrayerCalc.MIDNIGHT], -1]
        ];
        var cur = PrayersUi.current(now);
        var rowH = h * 82 / 1000;
        var y = h * 245 / 1000;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var left = w * 25 / 100;
        var right = w * 75 / 100;
        for (var r = 0; r < rows.size(); r++) {
            var idx = rows[r][2];
            var m = Prayers.at(today, rows[r][1]);
            var active = idx >= 0 && cur != null && cur[1] == idx && cur[0].value() == today.value();
            var past = m.compare(now) < 0 && !active;
            var isPrayer = idx >= 0;
            if (active) {
                dc.setColor(Theme.GOLD_BG, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(left - 22, y - fh / 2 - 2, right - left + 44, fh + 4, (fh + 4) / 2);
                if (Theme.MONO) {
                    dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(left - 22, y - fh / 2 - 2, right - left + 44, fh + 4, (fh + 4) / 2);
                }
            }
            var color = active ? Theme.GOLD
                       : (!isPrayer ? Theme.DIM : (past ? Theme.MUTED : Theme.TEXT));
            if (!isPrayer && !past) { color = Theme.MUTED; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, y, Graphics.FONT_XTINY, rows[r][0], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(right, y, Graphics.FONT_XTINY, Fmt.hhmm(m), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            if (isPrayer && PrayersUi.isDone(today, idx)) {
                Draw.check(dc, left - 12, y, 12, Theme.GREEN);
            }
            y += rowH;
        }
    }

    // ---- page 3: qibla ---------------------------------------------------------

    (:typecheck(false))
    function drawQibla(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h * 45 / 100;
        var loc = Prayers.location();
        var qibla = Qibla.bearing(loc[0], loc[1]);

        var heading = null;
        var si = Sensor.getInfo();
        if (si != null && (si has :heading) && si.heading != null) {
            heading = Math.toDegrees(si.heading).toFloat();
            if (heading < 0) { heading += 360.0; }
        }
        var rot = heading == null ? 0.0 : -heading;
        var diff = heading == null ? 180.0 : (qibla - heading).abs();
        if (diff > 180.0) { diff = 360.0 - diff; }
        var aligned = heading != null && diff < 5.0;
        if (aligned && !wasAligned && (Attention has :vibrate)) {
            Attention.vibrate([new Attention.VibeProfile(60, 120)]);
        }
        wasAligned = aligned;
        var accent = aligned ? Theme.GREEN : Theme.GOLD;
        var R = w * 26 / 100;

        // Dial.
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(R / 4);
        dc.drawCircle(cx, cy, R - R / 8);
        dc.setPenWidth(1);
        if (Theme.MONO) {
            dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, R);
            dc.drawCircle(cx, cy, R - R / 4);
        }
        for (var a = 0; a < 360; a += 10) {
            var rad = Math.toRadians(a + rot);
            var major = a % 90 == 0;
            var r1 = major ? R - R / 4 + 2 : (a % 30 == 0 ? R - 12 : R - 6);
            dc.setColor(major ? Theme.SOFT : Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(major ? 3 : 2);
            dc.drawLine((cx + r1 * Math.sin(rad)).toNumber(), (cy - r1 * Math.cos(rad)).toNumber(),
                        (cx + (R - 1) * Math.sin(rad)).toNumber(), (cy - (R - 1) * Math.cos(rad)).toNumber());
        }
        dc.setPenWidth(1);
        var card = ["N", "E", "S", "W"];
        for (var i = 0; i < 4; i++) {
            var rad = Math.toRadians(i * 90 + rot);
            dc.setColor(i == 0 ? Theme.RED : Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx + (R + 15) * Math.sin(rad)).toNumber(), (cy - (R + 15) * Math.cos(rad)).toNumber(), Graphics.FONT_XTINY, card[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Needle towards the Kaaba.
        var q = Math.toRadians(qibla + rot);
        var sq = Math.sin(q);
        var cq = Math.cos(q);
        var tip = R - R / 4 - 6;
        var half = 9;
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [(cx + tip * sq).toNumber(), (cy - tip * cq).toNumber()],
            [(cx + half * cq).toNumber(), (cy + half * sq).toNumber()],
            [(cx - 14 * sq).toNumber(), (cy + 14 * cq).toNumber()],
            [(cx - half * cq).toNumber(), (cy - half * sq).toNumber()]
        ]);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 6);

        // Kaaba on the ring.
        var kr = R - R / 8;
        var kx = (cx + kr * sq).toNumber();
        var ky = (cy - kr * cq).toNumber();
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(kx - 10, ky - 10, 20, 20, 3);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(kx - 10, ky - 10, 20, 20, 3);
        dc.fillRectangle(kx - 9, ky - 4, 18, 3);

        // Labels.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 8 / 100, Graphics.FONT_XTINY, S(Rez.Strings.Qibla), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 815 / 1000 + 4, Graphics.FONT_SMALL,
                    aligned ? S(Rez.Strings.FacingQibla) : qibla.format("%d") + "\u00B0 " + Qibla.compassPoint(qibla),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 895 / 1000, Graphics.FONT_XTINY, heading == null ? S(Rez.Strings.NoCompass) : PrayersUi.locationName(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- page 4: week ----------------------------------------------------------

    (:typecheck(false))
    function drawWeek(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var today = Time.today();
        var now = Time.now();

        var todayCount = 0;
        for (var i = 0; i < 5; i++) { if (PrayersUi.isDone(today, i)) { todayCount++; } }
        var streak = 0;
        for (var d = (todayCount == 5 ? 0 : 1); d < 9; d++) {
            var day = today.subtract(new Time.Duration(d * Prayers.DAY));
            var all = true;
            for (var i = 0; i < 5 && all; i++) { all = PrayersUi.isDone(day, i); }
            if (!all) { break; }
            streak++;
        }

        // Five-segment ring summary in the header.
        var ry = h * 17 / 100;
        var rr = h * 8 / 100;
        dc.setPenWidth(6);
        for (var i = 0; i < 5; i++) {
            var a0 = 90 - i * 72 - 4;
            var a1 = 90 - (i + 1) * 72 + 4;
            dc.setColor(PrayersUi.isDone(today, i) ? Theme.GREEN : Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, ry, rr, Graphics.ARC_CLOCKWISE, a0, a1);
        }
        dc.setPenWidth(1);
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ry, Graphics.FONT_SMALL, todayCount + "/5", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(streak > 0 ? Theme.GOLD : Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 31 / 100, Graphics.FONT_XTINY,
                    streak == 0 ? S(Rez.Strings.PrayedToday)
                        : (streak == 1 ? S(Rez.Strings.StreakOne) : Lang.format(S(Rez.Strings.StreakMany), [streak])),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Grid: last 6 days x 5 prayers.
        var colW = w * 95 / 1000;
        var x0 = cx - colW * 2 + w * 6 / 100;
        var rowH = h * 75 / 1000;
        var y0 = h * 45 / 100;
        var dot = w * 2 / 100 + 2;
        var letters = [];
        for (var i = 0; i < 5; i++) { letters.add(Prayers.name(i).substring(0, 1)); }
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            dc.drawText(x0 + i * colW, y0 - rowH * 8 / 10, Graphics.FONT_XTINY, letters[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        for (var d = 0; d < 6; d++) {
            var day = today.subtract(new Time.Duration(d * Prayers.DAY));
            var info = Gregorian.info(day.add(new Time.Duration(12 * 3600)), Time.FORMAT_MEDIUM);
            var y = y0 + d * rowH;
            dc.setColor(d == 0 ? Theme.TEXT : Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 - colW * 7 / 10, y, Graphics.FONT_XTINY, d == 0 ? S(Rez.Strings.Today) : info.day_of_week,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            var ws = d == 0 ? Prayers.windows(today) : null;
            for (var i = 0; i < 5; i++) {
                var x = x0 + i * colW;
                if (PrayersUi.isDone(day, i)) {
                    dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x, y, dot);
                } else if (ws != null && ws[i][0].compare(now) > 0) {
                    dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x, y, dot - 2);
                } else {
                    dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
                    dc.setPenWidth(2);
                    dc.drawCircle(x, y, dot - 1);
                    dc.setPenWidth(1);
                }
            }
        }
    }
}
