import Toybox.Lang;

// Colour themes, chosen per watch at compile time (see monkey.jungle):
//   (:color)    AMOLED / LCD screens
//   (:mip)      64-colour MIP screens (every channel is 00/55/AA/FF)
//   (:lowcolor) 16-colour screens (Forerunner 55, 735XT)
//   (:mono)     black-and-white screens (Instinct, Descent G1)

(:glance :color)
module Theme {
    const MONO = false;
    const BG = 0x000000;
    const TEXT = 0xFFFFFF;
    const SOFT = 0xD1D5DB;
    const MUTED = 0x8B929C;
    const DIM = 0x454B55;
    const TRACK = 0x262A31;
    const GREEN = 0x34D399;
    const AMBER = 0xFBBF24;
    const RED = 0xF87171;
    const GOLD = 0xE9C46A;
    const GOLD_BG = 0x2B2414;
    const BLUE = 0x60A5FA;

    function urgency(left as Number, warn as Number, done as Boolean) as Number {
        return ThemeUtil.urgency(left, warn, done, GOLD, RED, AMBER, GREEN);
    }
}

(:glance :mip)
module Theme {
    const MONO = false;
    const BG = 0x000000;
    const TEXT = 0xFFFFFF;
    const SOFT = 0xFFFFFF;
    const MUTED = 0xAAAAAA;
    const DIM = 0x555555;
    const TRACK = 0x555555;
    const GREEN = 0x55FFAA;
    const AMBER = 0xFFAA00;
    const RED = 0xFF5555;
    const GOLD = 0xFFAA55;
    const GOLD_BG = 0x550000;
    const BLUE = 0x55AAFF;

    function urgency(left as Number, warn as Number, done as Boolean) as Number {
        return ThemeUtil.urgency(left, warn, done, GOLD, RED, AMBER, GREEN);
    }
}

(:glance :lowcolor)
module Theme {
    const MONO = false;
    const BG = 0x000000;
    const TEXT = 0xFFFFFF;
    const SOFT = 0xAAAAAA;
    const MUTED = 0xAAAAAA;
    const DIM = 0x555555;
    const TRACK = 0x555555;
    const GREEN = 0x00FF00;
    const AMBER = 0xFFAA00;
    const RED = 0xFF0000;
    const GOLD = 0xFFFF00;
    const GOLD_BG = 0x000000;
    const BLUE = 0x00AAFF;

    function urgency(left as Number, warn as Number, done as Boolean) as Number {
        return ThemeUtil.urgency(left, warn, done, GOLD, RED, AMBER, GREEN);
    }
}

(:glance :mono)
module Theme {
    // Two colours only: shapes that are "dim" on colour screens are drawn as
    // white outlines instead (see Draw).
    const MONO = true;
    const BG = 0x000000;
    const TEXT = 0xFFFFFF;
    const SOFT = 0xFFFFFF;
    const MUTED = 0xFFFFFF;
    const DIM = 0xFFFFFF;
    const TRACK = 0x000000;
    const GREEN = 0xFFFFFF;
    const AMBER = 0xFFFFFF;
    const RED = 0xFFFFFF;
    const GOLD = 0xFFFFFF;
    const GOLD_BG = 0x000000;
    const BLUE = 0xFFFFFF;

    function urgency(left as Number, warn as Number, done as Boolean) as Number {
        return TEXT;
    }
}

(:glance)
module ThemeUtil {
    // Colour for "time left" given seconds left and the warning threshold.
    function urgency(left as Number, warn as Number, done as Boolean,
                     gold as Number, red as Number, amber as Number, green as Number) as Number {
        if (done) { return gold; }
        if (warn > 0 && left <= warn) { return red; }
        if (warn > 0 && left <= warn * 2) { return amber; }
        return green;
    }
}
