import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

// On-watch settings (hold the lower button / menu). Everything here is also
// editable from the Garmin Connect phone app.
module Settings {
    const WARN_VALUES = [0, 5, 10, 15, 20, 25, 30, 40, 45, 60, 90];
    const METHOD_IDS = [Rez.Strings.M0, Rez.Strings.M1, Rez.Strings.M2, Rez.Strings.M3, Rez.Strings.M4,
                        Rez.Strings.M5, Rez.Strings.M6, Rez.Strings.M7, Rez.Strings.M8, Rez.Strings.M9,
                        Rez.Strings.M10, Rez.Strings.M11, Rez.Strings.M12, Rez.Strings.M13, Rez.Strings.M14,
                        Rez.Strings.M15, Rez.Strings.M16, Rez.Strings.M17, Rez.Strings.M18, Rez.Strings.M19,
                        Rez.Strings.M20, Rez.Strings.M21, Rez.Strings.M22];
    const WARN_KIND = [:warnFajr, :warnDhuhr, :warnAsr, :warnMaghrib, :warnIsha];

    // [regionString, [[name, lat, lng], ...]]
    const CITY_REGIONS = [
        [Rez.Strings.RegKosovo, [
            ["Prishtina", 42.6629, 21.1655], ["Prizren", 42.2139, 20.7397], ["Peja", 42.6593, 20.2887],
            ["Gjakova", 42.3803, 20.4308], ["Mitrovica", 42.8914, 20.8660], ["Ferizaj", 42.3702, 21.1553],
            ["Gjilan", 42.4635, 21.4694], ["Podujeva", 42.9106, 21.1931], ["Vushtrri", 42.8231, 20.9675]]],
        [Rez.Strings.RegBalkans, [
            ["Istanbul", 41.0082, 28.9784], ["Ankara", 39.9334, 32.8597], ["Izmir", 38.4237, 27.1428],
            ["Tirana", 41.3275, 19.8187], ["Skopje", 41.9981, 21.4254], ["Tetovo", 42.0069, 20.9715],
            ["Sarajevo", 43.8563, 18.4131], ["Novi Pazar", 43.1367, 20.5122], ["Podgorica", 42.4304, 19.2594],
            ["Sofia", 42.6977, 23.3219]]],
        [Rez.Strings.RegEurope, [
            ["London", 51.5074, -0.1278], ["Birmingham", 52.4862, -1.8904], ["Manchester", 53.4808, -2.2426],
            ["Paris", 48.8566, 2.3522], ["Marseille", 43.2965, 5.3698], ["Berlin", 52.5200, 13.4050],
            ["Hamburg", 53.5511, 9.9937], ["Munich", 48.1351, 11.5820], ["Vienna", 48.2082, 16.3738],
            ["Zurich", 47.3769, 8.5417], ["Brussels", 50.8503, 4.3517], ["Amsterdam", 52.3676, 4.9041],
            ["Stockholm", 59.3293, 18.0686], ["Oslo", 59.9139, 10.7522], ["Copenhagen", 55.6761, 12.5683],
            ["Madrid", 40.4168, -3.7038], ["Rome", 41.9028, 12.4964], ["Moscow", 55.7558, 37.6173],
            ["Kazan", 55.7963, 49.1088]]],
        [Rez.Strings.RegMiddleEast, [
            ["Makkah", 21.4225, 39.8262], ["Madinah", 24.4672, 39.6111], ["Riyadh", 24.7136, 46.6753],
            ["Jeddah", 21.5433, 39.1728], ["Dubai", 25.2048, 55.2708], ["Abu Dhabi", 24.4539, 54.3773],
            ["Doha", 25.2854, 51.5310], ["Kuwait City", 29.3759, 47.9774], ["Manama", 26.2285, 50.5860],
            ["Muscat", 23.5880, 58.3829], ["Amman", 31.9454, 35.9284], ["Jerusalem", 31.7683, 35.2137],
            ["Beirut", 33.8938, 35.5018], ["Damascus", 33.5138, 36.2765], ["Baghdad", 33.3152, 44.3661],
            ["Tehran", 35.6892, 51.3890]]],
        [Rez.Strings.RegAfrica, [
            ["Cairo", 30.0444, 31.2357], ["Alexandria", 31.2001, 29.9187], ["Casablanca", 33.5731, -7.5898],
            ["Rabat", 34.0209, -6.8416], ["Algiers", 36.7538, 3.0588], ["Tunis", 36.8065, 10.1815],
            ["Tripoli", 32.8872, 13.1913], ["Khartoum", 15.5007, 32.5599], ["Lagos", 6.5244, 3.3792],
            ["Kano", 12.0022, 8.5920], ["Dakar", 14.7167, -17.4677], ["Nairobi", -1.2921, 36.8219],
            ["Mogadishu", 2.0469, 45.3182], ["Johannesburg", -26.2041, 28.0473], ["Cape Town", -33.9249, 18.4241]]],
        [Rez.Strings.RegAsia, [
            ["Karachi", 24.8607, 67.0011], ["Lahore", 31.5204, 74.3587], ["Islamabad", 33.6844, 73.0479],
            ["Delhi", 28.7041, 77.1025], ["Mumbai", 19.0760, 72.8777], ["Hyderabad", 17.3850, 78.4867],
            ["Dhaka", 23.8103, 90.4125], ["Kabul", 34.5553, 69.2075], ["Tashkent", 41.2995, 69.2401],
            ["Almaty", 43.2220, 76.8512], ["Jakarta", -6.2088, 106.8456], ["Surabaya", -7.2575, 112.7521],
            ["Kuala Lumpur", 3.1390, 101.6869], ["Singapore", 1.3521, 103.8198],
            ["Bandar Seri Begawan", 4.9031, 114.9398], ["Manila", 14.5995, 120.9842]]],
        [Rez.Strings.RegAmericas, [
            ["New York", 40.7128, -74.0060], ["Chicago", 41.8781, -87.6298], ["Detroit", 42.3314, -83.0458],
            ["Houston", 29.7604, -95.3698], ["Los Angeles", 34.0522, -118.2437], ["Toronto", 43.6532, -79.3832],
            ["Montreal", 45.5017, -73.5673], ["Mexico City", 19.4326, -99.1332], ["São Paulo", -23.5505, -46.6333],
            ["Buenos Aires", -34.6037, -58.3816]]],
        [Rez.Strings.RegOceania, [
            ["Sydney", -33.8688, 151.2093], ["Melbourne", -37.8136, 144.9631], ["Perth", -31.9505, 115.8605],
            ["Auckland", -36.8485, 174.7633]]]
    ];

