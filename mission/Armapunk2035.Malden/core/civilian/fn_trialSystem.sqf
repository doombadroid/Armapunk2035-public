if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_caseType", "", [""]], ["_trialData", [], [[]]]];
if (_caseType isEqualTo "" || _trialData isEqualTo[]) exitWith {};
switch (_caseType) do {case "defendantRequestTrial": {_trialData params[["_defendant", objNull, [objNull]]];
            if ((A_stats_crimes select 57) >= 1) exitWith {
                ["You cannot request a trial while admin jailed.", "basic"] spawn AP_fnc_handleMessage;};
            if ((A_stats_crimes select 0) <= 25000) exitWith {
                ["You must have a bounty over $25,000 to request a trial", "basic"] spawn AP_fnc_handleMessage};
            if (profileNameSpace getVariable["AP_requestedTrial", false]) exitWith {
                ["You have already requested a trial!", "basic"] spawn AP_fnc_handleMessage};
            if (SRV_trialData select 4) exitWith {
                ["Another trial is already in process and the courts are at capacity. Try again shortly.", "basic"] spawn AP_fnc_handleMessage
            };
            if ((SRV_trialData select 0) isEqualTo player) exitWith {
                ["You currently already have a trial active!", "basic"] spawn AP_fnc_handleMessage};
            if !((SRV_trialData select 0) isEqualTo objNull) exitWith {
                ["Another trial is already in process. Try again shortly.", "basic"] spawn AP_fnc_handleMessage};
            if ((AP_jailReleaseTime - time) < 720) exitWith {
                ["You must have at least 12 minutes left of your serving time to request a trial", "basic"] spawn AP_fnc_handleMessage};
            if ((getPlayerUID player) in SRV_trialPreviousDefenders) exitWith {
                ["You have already requested a trial this server restart!", "basic"] spawn AP_fnc_handleMessage};
            profileNameSpace setVariable["AP_requestedTrial", true];
            ["Your trial request has been submitted. It may take as long as 5 minutes before you receive word concerning the trial.", "basic"] spawn AP_fnc_handleMessage;
            [["startTrial", [player, (A_stats_crimes select 0)]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;
        }; case "juryInviteToTrial": {_trialData params[["_defendant", objNull, [objNull]]];
                AP_clientTrialData set[1, true];
                ["GovMessage", ["You have received a Jury Summons!"]] call BIS_fnc_showNotification; {
                    _x params["_timeDelayM", "_timeDelayS"];
                    if (SRV_trialData isEqualTo[objNull, [], [], false, false, false, ""]) exitWith {};
                    private _formatMinunteStr =
                    if (_forEachIndex isEqualTo 2) then {format["%1 minute", _timeDelayM]} else {format["%1 minutes", _timeDelayM]};
                    [format["<t color='#00FF00'><t size='1.5'><t align='center'>Jury Summons<br/><br/><t align='left'><t size='1'><t color='#ffffff'>You have been summoned to jury duty for the case of %2 v. %1! You will be <t color='#00FF00'>rewarded with $5,000</t>. Sign in at the nearest <t color='#00FF00'>courthouse</t> within %3 to attend.", worldName, name _defendant, _formatMinunteStr], "basic"] spawn AP_fnc_handleMessage;
                    uiSleep _timeDelayS;}
                forEach[[5, 180], [2, 60], [1, 60]];
                [] spawn {uiSleep 300;
                    AP_clientTrialData set[1, false];};};
        case "registerForJury": {if !(vehicle player isEqualTo player) exitWith {
                    ["You cannot register for jury duty while restrained!", "basic"] spawn AP_fnc_handleMessage};
                if (player getVariable["AP_restrained", false]) exitWith {
                    ["You cannot register for jury duty from within a vehicle.", "basic"] spawn lifqe_fnc_handleMessage};
                if (SRV_trialData select 5) exitWith {
                    ["The courtroom has already reached its max capacity!", "basic"] spawn AP_fnc_handleMessage};
                if !(AP_clientTrialData select 1) exitWith {
                    ["You haven't been chosen for jury duty yet!", "basic"] spawn AP_fnc_handleMessage};
                if (AP_clientTrialData select 3) exitWith {
                    ["You are currently waiting for a courtroom to be in session, please be patient!", "basic"] spawn AP_fnc_handleMessage
                };
                private _startPos = getPos player;
                AP_clientTrialData set[3, true]; [["addJuryPlayer", [player, "add"]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;
                ["You have registered for jury duty! Please wait up to 5 minutes for the court to be in session", "basic"] spawn AP_fnc_handleMessage;
                waitUntil {uiSleep 5;
                    ((SRV_trialData select 0) isEqualTo objNull) || (SRV_trialData select 4) || (player distance _startPos >= 25) || player getVariable["AP_restrained", false] || !(vehicle player isEqualTo player)
                };
                if (SRV_trialData select 0) exitWith {["Jury duty has been cancelled!"] spawn AP_fnc_handleMessage;
                    AP_clientTrialData set[3, false];};
                if (count(SRV_trialData select 1) isEqualTo 12) exitWith {
                    ["The courtroom has already reached its max capacity!", "basic"] spawn AP_fnc_handleMessage;
                    AP_clientTrialData set[3, false];};
                if ((player distance _startPos >= 25) || player getVariable["AP_restrained", false] || !(vehicle player isEqualTo player)) exitWith {
                    [["addJuryPlayer", [player, "remove"]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;
                    AP_clientTrialData set[3, false];
                    ["You moved too far from the courthouse, entered a vehicle, or have been restrained. You have been removed from the jury bench as a result. Quickly register for duty again before the trial begins if you wish to attend."] spawn AP_fnc_handleMessage;
                };};
        case "defendantTrialStart": {_trialData params[["_defendant", objNull, [objNull]], ["_positionData", [], [[]]]];
                _positionData params["_plb_pos", "_plb_dir"]; [
                    [0, 1, 2], "Your trial has begun. You have three minutes to convince the jury of your innocence. Good luck."] spawn AP_fnc_broadcast;
                AP_clientTrialData set[0, true];
                private _plb_obj = player;
                _plb_obj setDir _plb_dir;
                _plb_obj setPosASL _plb_pos;
                [player, player, true, false] spawn AP_fnc_restrainAction;
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                private _increment = 1;
                private _totalTime = 180;
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text = format["Plead your innocence to the Jury"];
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    if !(SRV_trialData select 3) exitWith {false};
                    false;}; 5 cutText["", "PLAIN"];
                if !(_isSuccess) exitWith {};
                waitUntil {(SRV_trialData select 5)}; [
                    [0, 1, 2], "The jury is now deliberating. You will have the verdict in 2 minutes from the court."] spawn AP_fnc_broadcast;
                [player] spawn AP_fnc_unrestrain;
                uiSleep 1;
                AP_clientTrialData set[0, false];};
        case "juryTrialStart": {_trialData params[["_defendant", objNull, [objNull]], ["_bailAmount", -1, [0]]];
                ["action", "attendjuryduty", 1] call AP_fnc_handleQuest; [
                    [0, 1, 2], format["The trial for the defendant %1 has begun. Their bail is currently $%2.", name _defendant, [_bailAmount] call AP_fnc_numberText]
                ] spawn AP_fnc_broadcast;
                private _previousAttire = getUnitLoadout player;
                private _previousAttireSkins = AP_uniformBackpack_skins;
                private _randomAttire = [[[], [], [], ["U_C_FormalSuit_01_black_F", []], [], [], "", "", ["Binocular", "", "", "", [],
                            [], ""], ["ItemMap", "", "", "ItemCompass", "ItemWatch", "NVGoggles"]], [[], [], [],
                        ["U_C_FormalSuit_01_tshirt_gray_F", []], [], [], "", "", ["Binocular", "", "", "", [], [], ""],
                        ["ItemMap", "", "", "ItemCompass", "ItemWatch", "NVGoggles"]], [[], [], [], ["U_C_Journalist", []], [],
                        [], "", "", ["Binocular", "", "", "", [], [], ""], ["ItemMap", "", "", "ItemCompass", "ItemWatch", "NVGoggles"]], [
                        [], [], [], ["U_C_Uniform_Scientist_01_formal_F", []], [], [], "", "", ["Binocular", "", "", "", [], [], ""],
                        ["ItemMap", "", "", "ItemCompass", "ItemWatch", "NVGoggles"]], [[], [], [], ["U_C_Uniform_Scientist_01_F", []], [],
                        [], "", "", ["Binocular", "", "", "", [], [], ""], ["ItemMap", "", "", "ItemCompass", "ItemWatch", "NVGoggles"]]];
                player setUnitLoadout(selectRandom _randomAttire);
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                private _increment = 1;
                private _totalTime = 180;
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text = format["Court in session"];
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
                [] spawn {uiSleep 5;
                    ["You can check the defendants charges via the MaxSec Wanted List!", "basic"] spawn AP_fnc_handleMessage;};
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    if !(SRV_trialData select 3) exitWith {};
                    false;}; 5 cutText["", "PLAIN"];
                if !(_isSuccess) exitWith {};
                AP_juryVoteEnabled = true;
                ["YOU MUST CHOOSE YOUR VERDICT BEFORE TIME ELAPSES. Failure to choose a verdict will result in a guilty default.", "basic"] spawn AP_fnc_handleMessage;
                ["<t align='center'>Don't decide too quickly, the jury will deliberate for 2 minutes. Speak your opinion. <t color='#00FF00'>Use your action menu (scroll wheel) to choose your verdict!</t></t>", "basic"] spawn AP_fnc_handleMessage;
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                private _increment = 1;
                private _totalTime = 120;
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text = format["Jury Deliberating"];
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    if !(SRV_trialData select 3) exitWith {};
                    false;}; 5 cutText["", "PLAIN"];
                if !(_isSuccess) exitWith {};
                if !(AP_clientTrialData select 2) then {[
                        ["addJuryVote", [player, "GUILTY"]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;};
                waitUntil {uiSleep 1;
                    !(AP_clientTrialData select 2)};
                player setUnitLoadout _previousAttire;
                AP_uniformBackpack_skins = _previousAttireSkins;
                [] spawn {uiSleep 0.5;
                    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
                    [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;
                    [] call AP_fnc_hudUpdate;};};
        case "voteGuilty": {["You have chosen to vote guilty!", "basic"] spawn AP_fnc_handleMessage;
                AP_clientTrialData set[2, true]; [["addJuryVote", [player, "GUILTY"]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;
                AP_juryVoteEnabled = false;};
        case "voteNotGuilty": {["You have chosen to vote not guilty!", "basic"] spawn AP_fnc_handleMessage;
                AP_clientTrialData set[2, true]; [["addJuryVote", [player, "INNOCENT"]], "APS_fnc_trialSystemSRV", 2] spawn AP_fnc_MP;
                AP_juryVoteEnabled = false;};
        case "trialEnded": {
                _trialData params[["_defendant", objNull, [objNull]], ["_endType", "", [""]], ["_chosenVerdict", "", [""]], ["_isJuryCorrupt", false, [false]]];
                private _extraText =
                if (_isJuryCorrupt) then {format["%1, due to having jury corruption", _chosenVerdict]} else {format["%1", _chosenVerdict]};
                switch (_endType) do {case ("jailedPlayer"): {[
                                [0, 1, 2], format["A verdict has been reached. You, the defendant, were found %1", _extraText]
                            ] spawn AP_fnc_broadcast;
                            if (_chosenVerdict isEqualTo "NOT GUILTY") then {AP_bail_paid = true; [
                                    [0, format["%1 has been found innocent and is released from jail!", name _defendant]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
                            };}; case ("juryPlayer"): {private _moneyEarned = 5000; [
                                    [0, 1, 2], format["A verdict has been reached. The defendant, %1, was found %2. As payment for your time, the government of %3 has awarded you $%4.", name _defendant, _extraText, worldName, [_moneyEarned] call AP_fnc_numberText]
                                ] spawn AP_fnc_broadcast;
                                titleText["You have been transported back to your original location", "PLAIN"]; [
                                    ["-JURYSUMMONS-", player, profileName, format["Completed jury summon, paid: $%1, pos: %2", [_moneyEarned] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                                [] spawn {uiSleep 4;
                                    [10] call AP_fnc_ClupdatePartial;};
                                AP_clientTrialData set[2, false];};};};};