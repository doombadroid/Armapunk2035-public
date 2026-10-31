if (814 in AP_completedQuests) exitWith {};
private _civMinutes = A_stats_civTime;
private _tutorialProgress = profileNamespace getVariable["AP_tutorialProgress", -1];
private _exit = false;
if (_tutorialProgress isEqualTo 14) exitWith {};
switch (true) do {case ((_tutorialProgress isEqualTo - 1) && !(AP_tutorialActive)): {if (_civMinutes >= 60 && _civMinutes <= 180) then {
                private _action = ["Since you have less than 3 hours on LoonyBin, would you like to do the tutorial?", "LoonyBin Tutorial", "Yes", "No"] call BIS_fnc_GUIMessage;
                if !(_action) exitWith {_exit = true};};
            if (_exit) exitWith {};
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Tutorial Started<br/><br/></t></t></t>Welcome to the LoonyBin community and we hope this tutorial will help you start out!<br/><br/>Since you are quite new to LoonyBin, a tutorial for you has started!<br/><br/>"], "warning"] spawn AP_fnc_handleMessage;
            AP_tutorialActive = true;
            AP_tutorialQuestsActive = true;
            profileNamespace setVariable["AP_tutorialProgress", 0];
            uiSleep 30;};
    case ((_tutorialProgress >= 0) && !(AP_tutorialActive)): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Tutorial Resumed<br/><br/></t></t></t>First of all, welcome back to the LoonyBin community and we hope this tutorial will continue to help you start out!<br/><br/>"], "warning"] spawn AP_fnc_handleMessage;
            AP_tutorialActive = true;
            AP_tutorialQuestsActive = true;
            uiSleep 30;};}; if (_exit) exitWith {};
