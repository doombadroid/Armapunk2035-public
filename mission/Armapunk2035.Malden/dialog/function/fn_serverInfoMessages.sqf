uiSleep(selectRandom[120, 250, 350]); {uiSleep(selectRandom[1000, 2000, 2500, 3000, 3500]);
    _x params["_message", "_messageType"];
    [_message, _messageType] spawn AP_fnc_handleMessage;}
forEach([
    ["<t color='#32e6f4'><t size='1.5'><t align='center'>LoonyBin Official Discord<br/><br/></t></t></t>Join Gaming LoonyBin's Discord Server! Find help topics, housing for sale, and get updated on upcoming content patches, events, giveaways plus more!", "speedingticket"],
    ["<t color='#32e6f4'><t size='1.5'><t align='center'>LoonyBin Forums<br/><br/></t></t></t>Do you need to submit a player report? Join our forums at https://discord.gg/TdNVfcFcx6", "speedingticket"],
    ["<t color='#32e6f4'><t size='1.5'><t align='center'>My LoonyBin<br/><br/></t></t></t>Want to see all your statistical data for LoonyBin? Or maybe even check our vast leaderboards, or possibly purchase a subscription or loot crate key? Join us at our Discord", "speedingticket"]
] call BIS_fnc_arrayShuffle);