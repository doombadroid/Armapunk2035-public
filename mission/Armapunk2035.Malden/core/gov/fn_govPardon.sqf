params[["_caseType", "", [""]], "_govData"];
switch (_caseType) do {case ("recievePardon"): {
            _govData params[["_governorObj", objNull, [objNull]], ["_governorPID", "", [""]], ["_governorName", "", [""]]];
            if ((isNull _governorObj) || (_governorPID isNotEqualTo(SRV_governorData param[0, "GovUID"])) || (_governorName isEqualTo "")) exitWith {};
            private _pardonUID = getPlayerUID player;
            private _dialogQuestion = [format["Do you wish to be pardoned by Governor %1 of %2?", _governorName, worldName], "Governor Pardon", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_dialogQuestion) exitWith {[
                    ["pardonDoneBackToGov", [profileName, getPlayerUID player, (A_stats_crimes param[0, 0]), true]], "AP_fnc_govPardon", _governorObj] call AP_fnc_MP;
            }; [
                ["-PARDON-", _governorObj, _governorName, format["gov pardoned %1 (%2) with a bounty of $%3.", profileName, (getPlayerUID player), (A_stats_crimes param[0, 0])]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            [
                ["pardonDoneBackToGov", [profileName, getPlayerUID player, (A_stats_crimes param[0, 0]), false]], "AP_fnc_govPardon", _governorObj] call AP_fnc_MP;
            [
                [0, format["%1 has been pardoned by Governor %2", [profileName] call AP_fnc_cleanName, [_governorName] call AP_fnc_cleanName]], "AP_fnc_broadcast", -2] call AP_fnc_MP;
            [[_pardonUID], "APS_fnc_wantedPardon", 2] call AP_fnc_MP;
            ["pardonedbygov", 1] call AP_fnc_statArrUpdate;
            private _bountyHunters = allPlayers select {!(((_x getVariable["AP_myBounties", []]) findIf {_pardonUID in _x}) isEqualTo - 1)
            };
            if !(_bountyHunters isEqualTo[]) then {[_pardonUID, false] remoteExec["AP_fnc_removeBounty", _bountyHunters];};
        }; case ("pardonDoneBackToGov"): {
                _govData params[["_pardonName", "", [""]], ["_pardonUID", "", [""]], ["_pardonBounty", 0, [0]], ["_failed", false, [false]]];
                if (_failed) then {
                    [format["%1 has declined your pardon. You can now submit another pardon for another player!", _pardonName]] spawn AP_fnc_handleMessage;
                    AP_govClientData set[3, false];
                    [21] call AP_fnc_ClupdatePartial;} else {
                    [format["%1 has accepted your pardon. You now must wait until next restart to pardon another player!", _pardonName]] spawn AP_fnc_handleMessage;
                    AP_govClientData set[3, true];
                    [21] call AP_fnc_ClupdatePartial;};};};