params[["_required", 1, [1]], ["_ignoreFed", false, [false]], ["_showMessage", true, [false]], ["_ignoreTenure", false, [false]]];
// owner 2026-06-17 (#333): beta zero-cop waiver TURNED OFF. AP_betaZeroCops now defaults FALSE (matching the
// server-side checks in fedAlarm/bankDrillVault/jewelryEmporiumSRV + the publicVariable set in init.sqf:535),
// so cop requirements ENFORCE even on a JIP client whose flag hasn't synced. Only an explicit =true (none ship
// now) re-waives. The whole heist suite (bank/fed/prison/evidence/convoy/jewelry/Loony Bin) gates through here.
if (missionNamespace getVariable ["AP_betaZeroCops", false]) exitWith { true };
// owner 2026-07-03: floor EVERY heist/fed/prison-break cop requirement at 1 online officer. Several callers
// pass 0 (fed dome/gate/safe [0,true]) or a server-data field left at 0 for beta; this makes at-least-1-cop
// the universal minimum without touching each call site. The AP_betaZeroCops admin override above still waives.
_required = _required max 1;
private _initRequired = _required;
// owner 2026-07-28 (parity): count what the SERVER counts. This line was `west countSide allPlayers` -- every
// cop online, raw -- but the server-side half of the same gate counts AP_fnc_tenuredCops: only cops that have
// been continuously on west for AP_copTenureReq (300s), the anti-soft-log rule from #496. A cop who had just
// come on duty counted here and not there, so on the Jewelry Emporium the client let the drill start and the
// server refused the job AFTER the player had stood through the whole 10-second bar (fn_jewelryEmporiumSRV:30).
// The tenured count is server-only state (AP_copDutySince), so the copTenure wheel job publishes it every 20s
// (server/AP_server/init.sqf) and this reads that.
// FALLBACK, for a client whose copy has not arrived yet (the wheel's first pass is up to 20s after boot):
// getVariable with a default never raises, and -1 is outside the range the server can ever publish, so both a
// missing value and a wrong-typed one leave _cops at exactly today's raw count. That fallback is the OLD
// behaviour, not a pass: it is never stricter than before, and it cannot waive the check the way defaulting to
// a large number or to `true` would.
// Shared gate -- this function fronts every heist (bank/fed/prison/evidence/convoy/jewelry/Loony Bin/gas), so
// note the direction: the tenured count is by definition <= the raw one AT THE MOMENT IT IS COMPUTED, so no
// caller can be ALLOWED something the server would refuse.
// owner 2026-07-28: _ignoreTenure OPT-OUT. Parity was the whole point of the tenure count -- stop the client
// letting a job start that the server is about to refuse. A caller with NO server-side cop gate to reach
// parity with is not diverging from anything, so the tenure rule only makes it harder for no gain.
// TWO callers are in that position and pass _ignoreTenure true: the gas station (fn_robStoreAction, whose
// APS_fnc_srvRobStore checks no cop count) and the evidence armory (fn_evidenceSystems mode 0). Those two --
// and ONLY those two -- go back to counting every cop online, which is what they did before the parity work.
// owner 2026-07-28, UPDATED: the PRISON BREAK was a third one and is no longer. APS_fnc_handlePrisonBreak now
// carries the tenuredCops + AP_betaZeroCops gate the sibling heists carry, so fn_doPrisonBreak's two call
// sites have gone back to the strict default -- keeping them opted out would have had the client count raw
// bodies while the server counted tenured ones, i.e. green-light a job, apply the wanted charge and run the
// 30-second upload before the server refused it. Whenever a server-side cop gate is ADDED to one of the two
// remaining opt-outs, its _ignoreTenure must come off in the same commit for the same reason.
// Default FALSE (= tenure ENFORCED), matching _ignoreFed's shape: a caller that says nothing, including any
// caller added later, keeps the strict behaviour. A flag defaulting the other way would quietly un-do the
// parity fix for every future call site, which is exactly the failure this gate exists to prevent.
//   `min`, not plain assignment -- 2026-07-28, caught in review. The published count is refreshed by a 20 s
//   wheel job, so between passes it can be STALE-HIGH against the live one: three cops are tenured, two
//   disconnect, and for up to 20 s the raw count reads 1 while AP_tenuredCopCount still reads 3. A plain
//   assignment would have REPLACED a correct low number with a stale high one and opened the gate the server
//   is about to refuse -- the exact divergence this change exists to close, running the other way. Taking the
//   lower of the two makes the direction genuinely one-way in every window, stale or fresh.
// Armapunk 2035 (faction rework PR6): once AP_dutyEnabled is on, `west countSide allPlayers` stops being
// even loosely the number of officers. It counts every unit the ENGINE puts on side west, which after the
// flip includes anyone who joined the published duty group netId without a roster entry, and excludes a
// rostered officer whose side flip has not landed yet. The server's own gates count APS_fnc_isDutyCop, i.e.
// the ROSTER, so AP_dutyCopCount -- republished by APS_fnc_dutySRV on every roster mutation, not on a wheel
// -- is the matching number and it is the one to compare against.
// `min` for the same reason the tenured line below uses it, and it is not redundant with that one: the two
// numbers can each be stale-high against the other in different windows (AP_dutyCopCount counts UNACKED
// entries; the raw count still sees an old-slot west player the roster does not). Taking the lowest
// available number keeps this gate one-way in every window -- the client can be stricter than the server
// and never more permissive, which is the whole point of counting what the server counts.
// NOT under _ignoreTenure, deliberately, and it is the one place this differs from the line below. That
// opt-out exists because the tenure RULE has no server-side counterpart at those two call sites, so
// applying it there is a restriction for no parity gain. This is not a rule, it is a better COUNT: with
// the flag on, the raw west total includes anyone who joined the published group netId, and no caller
// wants a self-joiner counted as an officer. The one cost this carried was the mixed transition state --
// flag on while old west mission slots still existed -- where a serving old-slot cop was invisible to the
// roster and this read lower than the bodies online. PR7 retired that cost by construction: the slots are
// gone, so every officer on side west got there through the roster and the two numbers describe the same
// people. Every server heist gate has counted this way since PR5 wrapped them in APS_fnc_isDutyCop, so the
// client agrees with the server rather than diverging from it.
private _cops = west countSide allPlayers;
if (missionNamespace getVariable ["AP_dutyEnabled", false]) then {
    private _rostered = missionNamespace getVariable ["AP_dutyCopCount", -1];
    if ((_rostered isEqualType 0) && {_rostered >= 0}) then { _cops = _cops min _rostered; };
};
private _tenured = missionNamespace getVariable ["AP_tenuredCopCount", -1];
if (!_ignoreTenure && {(_tenured isEqualType 0) && {_tenured >= 0}}) then { _cops = _cops min _tenured; };
private _message = "You";
if (_initRequired < _required) then {_message = "Because of crimes already in progress, you"};
if (((_cops < _required) && !(AP_fed_robbed select 0)) && _showMessage) then {
    [format["%1 cannot initiate this crime with fewer than %2 police officers online. An additional %3 officers are required.", _message, _required, _required - _cops], "basic"] spawn AP_fnc_handleMessage;
};
(_cops >= _required)