/*
    APS_fnc_fedRadarSRV -- sabotaging the island's air defences by blowing the radar tower.

    Four demo charges go on the four corners of the tower's pad. Any order; the FOURTH one arms a
    three-minute fuse, tells the police the system is being tampered with, and cannot be stopped
    (owner 2026-07-27: no defusing -- the alert is a call to defend the island, not a chance to
    prevent the sabotage). At zero the four charges detonate for real, the tower is destroyed, the
    MaxSec is told the defences are down, and AP_fedAirDefense goes false, which is all
    APS_fnc_fedAirDefenseSRV reads to stop engaging aircraft.

    Client entry:  [[_index], "APS_fnc_fedRadarSRV", 2, false] spawn AP_fnc_MP   (see
    core/actions/fn_fedRadarCharge.sqf). The server re-derives the caller from remoteExecutedOwner
    and re-checks his distance to the point he claims -- the CfgRE whitelist makes this callable by
    any client with arbitrary arguments, so nothing it is told may be trusted (model: fn_chopShopSell).

    STATE  SRV_fedRadar = [[p1, p2, p3, p4], armed, blownAt]  -- publicVariable, JIP reads it too.

    THE TOWER is not ours: nothing sits at this pad in mission.sqm or in allLocalMapEntities, so it
    belongs to Malden's terrain. It is resolved at boot by proximity and logged (owner's call), so
    the class can be confirmed from the RPT and hardcoded later if the search ever picks wrong.

    TODO -- COP REPAIR (owner 2026-07-27, deliberately NOT built yet): MaxSec should be able to
    bring the tower back up, but only 10 minutes after the last federal event resolves, and none of
    Malden's federal events are wired yet. Until that exists a blown tower stays blown for the
    session. See TODO.md.
*/
if (!isServer) exitWith {};

AP_fedRadarPoints = [[9642.87, 3317.16, 0.47], [9628.13, 3317.01, 0.47],
                      [9628.33, 3302.54, 0.47], [9642.84, 3303.18, 0.47]];
publicVariable "AP_fedRadarPoints";
if (isNil "SRV_fedRadar") then {
    SRV_fedRadar = [[false, false, false, false], false, -1];
    publicVariable "SRV_fedRadar";
};

private _fuse    = 180;      // three minutes
private _placeR  = 8;        // how far off the point the server tolerates (the client asks for 3)
private _blastR  = 60;       // charges live here; the tower is found within this of the pad centre

// ---- find the tower once, and say what was found so it can be confirmed from the log
if (isNil "AP_fedRadarTower" || {isNull (missionNamespace getVariable ["AP_fedRadarTower", objNull])}) then {
    private _c = [0, 0, 0];
    { _c = _c vectorAdd _x; } forEach AP_fedRadarPoints;
    _c = _c vectorMultiply (1 / (count AP_fedRadarPoints));
    private _near = nearestObjects [_c, [], _blastR];
    diag_log format ["[LooneyBin][fedRadar] pad centre %1 -- %2 object(s) within %3 m:", _c, count _near, _blastR];
    {
        diag_log format ["[LooneyBin][fedRadar]    %1 m  %2  (model %3)",
            (_c distance2D _x) toFixed 1, typeOf _x, getModelInfo _x param [0, "?"]];
    } forEach (_near select [0, 12]);
    // CONFIRMED 2026-07-27 from the boot log: Land_TTowerBig_1_F at [9635.35, 3309.95, 0.51], 0.2 m
    // from the pad centre -- a Malden terrain object, which is why nothing in the mission data matched.
    // The keyword search below stays as the fallback in case the terrain object is ever moved.
    private _key = ["ttowerbig", "radar", "antenna", "mast", "tower", "transmitter", "dish", "satellite"];
    private _hit = _near findIf {
        private _n = toLower ((getModelInfo _x) param [0, ""]) + toLower (typeOf _x);
        (_key findIf { _n find _x >= 0 }) > -1
    };
    AP_fedRadarTower = if (_hit > -1) then { _near select _hit } else { objNull };
    if (isNull AP_fedRadarTower) then {
        diag_log "[LooneyBin][fedRadar] NO tower matched -- the detonation will still fire the charges and drop the umbrella, but nothing will visibly collapse. Hardcode the class once it is known.";
    } else {
        diag_log format ["[LooneyBin][fedRadar] tower = %1 (model %2) at %3, %4 m from the pad centre",
            typeOf AP_fedRadarTower, (getModelInfo AP_fedRadarTower) param [0, "?"],
            getPosATL AP_fedRadarTower, (_c distance2D AP_fedRadarTower) toFixed 1];
    };
};

// ---- map: every blue thing that says "these defences are up" goes red, and the label reads Offline
if !(isFinal "AP_fnc_fedRadarMarkers") then {AP_fnc_fedRadarMarkers = compileFinal {
    params [["_online", true, [true]]];
    private _colour = if (_online) then { "ColorWEST" } else { "ColorRed" };
    // the 15 thin rectangles that ring the island, the radar site ring, and the six ! icons
    {
        _x setMarkerColor _colour;
    } forEach ["marker_125", "marker_126", "marker_128", "marker_129", "marker_130", "marker_131",
               "marker_132", "marker_133", "marker_134", "marker_135", "marker_137", "marker_138",
               "marker_139", "marker_140", "marker_141",
               // marker_157 is a border segment too, but it is numbered AFTER the ! icons rather than
               // with its neighbours -- which is exactly how it got missed and stayed blue on the map
               "marker_157",                                       // island border (15 + 1 segments)
               "marker_150",                                       // the radar site ring
               "marker_151", "marker_152", "marker_153", "marker_154", "marker_155", "marker_156"];
    "marker_151" setMarkerText (if (_online) then { "Air Defenses [Online]" } else { "Air Defenses [Offline]" });
}};

