/*
    AP_fnc_invisBag  (owner 2026-07-06) -- make the worn backpack INVISIBLE the robust way: EMPTY the texture on
    the backpackContainer (setObjectTexture[_,""]) instead of hideObject-ing the pack.

    Lesson from a reference deobf mission: an EMPTY texture ("") -- NOT a transparent .paa -- renders the selection
    invisible, and unlike hideObjectGlobal it isn't un-done by the engine on respawn / vehicle enter-exit / reconnect
    (which is why the old hideObject approach needed re-hiding in 6 places + a reconnect timer). backpackContainer is
    the rendered pack object; clearing selections 0..2 covers single- and multi-selection packs. Switching to any
    real pack/skin resets it (new object = default texture), so no un-apply is needed.

    Call:  [_global] call AP_fnc_invisBag   -- _global true = everyone sees it gone (setObjectTextureGlobal),
                                                 false = local only (shop preview).
*/
params [["_global", true, [true]]];
if (backpack player isEqualTo "") exitWith {};
private _bc = backpackContainer player;
if (isNull _bc) exitWith {};
if (_global) then {{ _bc setObjectTextureGlobal [_x, ""]; } forEach [0, 1, 2];} else {{ _bc setObjectTexture [_x, ""]; } forEach [0, 1, 2];
};
