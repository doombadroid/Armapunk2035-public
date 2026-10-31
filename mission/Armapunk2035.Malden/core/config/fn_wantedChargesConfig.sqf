params[["_mode", "", [""]], "_toFind"];
if (_mode isEqualTo "") exitWith {};
private _list = [[1, "Suicide Bomber", 40000, 300, false, false], [2, "Explosive Terrorism", 40000, 300, false, false],
    [3, "Possession of Explosives", 5000, 60, false, true], [4, "Bank Robbery", 10000, 240, false, true],
    [5, "Federal Reserve Robbery", 10000, 240, false, false], [6, "Unauthorized Parking", 300, 30, false, true],
    [7, "Attempted Bank Robbery", 7500, 120, false, true], [8, "Bounty Hunter Execution", 7500, 240, false, false],
    [9, "Execution", 7500, 240, false, false], [10, "Hit and Run", 1000, 30, false, true], [11, "Gang Homicide", 2500, 60, false, false],
    [12, "Manslaughter", 5000, 180, false, false], [13, "Escaping Jail", 4000, 300, false, false],
    [14, "Prison Break", 12500, 2400, false, true], [15, "Prison Conspiring", 1500, 240, false, false],
    [16, "Attempted Auto Theft", 500, 20, false, true], [17, "Attempted Manslaughter", 2500, 120, false, true],
    [18, "Robbery", 5000, 120, false, false], [19, "Kidnapping", 12500, 180, true, true],
    [20, "Unlawful Detainment", 1500, 30, false, false], [21, "Grand Theft", 1500, 45, false, true],
    [22, "Landing Within City Limits", 250, 30, false, true], [23, "Insurance Fraud", 500, 30, false, true],
    [24, "Aiding escape from custody", 1000, 30, false, false], [25, "Identity Fraud", 5, 3, false, true],
    [26, "Harassment", 50, 300, false, true], [27, "Disobeying an order from an officer", 500, 60, false, true],
    [28, "Possession of Police Equipment", 2500, 60, false, true], [29, "Public Intoxication", 100, 30, false, true],
    [30, "Manipulation of Police Gates", 1000, 60, false, true], [31, "Evading Arrest", 2500, 60, false, true],
    [32, "Possession of Reggie Weed/Stems", 2500, 60, false, true], [33, "Possession of Heroin", 5000, 60, false, true],
    [34, "Possession of Smash", 7500, 60, false, true], [35, "Possession of Black Lace", 10000, 60, false, true],
    [36, "Possession of Reserve Gold", 15000, 60, true, true], [37, "Possession of Turtle Meat", 12500, 60, false, true],
    [38, "Terrorism", 15000, 240, false, true], [39, "Threatening an Officer", 2500, 60, false, true],
    [40, "Speeding", 100, 30, false, true], [41, "Driving Without A License", 50, 30, false, true],
    [42, "Reckless Driving", 50, 30, false, true], [43, "Driving Unregistered Vehicle", 250, 30, false, true],
    [44, "Failure to Stop", 250, 30, false, true], [45, "Failure to Headlight", 100, 30, false, true],
    [46, "Driving an Illegal Vehicle", 2500, 60, false, true], [47, "Possession of Illegal Firearm", 2500, 60, false, true],
    [48, "Possession of Illegal Liquor", 2000, 60, false, true],
    [50, "Money Laundering", 5000, 120, true, true], [51, "Discharge Within City", 500, 30, false, true],
    [52, "Trafficking Weapons (3+)", 1000, 60, true, true], [53, "Second-degree Murder", 3000, 60, false, false],
    [54, "Organ Theft", 4000, 180, false, false], [55, "Cannabalism", 4000, 180, false, true],
    [56, "Raiding the Evidence Lockup", 15000, 240, false, true], [57, "Admin Jailed", 999999, 1800, false, false],
    [58, "Destruction of Property", 12500, 90, false, true], [59, "Drug Trafficking", 10000, 120, false, true],
    [60, "Possession of Uranium", 8500, 60, false, true], [61, "Possession of Barley", 2000, 60, false, true],
    [62, "Possession of Black Lace Prime", 15000, 60, false, true], [63, "Possession of Smash Bricks", 10500, 60, false, true],
    [64, "Theft of Cargo", 15000, 240, false, true], [65, "Possession of Oysters", 5000, 60, false, false],
    [66, "Possession of Fried Oysters", 9000, 60, false, false], [67, "Possession of Golden Wax", 13000, 60, false, true],
    [68, "Possession of High Potency Cannabis", 7000, 60, false, true],
    [72, "Possession of Element 115", 20000, 60, false, true], [73, "Possession of Drug Paraphernalia", 420, 35, false, true],
    [74, "Loony Bin Robbery", 15000, 300, false, true], [75, "Possession of Patient Remains", 35000, 120, false, true],
    [76, "Jewelry Emporium Robbery", 7500, 240, false, true], [77, "Excessive Speeding", 500, 60, false, true],
    [78, "Intent to commit Arson", 10000, 90, false, true], [79, "Arson", 12500, 240, false, false],
    [80, "Abuse of Bounty Hunter Weapon", 7500, 60, false, true], [81, "Possessing Illegal Firearm Accessories", 2000, 60, false, true],
    [82, "Impersonating a Police Officer", 5000, 120, false, false], [83, "Impersonating a Government Employee", 2500, 60, false, false],
    [84, "Bribery of a Public Official", 15000, 180, false, false], [85, "Obstruction of Justice", 7500, 120, false, false],
    [86, "Filing a False Police Report", 7500, 90, false, false], [87, "Witness Tampering", 5000, 90, false, false],
    [88, "Impersonating EMS", 2500, 60, false, false], [89, "Interfering With Emergency Personnel", 2500, 60, false, false],
    [90, "Abuse of Emergency Services", 3000, 60, false, false], [91, "False Emergency Report", 4000, 60, false, false],
    [92, "Possession of High Caliber Firearm", 5000, 60, false, false], [93, "Unlawful Discharge of a Firearm", 5000, 60, false, false],
    [94, "Armed Intimidation", 5000, 90, false, false], [95, "Trespassing", 2500, 45, false, false],
    [96, "Breaking and Entering", 5000, 90, false, false], [97, "Disorderly Conduct", 500, 30, false, false],
    [98, "Disturbing the Peace", 250, 30, false, false], [99, "Unlawful Assembly", 2500, 45, false, false],
    [100, "Riot Participation", 10000, 180, false, false], [101, "Incitement to Riot", 15000, 240, false, false],
    [102, "Theft of Aircraft", 15000, 240, false, false], [103, "Attempted Aircraft Theft", 10000, 120, false, false],
    [104, "Reckless Aircraft Operation", 2500, 60, false, false], [105, "Unauthorized Hovering Over City Limits", 1500, 45, false, false],
    [106, "Dangerous Takeoff or Landing", 2500, 60, false, false], [107, "Operating Aircraft While Intoxicated", 7500, 120, false, false],
    [108, "Discharging a Weapon From an Aircraft", 10000, 120, false, false],
    [109, "Aircraft Destruction of Property", 15000, 180, false, false],
    // owner 2026-06-21: "Rape" = a first-line-moderator CONTAINMENT charge (cops have no server power). isManual=true
    // (index 5) so cops can apply it from the charge menu; jailTime 1800 maxes the global 1500s (25-min) jail cap in
    // fn_jailMe = guaranteed max sentence; $50k per count. Stackable (index 4 true) -> cop can apply up to 5 counts
    // (fn_applyCharge _max=5) = up to $250k bounty/bail; sentence stays capped at 25 min. Re-sendable until staff act.
    // fn_applyCharge fires -MODFLAG-RAPE- on apply -> CLANKR pings an admin instantly. Sync with the server copy.
    [110, "Rape", 50000, 1800, true, true],
    // LooneyBin 2026-07-18: Cyberdeck auto-charges (stackable, non-manual). Sync with the server copy.
    [111, "Breaking & Entering", 50000, 120, true, false], [112, "Cyber Crime", 50000, 120, true, false]];
private _return = nil;
switch (_mode) do {case "getRow": {_return = _list param[_list findIf {_toFind isEqualTo(_x select 0)}, []];}; case "getChargeName": {
                _return = (_list param[_list findIf {_toFind isEqualTo(_x select 0)}, []]) param[1, "Error"];};
        case "getChargeValue": {_return = (_list param[_list findIf {_toFind isEqualTo(_x select 0)}, []]) param[2, 0];};
        case "getManualCharges": {_return = _list select {(_x select 5)};};
        case "getAmountOfCharges": {_return = count _list;};
        case "getChargeTimes": {_return = (_list select {(_x select 3) > 0}) apply {_x select 3};};}; _return ;