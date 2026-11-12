import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

(:background :glance)
class NamazApp extends Application.AppBase {
    // Set when the app was started only to receive a notification action.
    var actionOnly as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    // v0.1 shipped Diyanet + a hand tune that put Maghrib ~8 min early for Kosovo.
    // Move untouched installs to the fitted Kosovo method once.
    (:typecheck(false))
    function migrate() as Void {
        if (Storage.getValue("migrated") == 2) { return; }
        try {
            if (Prayers.prop("method", 0) == 0 &&
                Prayers.prop("tune", "").equals("5,3,5,7,9,-1,0,8,-6")) {
                Application.Properties.setValue("method", PrayerCalc.KOSOVO);
                Application.Properties.setValue("tune", "0,0,0,0,0,0,0,0,0");
            }
        } catch (e) {
        }
        Storage.setValue("migrated", 2);
    }

    (:typecheck(false))
    function getInitialView() {
        // Tapping "Prayed" / "Not yet" on a notification starts the app to deliver
        // the tap. Registering first delivers any queued tap right away; if one
        // arrived, record it and close again instead of opening the app.
        listenForActions();
        if (actionOnly) { return [new QuitView()]; }
        migrate();
        updateLocation();
        Prayers.schedule();
        var view = new NamazView();
        return [view, new NamazDelegate(view)];
    }

    (:glance :typecheck(false))
    function getGlanceView() {
        return [new NamazGlance()];
    }

    (:typecheck(false))
    function getServiceDelegate() {
        return [new NamazService()];
    }

    (:notif :typecheck(false))
    function listenForActions() as Void {
        if (Toybox has :Notifications) {
            Toybox.Notifications.registerForNotificationMessages(method(:onNotification));
        }
    }

    (:nonotif)
    function listenForActions() as Void {
    }

    (:notif :typecheck(false))
    function onNotification(msg) as Void {
        Prayers.handleNotification(msg);
        actionOnly = true;
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() as Void {
        // Coordinates typed in the phone app replace a city picked on the watch.
        Storage.deleteValue("cityName");
        Prayers.invalidate();
        Prayers.schedule();
        WatchUi.requestUpdate();
    }

    // Save the watch's last known position (no GPS fix is started — no battery cost).
    (:typecheck(false))
    function updateLocation() as Void {
        if (!(Prayers.prop("useGps", true) as Boolean)) { return; }
        var deg = null;
        var info = Position.getInfo();
        if (info != null && info.position != null && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            deg = info.position.toDegrees();
        } else if (Toybox has :Weather) {
            var cc = Toybox.Weather.getCurrentConditions();
            if (cc != null && cc.observationLocationPosition != null) {
                deg = cc.observationLocationPosition.toDegrees();
            }
        }
        if (deg != null && (deg[0] != 0 || deg[1] != 0)) {
            Storage.setValue("loc", [deg[0].toDouble(), deg[1].toDouble()]);
            Prayers.invalidate();
        }
    }
}
