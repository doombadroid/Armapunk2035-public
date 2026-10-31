// DEV INSTRUMENTATION -- 2026-07-27. Delete this file and its execVM in initPlayerLocal before any live pack.
//
// Round 2: the 50km hold now holds, but the relog teleport lands the player correctly and then something
// moves them ~500m UP 0.4s later and they fall from there. This samples fast enough to catch the jump and
// records enough state to identify it: ASL and ATL (a pure terrain-streaming artefact moves one and not the
// other), the terrain height under the player, and the unit's netId (so a unit swap is distinguishable from
// a teleport of the same unit).
if (!hasInterface) exitWith {};

[] spawn {
    private _t0 = diag_tickTime;
    private _lastZ = -1;
    private _lastId = "";
    private _lastBeat = -1;

    diag_log format ["[SIMPROBE] start t=0.00 player=%1 typeOf=%2 netId=%3 posASL=%4 sim=%5",
        player, typeOf player, netId player, getPosASL player, simulationEnabled player];

    while { (diag_tickTime - _t0) < 90 } do {
        private _t    = diag_tickTime - _t0;
        private _asl  = (getPosASL player) select 2;
        private _atl  = (getPosATL player) select 2;
        private _pos  = getPosASL player;
        private _terr = getTerrainHeightASL [_pos select 0, _pos select 1];
        private _id   = netId player;
        private _sim  = simulationEnabled player;

        // a jump is the event we are hunting -- log it loudly with both frames
        if (_lastZ > -1 && {abs (_asl - _lastZ) > 20}) then {
            diag_log format ["[SIMPROBE] *** JUMP t=%1 %2 -> %3 (%4m) sim=%5 local=%6 atl=%7 terrain=%8 netId=%9 (was %10) anim=%11",
                _t toFixed 2, _lastZ toFixed 1, _asl toFixed 1, (_asl - _lastZ) toFixed 1,
                _sim, local player, _atl toFixed 1, _terr toFixed 1, _id, _lastId, animationState player];
        };
        if (_id != _lastId && {_lastId != ""}) then {
            diag_log format ["[SIMPROBE] *** UNIT SWAP t=%1 %2 -> %3", _t toFixed 2, _lastId, _id];
        };

        if ((floor _t) != _lastBeat) then {
            diag_log format ["[SIMPROBE] t=%1 sim=%2 local=%11 asl=%3 atl=%4 terrain=%5 vel=%6 dlg=%7 ses=%8 alive=%9 anim=%10",
                _t toFixed 2, _sim, _asl toFixed 1, _atl toFixed 1, _terr toFixed 1,
                (velocity player) select 2, !(isNull (findDisplay 38500)),
                missionNamespace getVariable ["AP_session_completed", false],
                alive player, animationState player, local player];
            _lastBeat = floor _t;
        };

        _lastZ = _asl;
        _lastId = _id;
        uiSleep 0.05;
    };
    diag_log format ["[SIMPROBE] end sim=%1 asl=%2", simulationEnabled player, (getPosASL player) select 2];
};
