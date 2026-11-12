import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Runs in the background at each scheduled reminder time.
(:background)
class NamazService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    (:typecheck(false))
    function onTemporalEvent() as Void {
        Prayers.inBackground = true;
        debugMem("start");
        // Pick up any "Prayed" / "Not yet" taps that arrived while the app was closed.
        listenForActions();

        var now = Time.now().value();
        var handled = Storage.getValue("handled");
        var from = (handled instanceof Number) ? handled : now - 10 * 60;
        var to = now + 30;

        var evs = Prayers.events(from, to);
        if (Prayers.FORCE_BG && evs.size() == 0) {
            evs = Prayers.events(now - Prayers.DAY, now + Prayers.DAY);
        }
        if (evs.size() > 0) {
            // If several piled up (5-minute rule), only the latest matters.
            notify(evs[evs.size() - 1]);
        }
        Prayers.store("handled", to);
        Prayers.schedule();
        debugMem("end");
        Background.exit(null);
    }

    // Simulator-only memory check (see Prayers.FORCE_BG); empty in normal builds.
    (:forcebg)
    function debugMem(at as String) as Void {
        var st = System.getSystemStats();
        System.println("BG MEM " + at + " used=" + st.usedMemory + " total=" + st.totalMemory);
    }

    (:normalbg)
    function debugMem(at as String) as Void {
    }

    (:notif :typecheck(false))
    function listenForActions() as Void {
        if (Toybox has :Notifications) {
            try {
                Toybox.Notifications.registerForNotificationMessages(method(:onNotification));
            } catch (e) {
                // Not available in the background on this firmware; the app handles them on open.
            }
        }
    }

    (:nonotif)
    function listenForActions() as Void {
    }

    (:notif :typecheck(false))
    function onNotification(msg) as Void {
        Prayers.handleNotification(msg);
    }

    // ev = [Moment, kind, prayerIndex, doneKey, minutes]
    (:typecheck(false))
    function notify(ev as Array) as Void {
        var kind = ev[1] as Number;
        var name = Prayers.name(ev[2] as Number);
        var mins = ev[4] as Number;
        // Short title (the prayer), details in the subtitle: long titles scroll.
        var title = name;
        var sub;
        var started = kind == Prayers.EV_START;
        if (Prayers.noResources()) {
            sub = started ? "Started, until " + endTime(ev) : "Ends in " + mins + " min. Prayed?";
        } else if (started) {
            sub = Lang.format(Prayers.res(Rez.Strings.NotifStarted, ""), [endTime(ev)]);
        } else {
            sub = Lang.format(Prayers.res(Rez.Strings.NotifEnds, ""), [mins]);
        }

        show(ev, kind, mins, title, sub);
    }

    // Watches with the Notifications API (CIQ 5.1+): a real notification with buttons.
    (:notif :typecheck(false))
    function show(ev as Array, kind as Number, mins as Number, title as String, sub as String) as Void {
        if (Toybox has :Notifications) {
            var end = (ev[0] as Number) + mins * 60;
            var actions = [{ :label => Prayers.res(Rez.Strings.ActPrayed, "Prayed"), :data => "done" }];
            if (kind != Prayers.EV_START) {
                actions.add({ :label => Prayers.res(Rez.Strings.ActNotYet, "Not yet"), :data => "snooze" });
            }
            Toybox.Notifications.showNotification(title, sub, {
                :data => [ev[3], ev[2], end],
                :actions => actions,
                :dismissPrevious => true
            });
        } else {
            Background.requestApplicationWake(title + ": " + sub);
        }
    }

    // Older watches: a vibrating "open the app?" prompt.
    (:nonotif)
    function show(ev as Array, kind as Number, mins as Number, title as String, sub as String) as Void {
        Background.requestApplicationWake(title + ": " + sub);
    }

    function endTime(ev as Array) as String {
        return hhmmB(new Time.Moment((ev[0] as Number) + (ev[4] as Number) * 60));
    }
}

(:background)
function hhmmB(m as Time.Moment) as String {
    var i = Time.Gregorian.info(m, Time.FORMAT_SHORT);
    return i.hour.format("%02d") + ":" + i.min.format("%02d");
}
