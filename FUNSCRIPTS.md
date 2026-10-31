# FUNSCRIPTS.md

Debug-console gags + toys. Paste into the in-game debug console → **LOCAL EXEC** (the gauge button).
These are NOT wired into the mission — pure copy-paste fun. Nothing here ships in a PBO.

---

## Strider Boat Mode  🚙🌊  (a.k.a. "hilariously broken")

Fakes buoyancy + propulsion so a land vehicle screams across water speedboat-fast.
Pins the hull to the surface and drives it via `setVelocity` in your facing direction —
works even with the engine stalled in water. **W/S** throttle, **A/D** steer. Includes a
live debug readout (LOCAL / water / speed) so you can see when it inevitably misbehaves.

```sqf
STRIDER_BOAT = true;
STRIDER_BOAT_SPD = 40;   // m/s. Set to 3000 for orbital reentry (results may vary / be hilarious).
[] spawn {
    while { STRIDER_BOAT } do {
        private _v = vehicle player;
        if (_v != player && {driver _v isEqualTo player}) then {
            private _water = surfaceIsWater (getPosASL _v);
            private _thr  = (inputAction "MoveForward") - (inputAction "MoveBack");
            private _turn = (inputAction "TurnRight")  - (inputAction "TurnLeft");
            if (abs _turn > 0.01) then { _v setDir ((getDir _v) + _turn * 3) };
            private _dir = vectorDir _v;
            private _vz  = velocity _v select 2;
            if (_water) then { _v setVectorUp [0,0,1]; _vz = (0.5 - ((getPosASL _v) select 2)) * 5 };
            if (abs _thr > 0.01 || _water) then {
                _v setVelocity [(_dir select 0)*STRIDER_BOAT_SPD*_thr, (_dir select 1)*STRIDER_BOAT_SPD*_thr, _vz];
            };
            hintSilent format ["BOAT spd:%1  LOCAL:%2  water:%3  W:%4  going:%5 m/s", STRIDER_BOAT_SPD, local _v, _water, (round(_thr*10))/10, round speed _v];
        };
        sleep 0.03;
    };
    hint "boat off";
};
```

**Stop:** `STRIDER_BOAT = false;`
**Faster (live):** `STRIDER_BOAT_SPD = 80;`

**Known chaos:** high speeds launch/barrel-roll the hull; `LOCAL:false` means the vehicle is
sim'd server-side and client `setVelocity` no-ops (needs a different route on the live server).
The jankier the better — that's the point.

---
