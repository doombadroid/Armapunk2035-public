params[["_vendor", objNull, [objNull]], "", "", ["_type", "", [""]]];
// Process recipe table: input items -> output item, licence cost, progress caption, cartel index.
// Was a 49-arm `switch (_type)` of literal arrays; now one HashMap built once on first use. Keys are
// case-sensitive, matching the case-sensitive switch on a string that this replaces.
//
// The `+` is defensive rather than required: today the only consumers are an isEqualTo [] test and a
// `params` destructure, neither of which writes back. But fn_recipeDetail is the same shape and DOES
// get mutated in place by its caller, so handing out a bare reference to a cached row is a known-live
// hazard in this codebase. One array copy per process action is not worth the risk of finding out.
if (isNil "AP_processMap") then {AP_processMap = createHashMapFromArray [["cement", [["rock"], "cement", 3, "Mixing Cement", 0]], ["sandr", [["rock"], "sand", 0, "Crushing Rocks", 0]], ["smashpowder", [["smashpowder"], "smash", 0, "Processing Smash", 1]], ["copper", [["copperore"], "copper_r", 7, "Processing Copper", 0]], ["glitterbase", [["sparkdust", "redshift", "toxicslurry"], "glitterbase", 0, "Mixing Ingredients", 0]], ["glitter", [["glitterbase"], "glitter", 0, "Cooking Glitter", 0]], ["diamond", [["diamond"], "diamondc", 15, "Processing Diamond", 0]], ["drilledoil", [["oilu"], "oilp", 10, "Processing Oil", 0]], ["iron", [["ironore"], "iron_r", 11, "Processing Iron", 0]], ["marijuana", [["cannabis"], "marijuana", 0, "Processing Marijuana", 1]], ["marijuanam", [["cannabis"], "marijuanam", 0, "Processing Medical Marijuana", 0]], ["blacklace", [["lacebase"], "blacklace", 0, "Cooking Black Lace", 1]], ["lacebase", [["sparkdust", "redshift", "toxicslurry"], "lacebase", 0, "Mixing Ingredients", 0]], ["oil", [["oilb"], "oilp", 10, "Processing Oil", 0]], ["rock", [["rock"], "rock", 0, "Examining Stone", 0]], ["rum", [["water", "yeast", "sugar"], "rum_0", 0, "Distilling Spirits", 3]], ["rumsalt", [["saltwater", "yeast", "sugar"], "rum_0", 0, "Distilling Spirits", 3]], ["salt", [["salt"], "salt_r", 4, "Processing Salt", 0]], ["sand", [["sand"], "glass", 6, "Processing Sand", 0]], ["scotch", [["water", "yeast", "barley"], "scotch_0", 0, "Distilling Spirits", 3]], ["scotch3", [["scotch_2"], "scotch_3", 0, "Adding Aging Chemicals", 3]], ["scotchsalt", [["saltwater", "yeast", "barley"], "scotch_0", 0, "Distilling Spirits", 3]], ["timber", [["timber"], "plank", 0, "Processing Pine Timber", 0]], ["timberh", [["timberh"], "plankh", 0, "Processing Hardwood Timber", 0]], ["timberl", [["timberl"], "plankl", 0, "Processing Olive Timber", 0]], ["uraniump", [["uraniumu"], "uraniump", 0, "Enriching Uranium Ore", 0]], ["whiskeyc", [["water", "yeast", "barley", "corn"], "whiskeyc_0", 0, "Distilling Spirits", 3]], ["whiskeycsalt", [["saltwater", "yeast", "barley", "corn"], "whiskeyc_0", 0, "Distilling Spirits", 3]], ["whiskeyr", [["water", "yeast", "barley", "rye"], "whiskeyr_0", 0, "Distilling Spirits", 3]], ["whiskeyrsalt", [["saltwater", "yeast", "barley", "rye"], "whiskeyr_0", 0, "Distilling Spirits", 3]], ["blacklaceprime", [["blacklace"], "blacklaceprime", 0, "Refining Black Lace Prime", 1]], ["smashbrick", [["smash"], "smashbrick", 0, "Pressing Smash Bricks", 1]], ["moonshinehash", [["water", "yeast", "corn"], "moonshinehash", 0, "Making Corn Hash from Supplies", 0]], ["moonshine", [["moonshinehash"], "moonshine", 0, "Distilling Corn Hash into Homebrew Moonshine", 0]], ["moonshinep", [["moonshine"], "moonshinep", 0, "Purifying Moonshine into White Lightning", 0]], ["goldnugget", [["goldbar"], "goldnugget", 0, "Breaking Down Gold Bar", 0]], ["canna_joint", [["canna_papers"], "canna_joint", 0, "Rolling Joints With Cannabis", 0]], ["cannai_3", [["cannai_3"], "canna_dab", 0, "Extracting THC from Indica Exo Cannabis", 1]], ["cannai_2", [["cannai_2"], "cannai_3", 0, "Drying Wet Indica Plants into Dried Bud", 1]], ["cannas_2", [["cannas_2"], "cannas_3", 0, "Drying Wet Sativa Plants into Dried Bud", 1]]];};
private _processArray = +(AP_processMap getOrDefault [_type, []]);
if (_processArray isEqualTo[]) exitWith {["You don't have the items necessary.", "basic"] spawn AP_fnc_handleMessage;};
_processArray params["_input", "_output", "_cost", "_text", "_capIndex"];
if ((_output isEqualTo "canna_dab") && !(license_civ_marijuana)) exitWith {["You need a marijuana license to make wax!", "basic"] spawn AP_fnc_handleMessage;};
private _inputVals = [];
private _loggedInput = []; {_inputVals pushBack(missionNamespace getVariable(format["AP_inv_%1", _x]));
    _loggedInput pushBack(format["(%2 %1)", ["getName", _x] call AP_fnc_virtItemCfg, (missionNamespace getVariable(format["AP_inv_%1", _x]))]);}
