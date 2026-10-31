/*
    LooneyBin car radio -- station config. Read server-side by APS_fnc_radioSRV (broadcasts the current track per
    station) + client-side by the HUD, via  missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio" >> ...

    2026-07-06: ALL MUSIC WIPED + stations SEGREGATED. Each station now has its OWN song list (before, Origin+KHR
    shared one list and Pulse+Classico+Anarchy shared another -- that was the cross-station "bleed"). Starting fresh,
    genre by genre. To add a song to a station: (1) drop <file>.ogg in sounds\radio\, (2) add a CfgSounds class in
    CfgSounds.hpp, (3) add its class name to that station's AUTORADIO_RadioNN[] + a display title to ...NNName[] +
    the length in whole seconds to ...NNLengh[] (the three arrays stay parallel / index-aligned).
    An empty station simply broadcasts nothing (silent) until it has songs.

    Stations: 01 Origin / 02 KHR / 03 Pulse / 04 Classico (classical) / 05 Anarchy.
*/
class AP_Radio_Cfg {class AutoRadio {
        AUTORADIO_Radio[]      = { "AUTORADIO_Radio01", "AUTORADIO_Radio02", "AUTORADIO_Radio03", "AUTORADIO_Radio04", "AUTORADIO_Radio05" };
        AUTORADIO_RadioName[]  = { "AUTORADIO_Radio01Name", "AUTORADIO_Radio02Name", "AUTORADIO_Radio03Name", "AUTORADIO_Radio04Name", "AUTORADIO_Radio05Name" };
        AUTORADIO_RadioLengh[] = { "AUTORADIO_Radio01Lengh", "AUTORADIO_Radio02Lengh", "AUTORADIO_Radio03Lengh", "AUTORADIO_Radio04Lengh", "AUTORADIO_Radio05Lengh" };
        AUTORADIO_RadioColor[] = { "[0.988, 0.816, 0.062, 1]", "[0.203, 0.484, 0.203, 1]", "[0.683, 0.195, 0.511, 1]", "[0.121, 0.398, 0.660, 1]", "[0.796, 0, 0, 1]" };
        AUTORADIO_RadioLogo[]  = { "images\radio\OriginLogo.paa", "images\radio\KHRLogo.paa", "images\radio\PulseLogo.paa", "images\radio\ClassicoLogo.paa", "images\radio\AnarchyLogo.paa" };

        // Malden Radio stream stations: a non-empty mount turns that dial slot into a STREAM
        // station (audio via the optional @MaldenRadio addon; vanilla clients get the promo loop).
        // Mount must match a liquidsoap/icecast mount in radio/radio.liq. "" = packed station.
        // Mounts and labels must never contain the | character (the broadcast wire format splits on it).
        AUTORADIO_RadioStream[] = { "origin", "khr", "pulse", "classico", "anarchy" };
        AUTORADIO_StreamLabel[] = { "ORIGIN FM", "KHR", "PULSE", "CLASSICO", "ANARCHY" };
        AUTORADIO_PromoLen = 64;   // seconds; MUST match the packed promo ogg's real length (Task 7)

        // 01 Origin
        AUTORADIO_Radio01[]      = {};
        AUTORADIO_Radio01Name[]  = {};
        AUTORADIO_Radio01Lengh[] = {};

        // 02 KHR
        AUTORADIO_Radio02[]      = {};
        AUTORADIO_Radio02Name[]  = {};
        AUTORADIO_Radio02Lengh[] = {};

        // 03 Pulse
        AUTORADIO_Radio03[]      = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio03Name[]  = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio03Lengh[] = {};   // moved to the stream backend 2026-08-02

        // 04 Classico (classical)
        AUTORADIO_Radio04[]      = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio04Name[]  = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio04Lengh[] = {};   // moved to the stream backend 2026-08-02

        // 05 Anarchy
        AUTORADIO_Radio05[]      = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio05Name[]  = {};   // moved to the stream backend 2026-08-02
        AUTORADIO_Radio05Lengh[] = {};   // moved to the stream backend 2026-08-02
};};
