params[["_mode", "", ["", 0]], "_toFind"];
if (_mode isEqualTo "") exitWith {};
private _adminLevel = call AP_adminLevel;
private _devUIDs = [];
private _mitchUID = "";
private _hexCfg = [[0, "AHK", "icons\grphex\ahk.paa", true], [1, "Among Us 1", "icons\grphex\amogus1.paa", true],
    [2, "Among Us 2", "icons\grphex\amogus2.paa", true], [3, "Anime 1", "icons\grphex\anime1.paa", true],
    [4, "Anime 2", "icons\grphex\anime2.paa", true], [5, "Badge", "icons\grphex\badge.paa", true],
    [6, "Battleye", "icons\grphex\battleeye.paa", true], [7, "Biohazard", "icons\grphex\biohazard.paa", true],
    [8, "Bitcoin", "icons\grphex\bitcoin.paa", true], [9, "Close Eyes Emoji", "icons\grphex\closeeyesemoji.paa", true],
    [10, "Clowface", "icons\grphex\clownface.paa", true], [11, "Controller", "icons\grphex\controller.paa", true],
    [12, "COVID", "icons\grphex\covid.paa", true], [13, "Crosshair", "icons\grphex\crosshair.paa", true],
    [14, "Crown", "icons\grphex\crown.paa", true], [15, "Crown Royal", "icons\grphex\crownroyal.paa", true],
    [16, "Democrat", "icons\grphex\democrat.paa", true], [17, "Discord", "icons\grphex\discord.paa", true],
    [18, "Doge", "icons\grphex\doge.paa", true], [19, "Eggplant Emoji", "icons\grphex\eggplant.paa", true],
    [20, "Emoji Alien", "icons\grphex\emojialien.paa", true], [21, "Emoji Drool", "icons\grphex\emojidrool.paa", true],
    [22, "Emoji Glasses", "icons\grphex\emojiglasses.paa", true], [23, "Hand Emoji", "icons\grphex\emojihand.paa", true],
    [24, "Devil Emoji", "icons\grphex\emojihorns.paa", true], [25, "Mad Emoji", "icons\grphex\emojimad.paa", true],
    [26, "Middle Finger", "icons\grphex\emojimiddlefinger.paa", true], [27, "Tongue Emoji", "icons\grphex\emojitongue.paa", true],
    [28, "Empire", "icons\grphex\empire.paa", true], [29, "Explosion", "icons\grphex\explosion.paa", true],
    [30, "Fallout Boy", "icons\grphex\fallout.paa", true], [31, "Ghost Emoji", "icons\grphex\ghost.paa", true],
    [32, "Ghostbuster", "icons\grphex\ghostbuster.paa", true], [33, "Gimp", "icons\grphex\gimp.paa", true],
    [34, "Grenade", "icons\grphex\grenade.paa", true], [35, "Grim Reaper", "icons\grphex\grimreaper.paa", true],
    [36, "Gucci", "icons\grphex\gucci.paa", true], [37, "Gun", "icons\grphex\gun.paa", true], [38, "Hydra", "icons\grphex\hydra.paa", true],
    [39, "Lego", "icons\grphex\lego.paa", true], [40, "LV", "icons\grphex\louisv.paa", true],
    [41, "Mike Wazowski", "icons\grphex\mike.paa", true], [42, "Monkey", "icons\grphex\monkey.paa", true],
    [43, "Blank Face Emoji", "icons\grphex\noemotionemoji.paa", true], [44, "Anti-Smoke", "icons\grphex\nosmoke.paa", true],
    [45, "Omegalul", "icons\grphex\omegalul.paa", true], [46, "OMG Emoji", "icons\grphex\omgemoji.paa", true],
    [47, "Penny Wise", "icons\grphex\pennywise.paa", true], [48, "Pleading Emoji", "icons\grphex\pleadingemoji.paa", true],
    [49, "Pog Champ", "icons\grphex\pogchamp.paa", true], [50, "Poop Emoji", "icons\grphex\pooemoji.paa", true],
    [51, "Poop Face", "icons\grphex\poopface.paa", true], [52, "Rebel", "icons\grphex\rebel.paa", true],
    [53, "Republican", "icons\grphex\republican.paa", true], [54, "Sad Emoji", "icons\grphex\sademoji.paa", true],
    [55, "Skull", "icons\grphex\skull.paa", true], [56, "Spartan", "icons\grphex\spartan.paa", true],
    [57, "Spotify", "icons\grphex\spotify.paa", true], [58, "Star", "icons\grphex\star.paa", true],
    [59, "Tiktok", "icons\grphex\tiktok.paa", true], [60, "Tractor", "icons\grphex\tractor.paa", true],
    [61, "Twitch", "icons\grphex\twitch.paa", true], [62, "Twitter", "icons\grphex\twitter.paa", true],
    [63, "UFO", "icons\grphex\ufo.paa", true], [64, "Vader", "icons\grphex\vader.paa", true], [65, "Weed", "icons\grphex\weed.paa", true],
    [66, "Wheelchair", "icons\grphex\wheelchair.paa", true], [67, "Youtube", "icons\grphex\youtube.paa", true]];
private "_return";
switch (_mode) do {case "getCfg": {_return = _hexCfg;}; case "getHexData": {_return = _hexCfg param[_hexCfg findIf {
                    _toFind isEqualTo(_x param[0, 0])}, []];};}; _return ;