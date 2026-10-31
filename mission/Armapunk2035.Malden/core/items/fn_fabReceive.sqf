if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_jobs", [], [[]]]];
/*
    AP_fnc_fabReceive -- the server's push of a house's printer states.

    Row: [printerId, tier, slots, [[jobId, recipe, qty, remainingSeconds, ready], ...]]

    DISPLAY DATA ONLY. `remaining` is a snapshot taken when the server built the row and `ready` is
    its answer at that instant -- neither is re-derived here and neither is trusted on the way back.
    Editing this array gets a refusal from APS_fnc_fabSRV, which recomputes both from the database
    on every collect, and collects by printer id rather than by anything sent from here.
*/
AP_fabJobs = _jobs;
AP_fabListReady = true;
if (!isNull (findDisplay 1810)) then { [] call AP_fnc_fabJobFill; };
// deck app: same push, second consumer. The deck rebuilds its whole payload so
// the job panel and the have-counts move together.
if (!isNull (findDisplay 937500)) then {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "fab", (["data"] call AP_fnc_deckFab)] call webui_fnc_push; };
};