forEach _input;
private _inputCount = selectMin _inputVals;
if (_inputCount isEqualTo 0 || _inputVals isEqualTo[]) exitWith {["You don't have the items necessary.", "basic"] spawn AP_fnc_handleMessage;};
private _nBuilding = nearestBuilding player;
if (_output in ["glitterbase", "glitter"] && (player distance _nBuilding <= 10)) exitWith {["You're too close to a building to be messing with a mobile lab.", "basic"] spawn AP_fnc_handleMessage;};
if (_output in ["moonshinehash", "moonshine"] && (player distance _nBuilding <= 10)) exitWith {["You're too close to a building to be messing with a mobile distillery.", "basic"] spawn AP_fnc_handleMessage;};
private _processSoundArray =
switch (_output) do {case ("moonshinehash"): {["moonshineBoil", 12, 5]}; case ("moonshine"): {["moonshineDrip", 12, 5]};
        default {["", -1, -1]};}; _processSoundArray params["_soundString", "_soundDelay", "_soundRepeat"];
if !(_soundString isEqualTo "") then {[_soundString, _soundDelay, _soundRepeat] spawn {params["_soundString", "_soundDelay", "_soundRepeat"];
        for "_i"
        from 0 to _soundRepeat do {if (!(AP_is_processing) || !(AP_action_in_use)) exitWith {};
            if ((player getVariable["AP_restrained", false]) || !(alive player)) exitWith {};
            playSound _soundString;
            uiSleep _soundDelay;};};};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_is_processing = true;
AP_action_in_use = true;
private _success = false;
private _sleep = _inputCount * 0.03;
// ASSEMBLY LINE (221): all processing runs 25% faster. Stacks with the weed/infamy speed perks below.
if (221 in AP_side_talents) then { _sleep = _sleep * 0.75; };
// owner 2026-06-14: weed processing is 4/5ths faster (1/5 the time). Covers cannabis->weed, drying bud, and
// bud->golden wax. Stacks with the infamy-talent speed perk below.
if (_output in ["marijuana", "marijuanam", "canna_dab", "cannai_3", "cannas_3", "canna_joint"]) then {_sleep = _sleep * 0.2;};
private _vehicle = cursorObject;
if (_output in ["blacklace", "blacklaceprime", "smash", "smashbrick", "moonshine", "moonshinep", "marijuana"] && {25 in AP_infamy_talents && license_civ_rebel}) then {private _reduction = _sleep * 0.05;
    _sleep = _sleep - _reduction;};
