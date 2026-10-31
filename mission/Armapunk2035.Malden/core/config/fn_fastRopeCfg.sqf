params [["_mode", "", [""]], ["_toFind", "", [""]]];
// FAST ROPE -- the airframe table and the envelope numbers, one place.
// Each row is [class, anchors], anchors being the two rope stations in MODEL space as
// [x, y]: +x is the right-hand side of the hull, -x the left, y is fore/aft. The Huron
// ropes off the tail ramp, so its pair sits nearly on centreline and 7 m aft instead of
// out the side doors.
private _airframes = [
    ["B_Heli_Light_01_F",            [[ 1.15,  0], [-1.15,  0]]],   // MH-9 Hummingbird
    ["C_Heli_Light_01_civil_F",      [[ 1.15,  0], [-1.15,  0]]],   // M-900
    ["O_Heli_Light_02_unarmed_F",    [[ 1.5,   0], [-1.5,   0]]],   // PO-30 Orca
    ["B_Heli_Transport_01_F",        [[ 1.6,   0], [-1.6,   0]]],   // UH-80 Ghost Hawk
    ["B_Heli_Transport_03_unarmed_F",[[ 0.8,  -7], [-0.8,  -7]]],   // CH-67 Huron (ramp)
    ["B_Heli_Transport_03_F",        [[ 0.8,  -7], [-0.8,  -7]]]    // CH-67 Huron, armed
];

private _return = switch (_mode) do {
    case "classes": {_airframes apply {_x select 0}};
    // Unknown class falls back to a generic side-door pair rather than raising -- the
    // caller has already gated on "classes", so this only matters if the two lists drift.
    case "anchors": {
        (_airframes param [_airframes findIf {(_x select 0) isEqualTo _toFind}, ["", [[1.15, 0], [-1.15, 0]]]]) select 1
    };
    case "minAltitude": {5};    // m ATL -- below this, just step out
    case "maxAltitude": {35};   // m ATL -- above this the rope does not reach
    case "maxSpeed": {15};      // km/h -- the pilot has to actually hold a hover
    case "descentRate": {6.25}; // m/s down the rope
    default {0};
};

_return