    function S(id) as String {
        return WatchUi.loadResource(id) as String;
    }

    function warnLabel(m as Number) as String {
        return m == 0 ? S(Rez.Strings.Off) : Lang.format(S(Rez.Strings.MinBeforeEnd), [m]);
    }

    function warnSummary() as String {
        var first = Prayers.warnMinutes(0);
        for (var i = 1; i < 5; i++) {
            if (Prayers.warnMinutes(i) != first) { return S(Rez.Strings.DifferentPerPrayer); }
        }
        return warnLabel(first);
    }

    function methodLabel() as String {
        var m = Prayers.prop("method", Prayers.AUTO) as Number;
        var name = S(METHOD_IDS[Prayers.method()]);
        return m == Prayers.AUTO ? Lang.format(S(Rez.Strings.AutoWith), [name]) : name;
    }

    function asrLabel() as String {
        var a = Prayers.prop("asrSchool", 0) as Number;
        var name = Prayers.asrFactor() == 2 ? S(Rez.Strings.Hanafi) : S(Rez.Strings.Standard);
        return a == 0 ? Lang.format(S(Rez.Strings.AutoWith), [name]) : name;
    }

    function highLatLabel() as String {
        var h = Prayers.prop("highLat", 0) as Number;
        if (h == 1) { return S(Rez.Strings.HlMiddle); }
        if (h == 2) { return S(Rez.Strings.HlSeventh); }
        if (h == 3) { return S(Rez.Strings.HlAngle); }
        return Lang.format(S(Rez.Strings.AutoWith), [S(Rez.Strings.HlAngle)]);
    }

