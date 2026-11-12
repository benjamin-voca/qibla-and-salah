import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

module Draw {
    // A true crescent hugging the top of the screen: the area inside the screen
    // circle and outside a slightly lowered circle, so it is thickest at the top
    // and tapers to points at the sides. `fill` (0..1) is coloured from the left
    // tip; `marker` (0..1, or -1) puts a notch at the warning time.
    const CRES_START = 178.0;
    const CRES_SWEEP = 176.0;
    const CRES_PTS = 28;

    (:typecheck(false))
    function crescent(dc as Graphics.Dc, fill as Float, color as Number, marker as Float) as Void {
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var R = w / 2.0 - 3;
        var d = w * 0.085;
        var R2 = R - 1.0;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var full = crescentPoly(cx, cy, R, R2, d, CRES_START, CRES_START - CRES_SWEEP);
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(full);
        if (Theme.MONO) { outline(dc, full, Theme.TEXT); }

        if (fill > 0.0) {
            if (fill > 1.0) { fill = 1.0; }
            var endA = CRES_START - CRES_SWEEP * fill;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(crescentPoly(cx, cy, R, R2, d, CRES_START, endA));
            // Glowing head.
            if (fill < 0.995) {
                var t = innerT(R2, d, endA);
                var mid = (R + t) / 2.0;
                var rad = Math.toRadians(endA);
                var hx = cx + mid * Math.cos(rad);
                var hy = cy - mid * Math.sin(rad);
                var hr = (R - t) / 2.0 + 2;
                dc.fillCircle(hx.toNumber(), hy.toNumber(), hr.toNumber());
                dc.setColor(Theme.MONO ? Theme.BG : Theme.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(hx.toNumber(), hy.toNumber(), (hr / 3.0 + 1).toNumber());
            }
        }

        if (marker > 0.0 && marker < 1.0) {
            var a = CRES_START - CRES_SWEEP * marker;
            var rad = Math.toRadians(a);
            var t = innerT(R2, d, a);
            var c = Math.cos(rad);
            var s = Math.sin(rad);
            dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine((cx + (t - 2) * c).toNumber(), (cy - (t - 2) * s).toNumber(),
                        (cx + (R + 3) * c).toNumber(), (cy - (R + 3) * s).toNumber());
            dc.setPenWidth(1);
            dc.setColor(Theme.SOFT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((cx + (t - 7) * c).toNumber(), (cy - (t - 7) * s).toNumber(), 3);
        }
    }

    // Distance from the screen centre to the inner circle along angle `deg`.
    function innerT(R2 as Float, d as Float, deg as Float) as Float {
        var s = Math.sin(Math.toRadians(deg));
        return (-d * s + Math.sqrt(d * d * s * s - d * d + R2 * R2)).toFloat();
    }

    (:typecheck(false))
    function crescentPoly(cx, cy, R, R2, d, a0, a1) as Array {
        var pts = [];
        var n = CRES_PTS;
        for (var i = 0; i <= n; i++) {
            var a = a0 + (a1 - a0) * i / n;
            var rad = Math.toRadians(a);
            pts.add([(cx + R * Math.cos(rad)).toNumber(), (cy - R * Math.sin(rad)).toNumber()]);
        }
        for (var i = n; i >= 0; i--) {
            var a = a0 + (a1 - a0) * i / n;
            var rad = Math.toRadians(a);
            var t = innerT(R2, d, a);
            if (t > R) { t = R; }
            pts.add([(cx + t * Math.cos(rad)).toNumber(), (cy - t * Math.sin(rad)).toNumber()]);
        }
        return pts;
    }

    // Closed outline through polygon points (used instead of dim fills on mono screens).
    (:typecheck(false))
    function outline(dc as Graphics.Dc, pts as Array, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < pts.size(); i++) {
            var a = pts[i];
            var b = pts[(i + 1) % pts.size()];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    function check(dc as Graphics.Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        var u = size / 4;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(size > 16 ? 4 : 3);
        dc.drawLine(x - 2 * u, y, x - u / 2, y + 3 * u / 2);
        dc.drawLine(x - u / 2, y + 3 * u / 2, x + 2 * u, y - 3 * u / 2);
        dc.setPenWidth(1);
    }

    // Centered, word-wrapped text (works on every API level, unlike TextArea).
    (:typecheck(false))
    function wrapped(dc as Graphics.Dc, text as String, cx as Number, y as Number, width as Number,
                     font, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lineH = dc.getFontHeight(font);
        var line = "";
        var rest = text;
        while (rest.length() > 0) {
            var sp = rest.find(" ");
            var word = sp == null ? rest : rest.substring(0, sp);
            rest = sp == null ? "" : rest.substring(sp + 1, rest.length());
            var tryLine = line.length() == 0 ? word : line + " " + word;
            if (line.length() > 0 && dc.getTextWidthInPixels(tryLine, font) > width) {
                dc.drawText(cx, y, font, line, Graphics.TEXT_JUSTIFY_CENTER);
                y += lineH;
                line = word;
            } else {
                line = tryLine;
            }
        }
        if (line.length() > 0) { dc.drawText(cx, y, font, line, Graphics.TEXT_JUSTIFY_CENTER); }
    }

    // Small crescent-moon glyph (for headers).
    function moon(dc as Graphics.Dc, x as Number, y as Number, r as Number, color as Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + r * 45 / 100, y - r * 25 / 100, r * 85 / 100);
    }

    // Page indicator dots along the bottom.
    function pageDots(dc as Graphics.Dc, page as Number, count as Number) as Void {
        var w = dc.getWidth();
        var y = dc.getHeight() - dc.getHeight() * 45 / 1000;
        var gap = 13;
        var x0 = w / 2 - (count - 1) * gap / 2;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        for (var i = 0; i < count; i++) {
            if (i == page) {
                dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x0 + i * gap - 6, y - 3, 12, 6, 3);
            } else {
                dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x0 + i * gap, y, 3);
            }
        }
    }



}

