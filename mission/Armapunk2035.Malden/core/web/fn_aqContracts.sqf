/*
    fn_aqContracts.sqf  (AP_fnc_aqContracts) -- the CONTRACTS picker, owner 2026-09-05.
    Dialog: dialog\aq_contracts.hpp (AP_AqContracts, idd 941800).

    WHAT IT REPLACES. Every path to an ArmaQuest offer board used to be a scroll-wheel entry:
    ArmaQuest's shipped "addAction" driver on a spawned giver NPC, and -- because this mission
    wanted a no-walk-up option too -- six permanent "Cyberdeck: Contact X" self-actions armed on
    the player at boot by fn_aqDeckBootstrap/fn_aqDeckTrigger. The NPCs are gone (no giver declares
    `object` any more; see aq_content.hpp) and those two files are deleted, so this is now the only
    door to a board, and it is inside the phone where the rest of the deck's apps live.

    THE WHOLE JOB IS PICKING A GIVER. It does not fetch, cache or render offers: `aq_fnc_openOffers`
    already opens the journal on the chosen giver's Available tab, sets `aq_pendingGiver` so the
    journal's accept verb resolves to the right board, and asks the server for the rows. This file
    only decides which giver id that call receives, which is exactly what the removed scroll actions
    decided. Nothing about acceptance, prerequisites or board contents moves client-side here.

    ONE GIVER AT A TIME IS THE PAGE'S CONTRACT, NOT A SIMPLIFICATION. See aq_contracts.hpp's header:
    the vendored journal page replaces its whole Available list on each "offers" push and its accept
    verb carries no giver, so a merged all-givers board would hide five of six and could accept
    against the wrong one.

    ["open"]   from the deck's "Quest Log" app (AP_phone_buttons, core\init.sqf)
    ["show"]   OPEN button / double-click
*/
#define IDD_CONTRACTS  941800
#define IDC_GIVERS     941810
#define IDC_STATUS     941820

params [["_action", "open", [""]]];

if (_action isEqualTo "open") exitWith {
    if (!hasInterface) exitWith {};
    // aq_ready is preInit's verdict on the whole catalogue. With it false no giver is armed and
    // aq_fnc_openOffers refuses every id, so a picker would be a list of dead buttons -- say so
    // instead, and still offer the journal, which reads state the client already holds.
    private _armed = !isNil "aq_ready" && {aq_ready} && {!isNil "aq_idxGiver"};

    if (!createDialog "AP_AqContracts") exitWith {
        diag_log "[AP] aqContracts: createDialog AP_AqContracts failed -- is dialog\aq_contracts.hpp included in MasterHandler.h?";
    };
    private _disp = findDisplay IDD_CONTRACTS;
    private _lb = _disp displayCtrl IDC_GIVERS;
    lbClear _lb;

    // The journal first, because it is the entry that always works: it renders the quests this
    // client already holds and needs no giver and no server round trip.
    private _i = _lb lbAdd "My Journal";
    _lb lbSetData [_i, ""];
    _lb lbSetCurSel _i;

    if (_armed) then {
        // Sorted by display name so the list does not reorder itself between sessions -- `keys` on
        // a hashmap carries no ordering guarantee, and a picker whose rows move is a picker people
        // misclick.
        private _rows = [];
        {
            private _cfg = aq_idxGiver getOrDefault [_x, configNull];
            private _nm = if (isNull _cfg) then { "" } else { [_cfg >> "name"] call aq_fnc_text };
            if (_nm isEqualTo "") then { _nm = _x; };
            _rows pushBack [_nm, _x];
        } forEach (keys aq_idxGiver);
        _rows sort true;
        {
            _x params ["_nm", "_gid"];
            private _j = _lb lbAdd _nm;
            _lb lbSetData [_j, _gid];
        } forEach _rows;
    };

    (_disp displayCtrl IDC_STATUS) ctrlSetStructuredText parseText (
        if (_armed) then {
            "<t color='#8993a0'>Boards are shared and expire. What you see is what is left.</t>"
        } else {
            "<t color='#ff5a3c'>Contracts offline</t><t color='#8993a0'> -- the quest catalogue failed validation this boot; see the RPT.</t>"
        }
    );
};

if (_action isEqualTo "show") exitWith {
    private _disp = findDisplay IDD_CONTRACTS;
    if (isNull _disp) exitWith {};
    private _lb = _disp displayCtrl IDC_GIVERS;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith { ["Pick who you're calling first.", "basic"] spawn AP_fnc_handleMessage; };
    private _gid = _lb lbData _sel;

    // Close BEFORE opening the journal. Both are dialogs, and aq_fnc_openOffers' first act is
    // createDialog "AQ_Journal" -- leaving this one up would stack two dialogs and leave the picker
    // behind the journal to be found again on close. maldenPicker.hpp's opener does the same thing
    // for the same reason.
    closeDialog 0;

    // A frame between the close and the open: createDialog in the same frame as closeDialog is the
    // classic way to get a dialog that never appears, because the close has not been processed yet.
    [_gid] spawn {
        params ["_gid"];
        uiSleep 0.05;
        // Through AP_fnc_aqJournalOpen rather than aq_fnc_journal directly, so there stays exactly
        // one place in this mission that knows how to open the journal cold.
        if (_gid isEqualTo "") exitWith { [] call AP_fnc_aqJournalOpen; };
        // openOffers re-validates the id against aq_idxGiver and refuses an unknown one, so a
        // stale row here fails loudly in the RPT rather than opening an empty board.
        [_gid] call aq_fnc_openOffers;
    };
};