    function hijriLabel() as String {
        var a = Prayers.prop("hijriAdjust", 0) as Number;
        var h = Hijri.today();
        var sign = a > 0 ? "+" : "";
        return (h == null ? "" : h + "  ") + "(" + sign + a + ")";
    }

    (:typecheck(false))
    function open() as Void {
        var menu = new WatchUi.Menu2({ :title => S(Rez.Strings.AppName) });
        menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.WarningTime), warnSummary(), :warn, null));
        menu.addItem(new WatchUi.ToggleMenuItem(S(Rez.Strings.AlertAtStart), null, :atStart,
                                                Prayers.prop("notifyAtStart", true), null));
        menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.Location), PrayersUi.locationName(), :location, null));
        menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.Calculation), methodLabel(), :calc, null));
        WatchUi.pushView(menu, new MainDelegate(), WatchUi.SLIDE_UP);
    }

    // Open straight at the location menu (used by the "location needed" screen).
    function openLocation() as Void {
        pushLocationMenu(null);
    }

    function changed() as Void {
        Prayers.invalidate();
        Prayers.schedule();
        WatchUi.requestUpdate();
    }

    // Generic single-choice list. `kind` tells apply() what to change.
    (:typecheck(false))
    function choose(title as String, labels as Array, values as Array, current, kind as Symbol, parents) as Void {
        var menu = new WatchUi.Menu2({ :title => title });
        var focus = 0;
        for (var i = 0; i < labels.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(labels[i], null, i, null));
            if (values[i] == current) { focus = i; }
        }
        menu.setFocus(focus);
        WatchUi.pushView(menu, new ChoiceDelegate(kind, values, parents), WatchUi.SLIDE_LEFT);
    }

    // Apply a choice; returns the new sublabel for the item that opened the list.
    (:typecheck(false))
    function apply(kind as Symbol, value) as String? {
        if (kind == :warnAll) {
            for (var i = 0; i < 5; i++) { Properties.setValue(Prayers.WARN_PROPS[i], value); }
            return warnLabel(value);
        }
        var w = WARN_KIND.indexOf(kind);
        if (w >= 0) {
            Properties.setValue(Prayers.WARN_PROPS[w], value);
            return warnLabel(value);
        }
        if (kind == :method) { Properties.setValue("method", value); Prayers.invalidate(); return methodLabel(); }
        if (kind == :asr) { Properties.setValue("asrSchool", value); Prayers.invalidate(); return asrLabel(); }
        if (kind == :highLat) { Properties.setValue("highLat", value); Prayers.invalidate(); return highLatLabel(); }
        if (kind == :hijri) { Properties.setValue("hijriAdjust", value); return hijriLabel(); }
        if (kind == :isha) {
            Properties.setValue("ishaEnd", value);
            return value == 1 ? Prayers.name(0) : S(Rez.Strings.IslamicMidnight);
        }
        if (kind == :city) {
            Properties.setValue("latitude", value[1].toFloat());
            Properties.setValue("longitude", value[2].toFloat());
            Properties.setValue("useGps", false);
            Storage.setValue("cityName", value[0]);
            Prayers.invalidate();
            return value[0];
        }
        return null;
    }

    (:typecheck(false))
    function pushLocationMenu(parent) as Void {
        var menu = new WatchUi.Menu2({ :title => S(Rez.Strings.Location) });
        menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.ChooseCity), PrayersUi.locationName(), :city, null));
        menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.GetGpsFix), S(Rez.Strings.GpsHint), :fix, null));
        menu.addItem(new WatchUi.ToggleMenuItem(S(Rez.Strings.UseWatchLocation), S(Rez.Strings.LastKnown),
                                                :useGps, Prayers.prop("useGps", true), null));
        WatchUi.pushView(menu, new LocationDelegate(parent, menu), WatchUi.SLIDE_LEFT);
    }

    // ---- delegates --------------------------------------------------------------

    class MainDelegate extends WatchUi.Menu2InputDelegate {
        function initialize() { Menu2InputDelegate.initialize(); }

        (:typecheck(false))
        function onSelect(item) as Void {
            var id = item.getId();
            if (id == :warn) {
                var menu = new WatchUi.Menu2({ :title => S(Rez.Strings.WarnBeforeEnd) });
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.AllPrayers), warnSummary(), :warnAll, null));
                for (var i = 0; i < 5; i++) {
                    menu.addItem(new WatchUi.MenuItem(Prayers.name(i), warnLabel(Prayers.warnMinutes(i)),
                                                      WARN_KIND[i], null));
                }
                WatchUi.pushView(menu, new WarnDelegate(item, menu), WatchUi.SLIDE_LEFT);
            } else if (id == :atStart) {
                Properties.setValue("notifyAtStart", item.isEnabled());
                changed();
            } else if (id == :location) {
                pushLocationMenu(item);
            } else if (id == :calc) {
                var menu = new WatchUi.Menu2({ :title => S(Rez.Strings.Calculation) });
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.CalcMethod), methodLabel(), :method, null));
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.AsrSchool), asrLabel(), :asr, null));
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.IshaEndsAt),
                    Prayers.prop("ishaEnd", 0) == 1 ? Prayers.name(0) : S(Rez.Strings.IslamicMidnight), :isha, null));
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.HighLat), highLatLabel(), :highLat, null));
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.HijriDate), hijriLabel(), :hijri, null));
                menu.addItem(new WatchUi.MenuItem(S(Rez.Strings.FineTune), S(Rez.Strings.InPhoneApp), :tune, null));
                WatchUi.pushView(menu, new CalcDelegate(item), WatchUi.SLIDE_LEFT);
            }
        }
    }

    class WarnDelegate extends WatchUi.Menu2InputDelegate {
        var parent;
        var menu;
        function initialize(p, m) { Menu2InputDelegate.initialize(); parent = p; menu = m; }

        (:typecheck(false))
        function onSelect(item) as Void {
            var labels = [];
            for (var i = 0; i < WARN_VALUES.size(); i++) {
                labels.add(WARN_VALUES[i] == 0 ? S(Rez.Strings.Off) : Lang.format(S(Rez.Strings.MinShort), [WARN_VALUES[i]]));
            }
            var id = item.getId();
            var cur = id == :warnAll ? Prayers.warnMinutes(0) : Prayers.warnMinutes(WARN_KIND.indexOf(id));
            choose(item.getLabel(), labels, WARN_VALUES, cur, id, [item, parent, menu]);
        }
    }

    class LocationDelegate extends WatchUi.Menu2InputDelegate {
        var parent;
        var menu;
        var fixItem;
        function initialize(p, m) { Menu2InputDelegate.initialize(); parent = p; menu = m; }

        (:typecheck(false))
        function onSelect(item) as Void {
            var id = item.getId();
            if (id == :city) {
                var regions = new WatchUi.Menu2({ :title => S(Rez.Strings.ChooseCity) });
                for (var i = 0; i < CITY_REGIONS.size(); i++) {
                    regions.addItem(new WatchUi.MenuItem(S(CITY_REGIONS[i][0]), null, i, null));
                }
                WatchUi.pushView(regions, new RegionDelegate([item, parent]), WatchUi.SLIDE_LEFT);
            } else if (id == :useGps) {
                Properties.setValue("useGps", item.isEnabled());
                if (parent != null) { parent.setSubLabel(PrayersUi.locationName()); }
                changed();
            } else if (id == :fix) {
                fixItem = item;
                item.setSubLabel(S(Rez.Strings.Searching));
                Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
                WatchUi.requestUpdate();
            }
        }

        (:typecheck(false))
        function onPosition(info) as Void {
            if (info == null || info.position == null) { return; }
            var deg = info.position.toDegrees();
            Storage.setValue("loc", [deg[0].toDouble(), deg[1].toDouble()]);
            Storage.deleteValue("cityName");
            Properties.setValue("useGps", true);
            if (fixItem != null) {
                fixItem.setSubLabel(Lang.format(S(Rez.Strings.GotFix), [deg[0].format("%.3f") + ", " + deg[1].format("%.3f")]));
            }
            if (parent != null) { parent.setSubLabel(PrayersUi.locationName()); }
            changed();
        }
    }

    class RegionDelegate extends WatchUi.Menu2InputDelegate {
        var parents;
        function initialize(p) { Menu2InputDelegate.initialize(); parents = p; }

        (:typecheck(false))
        function onSelect(item) as Void {
            var cities = CITY_REGIONS[item.getId()][1];
            var labels = [];
            for (var i = 0; i < cities.size(); i++) { labels.add(cities[i][0]); }
            choose(item.getLabel(), labels, cities, null, :city, parents);
        }
    }

    class CalcDelegate extends WatchUi.Menu2InputDelegate {
        var parent;
        function initialize(p) { Menu2InputDelegate.initialize(); parent = p; }

        (:typecheck(false))
        function onSelect(item) as Void {
            var id = item.getId();
            if (id == :method) {
                var labels = [S(Rez.Strings.Automatic)];
                var values = [Prayers.AUTO];
                for (var i = 0; i < METHOD_IDS.size(); i++) { labels.add(S(METHOD_IDS[i])); values.add(i); }
                choose(S(Rez.Strings.CalcMethod), labels, values, Prayers.prop("method", Prayers.AUTO), :method, [item, parent]);
            } else if (id == :asr) {
                choose(S(Rez.Strings.AsrSchool), [S(Rez.Strings.Automatic), S(Rez.Strings.Standard), S(Rez.Strings.Hanafi)],
                       [0, 1, 2], Prayers.prop("asrSchool", 0), :asr, [item]);
            } else if (id == :isha) {
                choose(S(Rez.Strings.IshaEndsAt), [S(Rez.Strings.IslamicMidnight), Prayers.name(0)], [0, 1],
                       Prayers.prop("ishaEnd", 0), :isha, [item]);
            } else if (id == :highLat) {
                choose(S(Rez.Strings.HighLat), [S(Rez.Strings.Automatic), S(Rez.Strings.HlMiddle),
                       S(Rez.Strings.HlSeventh), S(Rez.Strings.HlAngle)], [0, 1, 2, 3],
                       Prayers.prop("highLat", 0), :highLat, [item]);
            } else if (id == :hijri) {
                choose(S(Rez.Strings.HijriDate), ["-2", "-1", "0", "+1", "+2"], [-2, -1, 0, 1, 2],
                       Prayers.prop("hijriAdjust", 0), :hijri, [item]);
            }
        }
    }

    class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
        var kind;
        var values;
        var parents;
        function initialize(k, v, p) {
            Menu2InputDelegate.initialize();
            kind = k; values = v; parents = p;
        }

        (:typecheck(false))
        function onSelect(item) as Void {
            var sub = apply(kind, values[item.getId()]);
            if (sub != null && parents != null && parents[0] != null) {
                parents[0].setSubLabel(sub);
                if (parents.size() > 1 && parents[1] != null) {
                    var top = parents[1];
                    if (top.getId() == :warn) {
                        top.setSubLabel(warnSummary());
                        if (kind == :warnAll && parents.size() > 2) {
                            var m = parents[2];
                            for (var p = 0; p < 5; p++) {
                                var at = m.findItemById(WARN_KIND[p]);
                                if (at >= 0) { m.getItem(at).setSubLabel(warnLabel(Prayers.warnMinutes(p))); }
                            }
                        }
                    } else if (top.getId() == :location) {
                        top.setSubLabel(PrayersUi.locationName());
                    } else if (top.getId() == :calc) {
                        top.setSubLabel(methodLabel());
                    }
                }
            }
            changed();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            // City lists are two levels deep (region -> city): close the region list too.
            if (kind == :city) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        }
    }
}
