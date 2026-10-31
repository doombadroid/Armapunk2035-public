params[["_mode", "", ["", 0]], "_toFind"];
if (_mode isEqualTo "") exitWith {};
private _tierTable = [[19, ["money", 20000], true, false, false, false], [20, ["goldnugget", 1], true, false, false, false],
    [21, ["speedbomb", 1], true, false, false, false], [22, ["V_HarnessOGL_brn", 2], false, true, false, false],
    [23, ["MiniGrenade", 4], false, true, false, false], [24, ["diamondf", 5], true, false, false, false],
    [25, ["LMG_Mk200_F", 1, ["optic_Arco", "acc_flashlight"], [["200Rnd_65x39_cased_Box", 3]]], false, false, false, true],
    [26, ["C_Tractor_01_F", 1], false, false, true, false], [27, ["giftXmas", 4], true, false, false, false],
    [28, ["money", 15000], true, false, false, false], [29, ["smashbrick", 20], true, false, false, false],
    [30, ["LMG_Zafir_F", 3, ["optic_Arco", "acc_flashlight"], [["150Rnd_762x54_Box", 5]]], false, false, false, true],
    [31, ["B_G_Offroad_01_armed_F", 1], false, false, true, false]];
private "_return";
switch (_mode) do {case "getCfg": {_return = _tierTable;}; case "getTierData": {_return = _tierTable param[_tierTable findIf {
                    _toFind isEqualTo(_x param[0, 0])}, []];};}; _return ;