module Qibla {
    const KAABA_LAT = 21.4225d;
    const KAABA_LNG = 39.8262d;

    // Initial great-circle bearing (degrees from true north) towards the Kaaba.
    function bearing(lat as Double, lng as Double) as Float {
        var p1 = Math.toRadians(lat);
        var p2 = Math.toRadians(KAABA_LAT);
        var dl = Math.toRadians(KAABA_LNG - lng);
        var y = Math.sin(dl);
        var x = Math.cos(p1) * Math.tan(p2) - Math.sin(p1) * Math.cos(dl);
        var b = Math.toDegrees(Math.atan2(y, x)).toFloat();
        return b < 0 ? b + 360.0 : b;
    }

    function compassPoint(deg as Float) as String {
        var points = Hijri.split(WatchUi.loadResource(Rez.Strings.CompassPoints) as String);
        return points[((deg + 22.5) / 45.0).toNumber() % 8];
    }
}

module Hijri {
    // "a,b,c" -> ["a", "b", "c"]
    function split(s as String) as Array<String> {
        var out = [] as Array<String>;
        var rest = s;
        while (true) {
            var i = rest.find(",");
            if (i == null) { out.add(rest); break; }
            out.add(rest.substring(0, i) as String);
            rest = rest.substring(i + 1, rest.length()) as String;
        }
        return out;
    }


    // Umm al-Qura date for a day number (days since 1970-01-01, local):
    // [day 1-30, month 0-11, year], or null outside the table.
    function fromDay(day as Number) as Array<Number>? {
        var s = HijriTable.STARTS;
        if (day < s[0] || day >= s[s.size() - 1] + 30) { return null; }
        var i = s.size() - 1;
        while (i > 0 && s[i] > day) { i--; }
        var m = HijriTable.FIRST_MONTH - 1 + i;
        return [day - s[i] + 1, m % 12, HijriTable.FIRST_YEAR + m / 12];
    }

    // Today's date as "2 Jumada II 1448", or null outside the table.
    function today() as String? {
        var local = Time.now().value() + System.getClockTime().timeZoneOffset;
        // Umm al-Qura, plus the user's adjustment. (The Kosovo takvim matched Umm
        // al-Qura on 29 of 32 archived days; it differs only around months the
        // Islamic Community announces itself, so there is no fixed shift to apply.)
        var adjust = Prayers.prop("hijriAdjust", 0) as Number;
        var h = fromDay(local / 86400 + adjust);
        if (h == null) { return null; }
        var months = split(WatchUi.loadResource(Rez.Strings.HijriMonths) as String);
        return h[0] + " " + months[h[1]] + " " + h[2];
    }
}
