params[["_mode", "", ["", 0]], "_toFind"];
if (_mode isEqualTo "") exitWith {};
private _sprayCfg = [[0, "Dog Poop", "images\spraycan\sprayPoopDog.paa", true],
    [1, "Potato Aim", "images\spraycan\sprayPotatoAim.paa", true], [2, "Among Us", "images\spraycan\sprayAmongUs.paa", true],
    [3, "Battleye", "images\spraycan\sprayBE.paa", true], [4, "Doom Slayer", "images\spraycan\sprayDoom.paa", true],
    [5, "Jedi Order", "images\spraycan\sprayJedi.paa", true], [6, "John Wick", "images\spraycan\sprayJohnWick.paa", true],
    [7, "Los Pollos Hermanos", "images\spraycan\sprayLosPollos.paa", true], [8, "Tea Bag", "images\spraycan\sprayTeaBag.paa", true],
    [9, "Trump", "images\spraycan\sprayTrump.paa", true], [10, "Tractor", "images\spraycan\sprayTractor.paa", true],
    [11, "Weed", "images\spraycan\sprayWeed.paa", true], [12, "Elon Musk", "images\spraycan\sprayElonMusk.paa", true],
    [13, "Jack Daniels", "images\spraycan\sprayJackDan.paa", true], [14, "Anime 1", "images\spraycan\sprayAnime1.paa", true],
    [15, "Anime 2", "images\spraycan\sprayAnime2.paa", true], [16, "Troll Face", "images\spraycan\sprayTroll.paa", true],
    [17, "Mald Maniac", "images\spraycan\sprayMald.paa", true], [18, "Ego Drop", "images\spraycan\sprayEgoDrop.paa", true],
    [19, "Obunga", "images\spraycan\sprayObunga.paa", true], [20, "Fuck APD", "images\spraycan\sprayFuckAPD.paa", true],
    [21, "Robocop", "images\spraycan\sprayRoboCop.paa", true]];
private "_return";
switch (_mode) do {case "getCfg": {_return = _sprayCfg;}; case "getSprayData": {_return = _sprayCfg param[_sprayCfg findIf {
                    _toFind isEqualTo(_x param[0, 0])}, []];};}; _return ;