params [["_index", -1, [0]]];
if (_index < 0 || {_index > 3}) exitWith {};
if (SRV_fedRadar param [1, false]) exitWith {};                       // already armed, ignore

// ---- validate the caller: the whitelist lets any client call this with any number
private _owner = remoteExecutedOwner;
private _unit = objNull;
if (_owner isEqualTo 0) then { _unit = objNull } else {
    _unit = (allPlayers select { owner _x isEqualTo _owner }) param [0, objNull];
};
if (isNull _unit) exitWith { diag_log format ["[LooneyBin][fedRadar] REJECT: no unit for owner %1", _owner]; };
if !(side _unit isEqualTo civilian) exitWith { diag_log format ["[LooneyBin][fedRadar] REJECT: %1 is not civilian", name _unit]; };
if !(alive _unit) exitWith {};
private _pt = AP_fedRadarPoints select _index;
if ((_unit distance2D _pt) > _placeR) exitWith {
    diag_log format ["[LooneyBin][fedRadar] REJECT: %1 claimed point %2 from %3 m away",
        name _unit, _index + 1, (_unit distance2D _pt) toFixed 1];
};

private _placed = +(SRV_fedRadar select 0);
if (_placed select _index) exitWith {};                                // that corner already has one
_placed set [_index, true];
SRV_fedRadar set [0, _placed];
publicVariable "SRV_fedRadar";

private _charge = "DemoCharge_Remote_Ammo" createVehicle _pt;          // global: everyone sees the satchel
_charge setPosATL _pt;
_charge setVariable ["AP_fedRadarCharge", _index, true];
diag_log format ["[LooneyBin][fedRadar] charge %1/4 placed by %2 at %3", ({_x} count _placed), name _unit, _pt];

if ((({_x} count _placed) < 4)) exitWith {
    [[0, format ["Demo charge %1 of 4 placed on the radar tower.", ({_x} count _placed)]],
     "AP_fnc_broadcast", _unit, false, false] spawn AP_fnc_MP;
};

// ---- fourth charge: arm, warn the island, three minutes, then blow it
SRV_fedRadar set [1, true];
publicVariable "SRV_fedRadar";
[[0, "ALERT: the island's air defence radar is being tampered with -- charges are on the tower!"],
 "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][fedRadar] ARMED by %1 -- %2 s fuse", name _unit, _fuse];

[_fuse] spawn {
    params ["_fuse"];

    // ALARM for the length of the fuse. say3D is a LOCAL effect, so the server playing it would be
    // heard by nobody -- it has to be pushed to the clients in earshot (AP_fnc_playSound, already
    // whitelisted server->client). bankalarm.ogg is 6.6 s, so repeat on that beat and skip the last
    // repeat if the blast would cut it off mid-wail.
    [_fuse] spawn {
        params ["_fuse"];
        private _end = time + _fuse;
        private _pad = [9635.5, 3310.0, 0];
        while {time < _end && {(SRV_fedRadar param [2, -1]) < 0}} do {
            private _src = missionNamespace getVariable ["AP_fedRadarTower", objNull];
            if (isNull _src) then { _src = (nearestObjects [_pad, ["DemoCharge_Remote_Ammo"], 60]) param [0, objNull]; };
            if (!isNull _src) then {
                private _hear = allPlayers select { (_x distance2D _pad) < 900 };
                if (_hear isNotEqualTo []) then {
                    [[_src, "bankalarm", false, 800], "AP_fnc_playSound", _hear, false] spawn AP_fnc_MP;
                };
            };
            if ((_end - time) < 7) exitWith {};      // no half-played wail over the explosion
            uiSleep 6.6;
        };
    };

    uiSleep _fuse;
    // no defusing by design, so nothing to re-check here except that the server still agrees it is armed
    if !(SRV_fedRadar param [1, false]) exitWith {};

    {
        private _c = _x;
        if (!isNull _c) then { _c setDamage 1; };
        uiSleep 0.2;
    } forEach (nearestObjects [[9635.5, 3310.0, 0], ["DemoCharge_Remote_Ammo"], 60]);

    private _tower = missionNamespace getVariable ["AP_fedRadarTower", objNull];
    if (!isNull _tower) then {
        _tower setDamage 1;
        diag_log format ["[LooneyBin][fedRadar] tower %1 destroyed (damage now %2)", typeOf _tower, damage _tower];
    } else {
        diag_log "[LooneyBin][fedRadar] no tower object to destroy -- umbrella still going down";
    };

    AP_fedAirDefense = false;                                        // the AA loop reads this every pass
    publicVariable "AP_fedAirDefense";
    SRV_fedRadar set [2, serverTime];
    publicVariable "SRV_fedRadar";
    [false] call AP_fnc_fedRadarMarkers;

    [[0, "The island's AIR DEFENCES ARE DOWN -- the radar tower has been destroyed."],
     "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
    diag_log "[LooneyBin][fedRadar] AIR DEFENCES OFFLINE";
};