for "_i"
from 0 to 1 step 0 do {uiSleep _sleep;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if ((_output in ["glitterbase", "glitter", "moonshinehash", "moonshine"]) && ((isNil "_vehicle") || (player distance _vehicle > 8) || (isNull _vehicle) || !(alive _vehicle))) exitWith {};
    if (player distance _vendor > 8) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_is_processing = false;
AP_action_in_use = false;
if !(_success) exitWith {[["-PROCESSEDITEMFAILED-", player, (profileName), format["failed to process %1 into %2 %3 at POS: %4", _loggedInput, _inputCount, (["getName", _output] call AP_fnc_virtItemCfg), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;};
if ((player getVariable["AP_restrained", false]) || !(alive player)) exitWith {["You didn't complete the processing successfully.", "basic"] spawn AP_fnc_handleMessage; [["-PROCESSEDITEMFAILED-", player, (profileName), format["failed to process %1 into %2 %3 at POS: %4", _loggedInput, _inputCount, (["getName", _output] call AP_fnc_virtItemCfg), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;};
private _inputValsCheck = []; {_inputValsCheck pushBack(missionNamespace getVariable(format["AP_inv_%1", _x]));}
forEach _input;
if !(_inputVals isEqualTo _inputValsCheck) exitWith {};
private _loggedInput = []; {if ([false, _x, _inputCount] call AP_fnc_handleInv);
    _loggedInput pushBack(format["(%2 %1)", ["getName", _x] call AP_fnc_virtItemCfg, _inputCount]);}
forEach _input;
AP_side_exp = AP_side_exp + (ceil(_inputCount * (count _input)));
// owner 2026-07-13: drug-processing yield talents (23-26) BAKED INTO CORE -- every civ now gets full return on
// weed/heroin/smash/oyster/black lace/glitter processing (was a 4-point tax to dodge a 15% penalty). Timber
// keeps its own reduction.
private _reduce = false;
if (_type in ["timberl", "timberh"]) then {_reduce = true;};
if (_reduce) then {_inputCount = floor(_inputCount * 0.85);};
private _capture =
if (_capIndex > 0) then {true} else {false};
private _reductionAmt = 0;
private _flag =
switch (_capIndex) do {case 1: {[drug_flag, ", you retain %1 after the owners of Drug Cartel took a cut of %2 %3", 0.85, "Drug Cartel"]};
    case 2: {
            // owner 2026-06-18: oil cartel intentionally takes NO processing tax (oil -> rubber is untaxed).
            // Leave bare string so _flagObj resolves nil and the tax-trigger stays off. Do NOT add brackets.
            oil_flag, ", you retain %1 after the owners of Oil Cartel took a cut of %2 %3", 0.85, "Oil Cartel"};
    case 3: {[wongs_flag, ", you retain %1 after the owners of Wongs Triad took a cut of %2 %3", 0.85, "Wongs Triad"]};
    default {[objNull, "", 0.85, ""]};}; _flag params["_flagObj", "_extra", "_tax", "_cartelName"];
private _gangId =
if !(AP_gang_data isEqualTo[]) then {AP_gang_data select 0} else {-1};
if (_type in ["cannas_3", "cannai_3", "smashbrick", "blacklaceprime", "scotch_3"]) then {_tax = 0.95;};
if (_capture) then {if !(isNull _flagObj) then {(_flagObj getVariable["AP_capData", [0, "Neutral", 0.5]]) params["_flagGangID", "_flagGangName", "_progress"];
        if !(_flagGangID isEqualTo _gangId) then {_reductionAmt = abs((floor(_inputCount * _tax)) - _inputCount);
            _inputCount = floor(_inputCount * _tax);
            private _value = _reductionAmt * (["getLowestPrice", _output] call AP_fnc_virtItemCfg); [[0, _capIndex, _value], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;} else {_extra = "owner";};};};
if ([true, _output, _inputCount] call AP_fnc_handleInv) then {if (_capture) then {if (_extra isEqualTo "owner") then {titleText[format["You have processed your goods into %1 %2. As the owner of %3, you retain the entire amount", _inputCount, (["getName", _output] call AP_fnc_virtItemCfg), _cartelName], "PLAIN"];} else {titleText[format["You have processed your goods into %1%2", (["getName", _output] call AP_fnc_virtItemCfg), format[_extra, _inputCount, _reductionAmt]], "PLAIN"];};} else {titleText[format["You have processed your goods into %1 %2", _inputCount, (["getName", _output] call AP_fnc_virtItemCfg)], "PLAIN"];}; [["-PROCESSEDITEMSUCCESS-", player, (profileName), format["processed %1 into %2 %3 at POS: %4", _loggedInput, _inputCount, (["getName", _output] call AP_fnc_virtItemCfg), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (_type isEqualTo "oil") then {private _rubbers = ceil(random 7);
        if (70 in AP_side_talents) then {_rubbers = _rubbers + 1};
        [true, "rubber", _rubbers] call AP_fnc_handleInv;
        systemChat format["You've received %1 units of rubber while processing oil.", _rubbers];};
    if (_output in ["uraniump", "smashbrick", "blacklaceprime", "moonshine", "moonshinep"]) then {[format["%1%2", _output, "_proc"], _inputCount] call AP_fnc_statArrUpdate;} else {[_output, _inputCount] call AP_fnc_statArrUpdate;};
    if (_output in ["uraniump", "smash", "smashbrick", "blacklace", "lacebase", "blacklaceprime", "moonshinep", "marijuana", "marijuanam", "canna_dab", "scotch_3", "glitter", "moonshine"]) then {
        // owner 2026-06-14: added regular weed (marijuana), golden wax (canna_dab) + sparkdust so weed/wax
        // processing grants infamy (it granted none before, in either the hand OR vehicle processor).
        // owner 2026-07-04: 3x infamy from ALL drugs EXCEPT house weed (marijuana/marijuanam stay at 0.2).
        private _multiplier = if (_output in ["marijuana", "marijuanam"]) then { 0.2 } else { 1.2 };
        private _infamyAmount = round(_inputCount * _multiplier);
        if (_infamyAmount < 1) exitWith {};
        private _infamyCap = if (_output in ["marijuana", "marijuanam"]) then { 15 } else { 45 };
        if (_infamyAmount > _infamyCap) then {_infamyAmount = _infamyCap;};
        [_infamyAmount, true] call AP_fnc_addInfamy;};
    playSound "ziptie";
    playSound "ziptie";
    playSound "ziptie";};