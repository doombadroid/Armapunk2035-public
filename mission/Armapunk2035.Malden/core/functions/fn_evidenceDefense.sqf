if !(canSuspend) exitWith {_this spawn AP_fnc_evidenceDefense;};
if !(AP_effSide isEqualTo civilian) exitWith {};
private _armoryFencePoly = AP_eviFencePoly;
while {((vehicle player) inArea evidenceTrigger) && (alive player)}
do {if ((SRV_evidence_status select 1) && (player inArea evidenceTrigger) && (position player inPolygon _armoryFencePoly)) then {
        if (((vehicle player) isKindOf "Air") && ((currentPilot(vehicle player)) isEqualTo player)) then {
            titleText["You are about to be shot down by the anti-air defense system! Leave now!", "PLAIN"];
            systemChat "You are about to be shot down by the anti-air defense system! Leave now!";
            uiSleep 5;
            if ((player inArea evidenceTrigger) && (SRV_evidence_status select 1)) then {[
                    [20893.7, 19227.5, 40.3462], "M_Titan_AA_static", 105, vehicle player, 600] spawn AP_fnc_fireMissile;};} else {
            titleText["You are about to be electrocuted by the electric fence! Leave now!", "PLAIN"];
            uiSleep 3;
            while {
                ((player inArea evidenceTrigger) && (SRV_evidence_status select 1) && (alive player) && (position player inPolygon _armoryFencePoly))
            }
            do {if (!(player getVariable["AP_downed", false]) && !(player getVariable["AP_restrained", false])) then {
                    PlaySound "electricity_loop";
                    player setUnconscious true;
                    [] spawn {uiSleep 2;
                        if (userInputDisabled) then {disableUserInput false;
                            uiSleep 0.1;
                            disableUserInput true;};};
                    private _hndlBlur = ppEffectCreate["DynamicBlur", 250];
                    _hndlBlur ppEffectEnable true;
                    _hndlBlur ppEffectAdjust[1];
                    _hndlBlur ppEffectCommit 0;
                    private _hndlBlack = ppEffectCreate["colorCorrections", 1000];
                    _hndlBlack ppEffectEnable true;
                    _hndlBlack ppEffectAdjust[1.0, 1.0, 0.0, [0, 0, 0, 0.9], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 0.0]];
                    _hndlBlack ppEffectCommit 0;
                    private _effects = true;
                    private _eff1 = 5;
                    private _eff2 = 0.9;
                    uiSleep 5;
                    waitUntil {!(player getVariable["AP_downed", false])};
                    disableUserInput false;
                    disableUserInput true;
                    disableUserInput false;
                    while {_effects}
                    do {_eff1 = _eff1 - 0.025;
                        _eff2 = _eff2 - 0.0045;
                        _hndlBlur ppEffectAdjust[_eff1];
                        _hndlBlur ppEffectCommit 0;
                        _hndlBlack ppEffectAdjust[1.0, 1.0, 0.0, [0, 0, 0, _eff2], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 0.0]];
                        _hndlBlack ppEffectCommit 0;
                        uiSleep 0.01;
                        _effects = !(_eff2 <= 0);}; ppEffectDestroy _hndlBlur;
                    ppEffectDestroy _hndlBlack;
                    player setUnconscious false;
                    disableUserInput false;
                    private _stance =
                    if (stance player isEqualTo "STAND") then {"AidlPercMstpSnonWnonDnon_G01"} else {"AmovPpneMstpSnonWnonDnon"};
                    player playMoveNow _stance;};
                uiSleep 10;};};};
    uiSleep 0.5;};