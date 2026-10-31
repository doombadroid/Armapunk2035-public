if !(params[["_type", "", [""]]]) exitWith {};
if !(AP_effSide isEqualTo civilian) exitWith {};
if (AP_carryWeight > 10) exitWith {
    ["You are too heavy to open gifts. You need your weight to be 10 or below to open gifts!", "basic"] spawn AP_fnc_handleMessage;};
private _rewards =
switch (_type) do {case "giftXmas": {[["bust", 0], ["beer", 3], ["diamondf", round random[1, 3, 5]], ["diamondc", round random[4, 8, 12]],
                ["smash", round random[4, 6, 8]], ["smashbrick", round random[2, 5, 10]], ["marijuana", round random[4, 6, 10]],
                ["doubloon", round random[6, 12, 15]], ["dogp", round random[6, 12, 15]], ["goatp", round random[1, 2, 3]],
                ["blacklace", round random[1, 3, 8]], ["blacklaceprime", round random[1, 4, 8]], ["rubber", round random[4, 6, 8]],
                ["redgull", round random[8, 6, 10]], ["donerkebab", round random[8, 6, 10]], ["goldbar", 1],
                ["goldnugget", round random[1, 2, 3]], ["manflesh", round random[1, 2, 3]], ["treasuremap", 1],
                ["treasure", round random[1, 1, 2]], ["whiskeyr_3", round random[4, 6, 8]], ["money", 5000], ["money", 10000],
                ["money", 15000], ["money", 20000], ["money", 25000], ["money", 30000], ["money", 35000], ["money", 40000]]
        }; case "giftHallo": {[["bust", 0], ["beer", 3], ["diamondf", round random[1, 3, 5]], ["diamondc", round random[4, 8, 12]],
                    ["smash", round random[4, 6, 8]], ["smashbrick", round random[4, 6, 8]], ["marijuana", round random[4, 6, 10]],
                    ["doubloon", round random[6, 12, 15]], ["dogp", round random[6, 12, 15]], ["goatp", round random[1, 2, 3]],
                    ["blacklace", round random[1, 4, 8]], ["rubber", round random[4, 6, 8]], ["redgull", round random[8, 6, 10]],
                    ["donerkebab", round random[8, 6, 10]], ["goldbar", 1], ["goldnugget", 1], ["manflesh", round random[1, 2, 3]],
                    ["treasuremap", 1], ["treasure", 1], ["whiskeyr_3", round random[4, 6, 8]], ["money", 5000], ["money", 10000],
                    ["money", 15000], ["money", 20000], ["money", 25000], ["money", 30000], ["money", 35000], ["money", 40000]]};
        case "giftAdmin": {[["diamondf", round random[1, 3, 4]], ["diamondc", round random[4, 8, 10]], ["smash", round random[4, 6, 7]],
                    ["smashbrick", round random[2, 3, 5]], ["marijuana", round random[4, 6, 10]], ["doubloon", round random[6, 12, 15]],
                    ["blacklace", round random[1, 4, 7]], ["blacklaceprime", round random[1, 2, 4]], ["goldbar", 1], ["goldnugget", 1],
                    ["treasuremap", 1], ["treasure", 1], ["money", 50000], ["money", 750000], ["money", 1000000]]};
        default {[]};}; if (_rewards isEqualTo[]) exitWith {
    ["There was an error processing your gift reward. Please try again.", "basic"] spawn AP_fnc_handleMessage;};
closeDialog 0;
private _reward = selectRandom _rewards;
_reward params["_item", "_qty"];
private _giftName = ["getName", _item] call AP_fnc_virtItemCfg;
if !([false, _type, 1] call AP_fnc_handleInv) exitWith {
    ["There was an error processing your gift reward. Please try again.", "basic"] spawn AP_fnc_handleMessage;}; [
    ["-GIFTOPEN-", player, (profileName), format["opened a gift(%1) and obtained %2.", _type, _reward]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
if (_item isEqualTo "bust") exitWith {private _saying =
    if (_type isEqualTo "giftXmas") then {"coal"} else {"Halloween candy"};
    [format["<t color='#8034EB' align='center'><t size='1'>Gift Opened</t></t><br/>You have opened your gift and got some lousy worthless %1. Better luck next time.", _saying], "basic"] spawn AP_fnc_handleMessage;
};
if (_item isEqualTo "money") exitWith {AP_cash = AP_cash + _qty;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [format["<t color='#8034EB' align='center'><t size='1'>Gift Opened</t></t><br/>You have opened your gift and got $%1!. Better run to the ATM to deposit that!", [_qty] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
};
if (_type == 'giftAdmin') then {["use", "admingift", 1] call AP_fnc_handleQuest;};
[true, _item, _qty] call AP_fnc_handleInv;
[format["<t color='#8034EB' align='center'><t size='1'>Gift Opened</t></t><br/>You have opened your gift and got %1 %2!. The item(s) have been added to your inventory.", [_qty] call AP_fnc_numberText, _giftName], "basic"] spawn AP_fnc_handleMessage;