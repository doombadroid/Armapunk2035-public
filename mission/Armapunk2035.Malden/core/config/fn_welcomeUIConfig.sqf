params["_type", "_treeCtrl", "_selection"];
private _treeItems = [["General Information", "", [
        ["Welcome", format["<t size='1.6' color='#ff2a2a'>CONTENT WARNING</t><br/><t color='#ff9999'>This server may contain content others find offensive. We've provided a setting under the ""Settings"" app of your phone called ""Streamer Mode"" that disables profanity and server-sided content that may result in issues when streaming on certain platforms.</t><br/><br/><t size='1.4' color='#00fff2'>Welcome to LoonyBin!</t><br/>Hi <t color='#00fff2'>%1!</t> Good to see you here! We are thrilled to have you join us and become a part of our community.<br/><br/>We hope you enjoy your time here, and we look forward to seeing you in-game. If you have any questions or need any assistance, don't hesitate to reach out to our staff team or other members of the community. Have fun!<br/><br/>", profileName] + "<t color='#00fff2'>Useful Links:</t><br/>" + "
				> <a colorLink='#02b2f7' href='https://discord.gg/TdNVfcFcx6'>Discord</a><br/>
				"],
        ["Server Rules", "<t size='1.4' color='#c40000'>Server Rules</t><br/>Some of the basic rules are listed below. To get the full rules list, please visit our <a colorLink='#02b2f7' href='https://discord.gg/TdNVfcFcx6'>Discord</a>.<br/><br/>" + "<t size='1.4' color='#c40000'>Random Deathmatch (RDM)</t><br/>RDM is killing/downing another player without any type of HOSTILE role-play being initiated and reasonable amount of time for the target to react.<br/>Intentions must be clearly stated to the intended target, and they MUST be given reasonable time to react. Text messages through phone to the player is a allowed method of starting RP.<br/>Initiation last 5 minutes from the time instructions are given.<br/><br/>" + "<t size='1.4' color='#c40000'>Vehicle Deathmatch (VDM)</t><br/>Dropping a sling loaded vehicle from a helicopter to intentionally kill a player or cause destruction by 'bombing' them is also considered VDM, and is not allowed. Armored Vehicles may be used in an offensive manner against ONLY other armored vehicles. (Strider/Hunter/Ifrit)<br/>Due to the difficulty in stopping those types of vehicles. You may hit a player with your vehicle only if they are firing at you, and blocking your direct path of travel. You may not maneuver to intentionally hit a player. Closing a gate on a vehicle causing it to explode that results in the death of other players is considered VDM. Intentional contact between vehicles that directly causes loss of life, or the disablement or destruction of the vehicle is considered VDM. Also, repeated attempts at intentional contact that fail to cause immediate injury or loss will also be considered VDM since it's clear of the intent behind the actions.<br/><br/>" + "<t size='1.4' color='#c40000'>COMBAT LOGGING (CL)</t><br/>Do not exit the game, return to lobby, or respawn (suicide button) to avoid a role-play situation. Another player breaking rules does not give you the right to combat log. This rule also applies to storing vehicles. This includes, but is not limited to, being engaged in a firefight, being chased, or having your vehicle stolen after you pull it from the garage.<br/><br/>" + "<t size='1.4' color='#c40000'>EXPLOITING</t><br/>Knowingly using a bug or glitch to your advantage or another's detriment is not allowed. This includes but is not limited to:<br/>Being downed/restrained and still having the ability to move. Hiding in places that conceal your player in a manner that is not intended such as, in rocks, sandbags, vehicles, static objects (crashed helis and vehicles placed) ect. The use of an increased DPI in order to avoid a fight or death, or any other situation where the unnatural movement speeds would impede an interaction or immersion. Exiting or driving any vehicle or helicopter, locked or unlocked, while downed or in restraints. Entering a player's house by any means other than thru an unlocked/open door. (Including shed skylights) The unflip option cannot be used to elevate any vehicle to any position in which it is not able to be driven to. Dropping Y inventory to prevent other players from climbing ladders, entering doors, or to block roadways is not allowed.<br/><br/>"],
        ["Support / Reports", "<t size='1.4' color='#00fff2'>Support / Reports</t><br/>Need support or want to submit a report? Reach us on <a colorLink='#02b2f7' href='https://discord.gg/TdNVfcFcx6'>discord</a>.<br/><br/>"],
        ["Controls", "<t size='1.4' color='#00fff2'>Controls</t><br/>LoonyBin offers a wide range of custom controls for doing specific actions.<br/><t color='#00fff2'>Custom 1-17</t> can be changed in: <t color='#a3a3a3'>ESC > Configure > Controls > Custom controls.</t><br/><br/>" + "
				<t color='#00fff2'>1:</t> Wanted Menu <br/>
				<t color='#00fff2'>5:</t> Open phone messaging<br/>
				<t color='#00fff2'>6:</t> Activate vehicle nitrous<br/>
				<t color='#00fff2'>8:</t> Medic Respond (ANG only)<br/>
				<t color='#00fff2'>9:</t> Accept Admin Event (When Available)<br/><br/>

				<t color='#00fff2'>TAB:</t> Surrender<br/>
				<t color='#00fff2'>H:</t> Holster active weapon<br/>
				<t color='#00fff2'>Y:</t> Open player menu<br/>
				<t color='#00fff2'>U:</t> Lock and unlock cars<br/>
				<t color='#00fff2'>F:</t> Siren (if cop or paramedic)<br/>
				<t color='#00fff2'>Shift + F:</t> Phaser Siren (if cop)<br/>
				<t color='#00fff2'>Ctrl + F:</t> Yelp Siren (if cop)<br/>
				<t color='#00fff2'>Shift + L:</t> Cop Lights (if cop)<br/>
				<t color='#00fff2'>T:</t> Vehicle trunk<br/>
				<t color='#00fff2'>Shift + B:</t> Spray Can (Subscriber Only)<br/><br/>

				<t color='#00fff2'>Custom 1:</t> Open player menu<br/>
				<t color='#00fff2'>Custom 2:</t> Pickup nearby items<br/>
				<t color='#00fff2'>Custom 3:</t> Open virtual inventory<br/>
				<t color='#00fff2'>Custom 4:</t> Restrain hotkey<br/>
				<t color='#00fff2'>Custom 5:</t> Toggle AutoRun,AutoDrive<br/>
				<t color='#00fff2'>Custom 6:</t> Use Virtual FAK<br/>
				<t color='#00fff2'>Custom 7:</t> Toggle Lethals (If cop)<br/>
				<t color='#00fff2'>Custom 8:</t> Speed radar (if cop)<br/>
				<t color='#00fff2'>Custom 9:</t> Activate spike strip<br/>
				<t color='#00fff2'>Custom 10:</t> Interaction key<br/>
				<t color='#00fff2'>Custom 11:</t> Consume Red Gull<br/>
				<t color='#00fff2'>Custom 12:</t> Toggle Earplugs<br/>
				<t color='#00fff2'>Custom 13:</t> Lockpick<br/>
				<t color='#00fff2'>Custom 15:</t> Detonate Suicide Vest<br/>
				<t color='#00fff2'>Custom 16:</t> Open Wanted Menu (Cop/BH Only)<br/>
				<t color='#00fff2'>Custom 17:</t> Nod Yes<br/>
				<t color='#00fff2'>Custom 18:</t> Nod No<br/>
				<t color='#00fff2'>Custom 19:</t> Point<br/>
				<t color='#00fff2'>Custom 20:</t> Halt/Stop<br/>
				"], ["Chat Commands", "<t size='1.4' color='#00fff2'>Chat Commands</t><br/>The following chat commands can be used:<br/><br/>" + "
				<t color='#00fff2'>!comp</t> - Check Mailbox for compensations, offline house purchases, ...<br/>
				<t color='#00fff2'>!911</t> <t color='#007a74'>message</t> - Emergency request To MaxSec<br/>
				<t color='#00fff2'>!311</t> <t color='#007a74'>message</t> - Emergency request To ANG<br/>
				<t color='#00fff2'>!r</t> <t color='#007a74'>message</t> - Respond to last player that texted you<br/>
				<t color='#00fff2'>!e</t> <t color='#007a74'>emotename</t>- Plays given emote<br/>
				<t color='#00fff2'>!spray</t> - Change spray can spray<br/>
				<t color='#00fff2'>!stats</t> - Check MyLoonyBin stats<br/>
				<t color='#00fff2'>!loginbonus</t> - Receive your login bonus loot<br/>
				"]]]];
switch (_type) do {case "init": {{private _index = _forEachIndex;
                _x params["_entryTitle", "_entryDesc", "_subArray"];
                _treeCtrl tvAdd[[], _entryTitle];
                 { _x params["_subTitle", "_subDesc"];
                    _treeCtrl tvAdd[[_index], _subTitle];}
                forEach _subArray;} forEach _treeItems;
            tvExpandAll _treeCtrl;
            _treeCtrl ctrlSetEventHandler["TreeSelChanged", "['getText', _this select 0, _this select 1] call AP_fnc_welcomeUIConfig; false"];
            _treeCtrl tvSetCurSel[0, 0];}; case "getText": {private _plb_display = findDisplay 17000;
                if (isNull _plb_display) exitWith {};
                private _treeCenterText = _plb_display displayCtrl 17501;
                _selection params["_index1", "_index2"];
                private _text = "";
                if ((count _selection) isEqualTo 1) then {_text = (_treeItems select _index1) select 1;} else {
                    private _array = (_treeItems select _index1) select 2;
                    _text = (_array select _index2) select 1;};
                if (_text != "") then {private _originHeight = _treeCenterText getVariable["wui_min_height", 1.09];
                    private _ctrlPos = ctrlPosition _treeCenterText;
                    _treeCenterText ctrlSetStructuredText parseText(_text);
                    private _ctrlHeight = ctrlTextHeight _treeCenterText;
                    if (_ctrlHeight < _originHeight) then {_ctrlHeight = _originHeight;};
                    _ctrlPos set[3, _ctrlHeight];
                    _treeCenterText ctrlSetPosition _ctrlPos;
                    _treeCenterText ctrlCommit 0;};};
        default {};};
