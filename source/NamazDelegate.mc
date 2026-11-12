import Toybox.Attention;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class NamazDelegate extends WatchUi.BehaviorDelegate {
    var view as NamazView;

    function initialize(v as NamazView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Tap / top button on the "Now" page: toggle "prayed" for the current prayer.
    function onSelect() as Boolean {
        if (!Prayers.hasLocation()) {
            if (WatchUi has :Menu2) { Settings.openLocation(); return true; }
            return false;
        }
        if (view.page != NamazView.PAGE_NOW) { return false; }
        var cur = PrayersUi.current(Time.now());
        if (cur == null) { return false; }
        var day = cur[0] as Moment;
        var idx = cur[1] as Number;
        PrayersUi.setDone(day, idx, !PrayersUi.isDone(day, idx));
        Prayers.schedule(); // drop pending reminders for it
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 80)]);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        view.setPage(view.page + 1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.setPage(view.page - 1);
        return true;
    }

    // Hold the bottom button: settings.
    function onMenu() as Boolean {
        // The on-watch menu needs Menu2 (API 3.0); older watches use the phone app.
        if (!(WatchUi has :Menu2)) { return false; }
        Settings.open();
        return true;
    }
}
