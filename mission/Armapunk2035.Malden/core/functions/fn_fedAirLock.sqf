/*
    AP_fnc_fedAirLock -- "the Fed battery has you", shown to the pilot the server is about to shoot.

    Called from APS_fnc_fedAirDefenseSRV (server -> this client only, CfgRE allowedTargets = 1). It is
    a warning and nothing else: the decision to fire, and the missiles themselves, are the server's,
    so ignoring or blocking this changes nothing except that you get no siren.

    Four seconds, and climbing above 120 m or leaving the ring in that time breaks the lock -- so the
    text says exactly that. Anything slower than about 90 km/h inside the ring counts as an approach
    no matter how high you are.

    Sound: the fork has no missile-lock tone (fn_fireMissile still plays "missileLocking", which is
    not in CfgSounds and has been silent here since the fork). AP_DroneSiren is a real entry and
    reads as an air-defence alarm; swap it the day a proper lock beep is baked.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
if (!hasInterface) exitWith {};
if (isNil "AP_fedAirLockLast") then { AP_fedAirLockLast = -100000; };
if ((time - AP_fedAirLockLast) < 6) exitWith {};        // one siren per engagement, not per packet
AP_fedAirLockLast = time;

titleText ["FED AIR DEFENCE HAS LOCKED YOU\nCLIMB ABOVE 120 m OR LEAVE THE RING", "PLAIN", 0.3];
systemChat "Federal Reserve air defence: LOCKED. Climb above 120 m or clear the ring -- you have four seconds.";
playSound "AP_DroneSiren";
[] spawn {
    for "_i" from 1 to 3 do {
        uiSleep 1.1;
        playSound "AP_DroneSiren";
    };
};
