import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Shown when the app was opened only to deliver a notification button tap:
// draws nothing and closes immediately, so the tap feels like a plain dismiss.
class QuitView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        System.exit();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}
