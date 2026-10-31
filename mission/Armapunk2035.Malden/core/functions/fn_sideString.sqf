private _side =
switch (AP_effSide) do {case west: {"cop"};
    case civilian: {"civ"};
    case independent: {"med"};
    default {""};}; _side