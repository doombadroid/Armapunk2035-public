/*
    fn_phoneGlobals.sqf — the four always-present phone apps.

    These are not in AP_phone_buttons: the deck pins
    them to their own row, and the web deck pins them to its left rail. Both need
    the same name/icon/action/gate/tooltip tuples, so they live here rather than
    being written out twice and drifting.

    Usage:  private _globals = call AP_fnc_phoneGlobals;
*/

[
    ["Sync",      "",      "[] call AP_fnc_syncData",           { true }, "Update server with your current character data"],
    ["Money",     "",     "[""Money""] call AP_fnc_deckOpenApp",             { true }, "Trade your cash on hand"],
    ["Message",   "",   "[""Message""] call AP_fnc_deckOpenApp",         { true }, "Send text messages to other players"],
    ["Inventory", "", "[""Inventory""] call AP_fnc_deckOpenApp", { true }, "View your virtual inventory"]
]
