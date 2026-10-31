/*
    APS_fnc_handleTimer  (LooneyBin -- implemented from stub 2026-06-09)
    Evidence-lockup federal event state machine. Client (core/actions/fn_evidenceSystems.sqf) sends:
      [0, 300]  civ uploaded the virus  -> laptop status 2 (virus running); after 300s defenses DOWN
                  (SRV_evidence_status[1]=false, laptop status 0), attack-clock stamped
      [1, 0]    cop repaired the system -> defenses UP (status[1]=true), laptop status 1
      [2, time] civ demo charge planted on the dome -> after `time`s (15-25 min) the dome BLOWS OPEN
                  (AP_evidenceOpen) unless a cop secured it first
      [3, 180]  cop securing the lockup -> after 180s dome closed + bomb defused + event reset
    SRV_evidence_status = [hasEvidence, defensesUp, unused, lastAttackTime, copsRequired]  (init.sqf)
    The evidence laptop object is found/created + published as `evidenceLaptop` by init.sqf.
*/
params [["_mode", -1, [0]], ["_seconds", 0, [0]]];
if (isNil "SRV_evidence_status") then { SRV_evidence_status = [false, true, 0, -1800, 2]; publicVariable "SRV_evidence_status"; };
private _laptop = missionNamespace getVariable ["evidenceLaptop", objNull];
private _dome   = nearestObject [[20898.6, 19221.7, 0], "Land_Dome_Big_F"];

switch (_mode) do {case 0: {   // virus uploaded -> countdown to defenses-down
        // owner 2026-06-16 (#302): server-authoritative one-federal-event-at-a-time gate (client check has a window).
        if (["evidence"] call APS_fnc_fedEventActive) exitWith {
            diag_log "[LooneyBin][evidence] virus upload BLOCKED -- another federal event already active (#302 server gate)";};
        if (!isNull _laptop) then { _laptop setVariable ["AP_laptopstatus", 2, true]; };
        SRV_evidence_status set [3, serverTime];   // attack clock (30-min lockout read client-side)
        publicVariable "SRV_evidence_status";
        [_seconds, _laptop] spawn {params ["_s", "_laptop"];
            uiSleep _s;
            // a cop repair (mode 1) flips the laptop back to 1 -> abort the takedown
            if (!isNull _laptop && {(_laptop getVariable ["AP_laptopstatus", 1]) isEqualTo 2}) then {
                _laptop setVariable ["AP_laptopstatus", 0, true];
                SRV_evidence_status set [1, false];
                publicVariable "SRV_evidence_status";
                [[0, "The Evidence Lockup defense systems are DOWN!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};};};
    case 1: {   // cop repair -> defenses back up
        if (!isNull _laptop) then { _laptop setVariable ["AP_laptopstatus", 1, true]; };
        SRV_evidence_status set [1, true];
        publicVariable "SRV_evidence_status";};
    case 2: {   // demo charge on the dome -> long fuse, then breach (unless secured meanwhile)
        if (isNull _dome) exitWith {};
        _dome setVariable ["AP_bombPlanted", true, true];
        [_seconds, _dome] spawn {params ["_s", "_dome"];
            uiSleep _s;
            if !(_dome getVariable ["AP_bombPlanted", false]) exitWith {};   // defused by a cop secure
            _dome setVariable ["AP_bombPlanted", false, true];
            _dome setVariable ["AP_evidenceOpen", true, true];
            _dome setVariable ["bis_disabled_Door_3", 0, true];
            _dome animate ["door_3_rot", 1];
            private _boom = "ModuleExplosive_DemoCharge_F" createVehicle (getPosATL _dome);
            uiSleep 0.5; _boom setDamage 1;
            [[0, "The Evidence Lockup has been BREACHED!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        };};
    case 3: {   // cop secure -> close + defuse + reset after _seconds
        if (isNull _dome) exitWith {};
        [_seconds, _dome] spawn {params ["_s", "_dome"];
            uiSleep _s;
            _dome setVariable ["AP_bombPlanted", false, true];
            _dome setVariable ["AP_evidenceOpen", false, true];
            _dome setVariable ["AP_vaultBreached", false, true];   // vault re-sealable next event
            _dome setVariable ["bis_disabled_Door_3", 1, true];
            _dome animate ["door_3_rot", 0];
        };};};