private _tutorialProgress = profileNamespace getVariable["AP_tutorialProgress", -1];
switch (_tutorialProgress) do {case (0): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>LoonyBin Server Info<br/><br/></t></t></t>Press escape on your keyboard to find the server links.<br/><br/>Join our Discord: https://discord.gg/TdNVfcFcx6"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 1];
            [1] spawn AP_fnc_tutorialNewPlayer;};
    case (1): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Server Rule - VDM Rule<br/><br/></t></t></t>VDM is using your vehicle as an OFFENSIVE weapon.<br/><br/>Dropping a sling loaded vehicle from a helicopter to intentionally kill a player or cause destruction by -bombing- them is also considered VDM, and is not allowed.<br/><br/>Armored Vehicles may be used in an offensive manner against ONLY other armored vehicles. (Strider/Hunter/Ifrit) due to the difficulty in stopping those types of vehicles.<br/><br/>You may hit a player with your vehicle only if they are firing at you, and blocking your direct path of travel. You may not maneuver to intentionally hit a player.<br/><br/>Closing a gate on a vehicle causing it to explode that results in the death of other players is considered VDM.<br/><br/>"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 2];
            [2] spawn AP_fnc_tutorialNewPlayer;};
    case (2): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Server Rule - RDM Rule<br/><br/></t></t></t>RDM is killing/downing another player without any type of HOSTILE role-play being initiated and reasonable amount of time for the target to react.Intentions must be clearly stated to the intended target, and they MUST be given reasonable time to react. Text messages through phone to the player is a allowed method of starting RP. Initiation last 5 minutes from the time instructions are given.<br/><br/>Revenge killing is NOT a form of role-playing reasoning.<br/><br/>RDM rules do NOT apply within ILLEGAL areas.<br/><br/>You must make sure you have your in-game effects volume turned up! This is the sound level for your direct communication. VON is used for Vehicle, Group, and Side.<br/><br/>No type of initiation may be done through direct chat, side chat, 911/311, or vehicle via typing. All initiation must be done with your voice or via text message to a specific player.<br/><br/>If a player complies and does what you ask, that does not give you the right to still kill them. You need to have a legit RP reason why they must still die and not having any money when you rob them is not enough. This includes people who are in restraints and have complied.<br/><br/>LoonyBin aggression system - Red = Dead<br/>"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 3];
            [3] spawn AP_fnc_tutorialNewPlayer;};
    case (3): {
            private _action = ["Do you understand these main important RDM and VDM rules? You aren't exempt from any rules if you don't know them.", "LoonyBin", "Yes", "No"] call BIS_fnc_GUIMessage;
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Useful Keybinds<br/><br/></t></t></t>U - Unlock/lock vehicles and doors (As long as you have keys to the vehicle/the house).<br/><br/>Y - Brings up your cell phone. It has many useful applications on it.<br/><br/>T - Access Virtual Inventory (Look at a vehicle/crate and press T to open the menu).<br/><br/>Caps Lock - Voice chat (Make sure you’re talking in the right channel else people will not hear you). This is the only LoonyBin key bind you can change in Arma 3 settings.<br/><br/>Scroll wheel - Scrolling is used for most interactions (ATMs, Medical, player, gather actions) on LoonyBin. This also is used by most Arma 3 interactions. You must press space on the highlighted option to activate it.<br/><br/>H - Holsters your weapon. You may press 1 or 2 on your keyboard to bring them out again.<br/><br/>Tab - Raises your hands. At times you may be asked by criminals, bounty hunters, or the Police to raise your hands.<br/><br/>2x Left Ctrl - Lowers your weapon so that you are not pointing it at other players. Press again to raise it.<br/><br/>Custom Action 12 - Puts in earplugs. You must set the lowered volume first in the phone settings.<br/>"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 4];
            [4] spawn AP_fnc_tutorialNewPlayer;};
    case (4): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Quest System<br/><br/></t></t></t>LoonyBin's Quest System contains seasonal and non-seasonal quests. All factions have different quests to choose from. Each completetion of a quest, can reward you with buffs, money, money reduction and more!"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 5];
            [5] spawn AP_fnc_tutorialNewPlayer;};
    case (5): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Talent System<br/><br/></t></t></t>While playing on LoonyBin you will gain experience to level up and acquire talent points.<br/><br/>Talents allow you to do certain things in-game or help you make money by giving you certain advantages.<br/><br/>There are 19 talent points you can have at the same time out of a total of 56, so you will have to pick wisely. But do not worry, you can always unlearn a talent at all times using your phone, although it will charge you a fee of $1,500 directly from your bank account.<br/><br/>For more information regarding talents, refer to the Talents Guide on the wiki"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 6];
            [6] spawn AP_fnc_tutorialNewPlayer;};
    case (6): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Whitelisted Factions<br/><br/></t></t></t>LoonyBin has whitelisted only other factions besides civilian. The TT (Medics) and MaxSec (Police) strive to help the island of Altis! You can apply to become an officer or medic, via our forums!"], "warning"] spawn AP_fnc_handleMessage;
            private _action = ["Would you like to see more info regarding the police?", "LoonyBin MaxSec", "Yes", "No"] call BIS_fnc_GUIMessage;
            if (_action) then {[] spawn AP_fnc_policeRecruit};
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 7];
            [7] spawn AP_fnc_tutorialNewPlayer;};
    case (7): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Your Stats<br/><br/></t></t></t>Type !stats in chat to see your leaderboard standing in-game."], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 8];
            [8] spawn AP_fnc_tutorialNewPlayer;};
    case (8): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Housing Guide<br/><br/></t></t></t>The talent Citizenship this will allow you to purchase a home owners license.<br/><br/>You may also purchase the Home Owners license at either a Home Improvement store or a DMV; this is what allows you to purchase a home.<br/><br/>Homes will go back on the market for the standard market price after the owner has not logged on for 30 days. You must play within a 30 days period to keep ownership of your houses.<br/><br/>Players can own up to Five(5) buildings, both houses, and garages. With an additional talent Leadership this will allow you to designate a home of your choice to be a gang HQ.<br/><br/>Designating a house as a gang HQ will give access to an additional spawn point for all gang members, access to all doors for gang members that are level 4 or above, and access to storage for gang members who are level 3 or above.<br/><br/>To find out if a home is for sale, walk up to the desired home and with your scroll wheel select the green option -House Menu-, this will tell you the property value and if it is currently owned.<br/><br/>To find new homes for sale the player can check out the House Menu in-game.<br/><br/>"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 9];
            [9] spawn AP_fnc_tutorialNewPlayer;};
    case (9): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Gangs and Rebel Life<br/><br/></t></t></t>You can fight for capturable turfs, cartels, fight at federal events and more! Rebels have access to exclusive weaponry at their disposal. You may rack up a high bounty while pursuing highly illegal activities.<br/><br/>Cops will be your number one threat, but don't worry they have lower caliber weapons, usually!<br/><br/>Gangs have the ability in gang wars. Enemy gang members become automatically red, and can help you gain war points and New Drachma!<br/><br/>New Drachma (ND) is exclusively used at rebels as an alternative to money. You can purchase weapons, clothing, and vehicles with ND.<br/><br/>You can join/create a gang or group. Gangs are managed throught the app on your phone, but can also set up a gang house. Groups can have passwords and names, so only your buddies get in!<br/><br/>"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 10];
            [10] spawn AP_fnc_tutorialNewPlayer;};
    case (10): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Bounty Hunter License<br/><br/></t></t></t>You want to become a bounty hunter?<br/><br/>As a <t color='#FF0000'>bounty hunter</t> you must adhere to certain rules or risk the removal of your license or possibly even being banned from the server.<br/><br/><t color='#FF0000'>It is very important</t> to understand that you are still a civilian, and must obey all rules other civilians do.  Shooting another player to stun them with rubber bullets is still considered RDM if you do not engage verbally first with a warning. Do not attack unprovoked, even to stun, and always give them a chance to comply before opening fire.<br/><br/>As a bounty hunter you are not to interfere when MaxSec are present, your job is to bring in criminals when <t color='#00FF00'>police forces are not present</t>."], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 11];
            [11] spawn AP_fnc_tutorialNewPlayer;};
    case (11): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Money Making Guide<br/><br/></t></t></t>Legal runs are anything that takes place in non-illegal areas that aren’t KOS zones! These include gathering Apples, Peaches, Toxic Slurry, Redshift, Mining at a quarry etc. Typically you can either sell them as is, or process them if needed. For example: mine uncut diamonds at a quarry, process them into cut diamonds, then sell them at any jewelry store!<br/><br/>Illegal runs are more dangerous, scary, but highly rewarding for your time. Illegal drugs include Weed, Heroin, Smash, Black Lace, Glitter, Moonshine, Scotch etc. Most of these sought after drugs require processing, but can also possibly be double processed. Drug runners, including boats and planes can help you ship drugs all over the island! Black Lace is a more busy work drug as it requires more ingredients, but the payoff is worth it!<br/><br/>You can see full list of each run and what you need to complete them on our wiki page via https://discord.gg/TdNVfcFcx6"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep 120;
            profileNamespace setVariable["AP_tutorialProgress", 12];
            [12] spawn AP_fnc_tutorialNewPlayer;};
    case (12): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Tutorials<br/><br/></t></t></t>We also have a tutorial system in place to help you get started, open up your phone by pressing y and take a quick peek at the tutorials if you'd like"], "warning"] spawn AP_fnc_handleMessage;
            uiSleep(random[15, 25, 50]);
            profileNamespace setVariable["AP_tutorialProgress", 13];
            [13] spawn AP_fnc_tutorialNewPlayer;};
    case (13): {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Tutorial Complete<br/><br/></t></t></t>You have finished the entire tutorial. Welcome to Gaming LoonyBin!"], "warning"] spawn AP_fnc_handleMessage;
            profileNamespace setVariable["AP_tutorialProgress", 14];};};