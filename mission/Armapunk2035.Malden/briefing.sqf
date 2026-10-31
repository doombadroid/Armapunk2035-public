if !(hasInterface) exitWith {};
waitUntil {!isNull player && player == player};
if (player diarySubjectExists "loonybin") exitWith {};   // LoonyBin fix: was "rules" (never created) -> guard never tripped -> duplicate records
player createDiarySubject["loonybin", "Gaming LoonyBin"];
player createDiarySubject["generalrules", "General Rules"];
player createDiarySubject["redzones", "Illegal Areas"];
player createDiarySubject["laws", "Laws"];
player createDiarySubject["coprules", "Cop Rules"];
player createDiarySubject["civrules", "Civ Rules"];
player createDiarySubject["Features", "Features"];
player createDiarySubject["controls", "Controls"];
player createDiarySubject["chatcommands", "Chat Commands"];
player createDiaryRecord["loonybin", ["Discord", "
					Join the community on Discord:<br/><br/>
					https://discord.gg/TdNVfcFcx6<br/><br/>
					Report players, appeal bans, and hang out.<br/><br/>
					"]];
player createDiaryRecord["generalrules", ["General Rules", "
				1: Vehicles are not a weapon. You can use a vehicle to defend yourself if you are in immediate danger and the threat is directly in front of your vehicle. Bannable uses of vehicles include but are not limited to: running innocent people over for fun, ramming into stationary vehicles with the intent to blow them up, turning around to run over someone shooting at you from behind.<br/>
				2: Vehicle mounted weapons fall under the same rules as any other weapon.<br/>
				3: Disconnecting or re-spawning while being engaged by another player is a bannable offense (Combat Logging). Claims of RDM/other rule violations are not a defense for Combat Logging.<br/>
				4: Illegal areas are marked in red text on the map and include drug fields, drug processing areas, drug dealers, black market factories, cartels, and rebel outposts.<br/>
				5: Players in and around illegal areas are responsible for their own survival as <b>RDM RULES DO NOT APPLY</b>. See our forums for a detailed list of the illegal area ranges.<br/>
				6: Random Death Matching (RDM):  Is the act of killing a player outside of an illegal area without valid RP reason and communication via in-game direct voice communication or cell phone text messages.  RDM is  a bannable offence. Example: you tell someone to STOP and put their hands on their head. If they comply you can role-play out robbing them, if they do not you are allowed to kill. If someone complies with your demands, you must continue the roleplay and find another reason to kill them.<br/>
				7: Warning shots are allowed at helicopters that are hovering or attempting to land near your position. If the helicopter does not leave the area after multiple warning shots, you may attempt to disable the helicopter. Remember, sufficient time must be given to allow the pilot to react and decide to leave.<br/>
				8: The rules are not designed to shield players from the consequences of their own actions or lack of awareness.   It is not considered RDM if players die for reasons such as: ignoring demands from any player, trying to drive through on-going gunfire, running into an active firefight, etc.<br/>
				9: Players must have in-game sound effects turned up so they can hear direct voice communication from other players.<br/>
				10: The use of racist, misogynistic, or hate speech will result in a permanent ban from the LoonyBin Servers.<br/>
				11: As a Bounty Hunter, do not profit by arresting your friends. Additionally, do not share your reward with the bounty that you have arrested. Such funds will be removed from your respective bank accounts and depending on severity, may result in a ban.<br/>
				12: For a more in-depth look at our rules, visit our website listed above.<br/>
				"]];
player createDiaryRecord["redzones", ["Illegal Areas (Redzones)", "
				Illegal Areas (marked on the map as red markers) are Kill on Sight (KOS) zones. As such RDM RULES DO NOT APPLY. Some of these areas have extended KOS areas which surround the marker but may not necessarily be displayed on the map. Below is a summary of the redzones on LoonyBin.<br/><br/>
				Persistent 300 Meter Redzones:<br/>
				1. All Drug/Illegal Item Fields<br/>
				2. All Drug/Illegal Item Processors<br/>
				3. All Rebel Bases<br/>
				4. Black Market Production Facilities<br/>
				5. Cartel Locations<br/>
				6. Aircraft Carrier<br/><br/>
				Persistent Specific-Range Redzones:<br/>
				1. Drug Dealers/Wongs Food and Liquor: (Interaction Range)<br/>
				2. Drug Runner Locations: (50m Radius from the vendor)<br/>
				3. Turtle Zones: (Red Circle on Map)<br/><br/>
				Event-Specific Redzones:<br/>
				1. Gas Station Robberies: (Immediate Area - Only armed players may be killed)<br/>
				2. Federal Reserve Robbery / Prison Break / Bank Robbery: (Immediate Area. These zones of conflict can understandably stretch across a relatively wide area; so please use your best judgment when engaging contacts who you know may not be involved in the event. Administrators will handle reports or RDM from near these locations on a case-by-case basis.)<br/><br/>
				Fixer Territory (Weekly War):<br/>
				Three towns belong to fixers -- Larche to the Lightrunners, Chapoi to the Crusaders, La Port to the Silent Partners. La Trinite belongs to nobody and never will. Every week two of the three fixers go to war and the third sits it out; the current matchup is on the FIXER card in your gang app, and you are told which territory you have entered as you cross into it.<br/>
				If your gang is aligned with one of the two fixers at war, then inside EITHER of those two fixers' territories you and any gang aligned with the other are KOS to each other, both ways, and RDM RULES DO NOT APPLY between you. Their names render red to you and yours render red to them. Nothing else changes: not the neutral fixer's town, not La Trinite, not the open road, and not gangs who are unaligned or aligned with the fixer sitting the week out -- those are ordinary players and shooting them is an ordinary RDM report.<br/>
				Solo players and gangs with no fixer are never KOS under this rule anywhere, and are never a valid target under it.<br/><br/>
				Any player who is within the boundaries identified above may be killed or downed by any player at any time. You may be outside of an Illegal Area and fire upon those who are inside without initiation of roleplay.<br/><br/>
				In addition; any player whose name displays as RED may be fired upon without fear of repercussion. Red Names indicate that the player is either in a Gang War with you, or that their group is in a firefight with your group.<br/>
				"]];
player createDiaryRecord["laws", ["Laws", "
				1: Killing of another player in a non self defense situation is illegal.<br/>
				2: Stealing any vehicle is illegal.<br/>
				3: Cannibalism is illegal.<br/>
				4: Breaking people out of jail is illegal.<br/>
				5: Possession of illegal materials such as weed, smash, boost, black lace, etc. is illegal.<br/>
				6: Police will seize any Ifrit or Armed vehicle they capture, resulting in its removal from your garage. Additionally, any vehicle with more than $5,000 worth of illegal items may also be seized.<br/>
				7: Taking someone hostage is a illegal act.<br/>
				8: As a civilian, only guns purchased at city gun stores are considered legal when you have the required licence. All other guns are illegal including: Guns purchased from the rebel bases, guns obtained without a licence, and guns picked up from police officers. The SDAR is illegal, even if it may be purchased from the gun store.<br/>
				9: Interfering with an arrest after being warned will warrant an arrest with ticket and possible jail time.<br/>
				10: Armed robbery is an illegal act.<br/>
				11: Being inside of, or stealing money from the Federal Reserve / Bank of Altis is illegal.<br/>
				12: You are not allowed to carry weapons unholstered while in town.<br/>
				13: Any form of impersonating an officer is considered illegal.<br/>
				14: If a killing happens in self defence and you want to ensure your innocence, you must contact the police via 911's or in-person as soon as possible. If you wait to inform them of the self-defense homicide, your chances of being ticketed/jailed increase significantly!<br/>
				"]];
player createDiaryRecord["coprules", ["General", "
				1: Cops must stay in police channels with their current game name.<br/>
				2: Cops are not allowed to leak information to civilians. this is grounds for dismissal from the force.<br/>
				3: Cops may be demoted for selling weapons to civilians or lower grade officers.<br/>
				4: Cops are not allowed to stay in an illegal area for more than 2 minutes without cause.<br/>
				5: All people around a crime are able to be restrained and held for a maximum of 10 minutes until the issue is resolved.<br/>
				6: Any police engagement must be complete before vehicles are able to be impounded/seized.<br/>
				7: No ticket/arrest will be issued more than one time per bounty.<br/>
				8: Less-lethal ammunition should be loaded unless given authorization by the appropriate officer on-scene.<br/>
				9: Civilians can be arrested for interfering with an officer or failing to follow commands such as vacating an area and moving vehicles.<br/>
				10: A person or vehicle cannot be searched without consent unless the officer has probable cause and states such at the time of the search.<br/>
				11: Cops must have undivided loyalty to MaxSec at all times when in uniform, and must not grant special favours for civilians, or take bribes or payments of any sort, whether monetary or otherwise.<br/>
				"]];
player createDiaryRecord["coprules", ["Chain of Command", "
			The highest ranking officer on duty is in charge of the police force as a whole on the server. The highest ranking officer in each City/Patrol Group is responsible to lead the officers under his/her care with all due diligence expected of his/her position. Report any misconduct of officers on our forums for review by the Lieutenants and Captains<br/><br/>

			Police Chain of Command:<br/>
			1. Chief of Police<br/>
			2. Captain<br/>
			3. Lieutenant<br/>
			4. Sergeant<br/>
			5. Corporal<br/>
			6. Patrol Officer<br/>
			7. Cadet<br/>
			"]];
player createDiaryRecord["civrules", ["Civ Rules", "
				1: Racist, misogynist, hateful, etc. speech is not tolerated. Being a bigot is grounds for a permanent ban.<br/>
				2: Once killed you are not allowed to seek revenge on the person or group that killed you without re-initiation of roleplay.<br/>
				3: Civilians cannot keep anyone restrained or hostage for more than ten minutes without gaining the consent of the victim. If you have been restrained by civilians for 10 minutes or more, you may disconnect without fear of punishment.<br/>
				"]];
player createDiaryRecord["Features", ["Features", "
					1: Player Housing: The first step to owning a home is obtaining a home owner license from the DMV. With the license, find a vacant home in the world and you may see a buy house action menu option. You may lock doors of your homes and with access to Home Improvements, place storage containers in your homes. Larger and more expensive homes will offer more storage ability. You have the ability to spawn at your home upon death. Additionally, you may own garages and access your garage from them! (Be careful, vehicles larger than the garage may result in explosions).<br/>
					2: Hostage Taking: You can take hostages in LoonyBin Life by having another player press the TAB key, this will activate surrender mode. You may also shoot your target with a less-lethal weapon. When your target is in surrender mode or downed, you can restrain, escort, put into, and pull them out of vehicles.<br/>
					3: Cartels: Gangs may take control of various cartel locations in order to gain financial or other benefits. Claim your territory!<br/>
					4: Full Saving: On LoonyBin Life, everything saves. Your location, your equipment, your inventory items, and your vehicles.<br/>
					5: Drug Running Missions: Proceed to Drug Runner points and race against time to deliver a plane full or drugs to another location! Successful runs will reward you greatly; failing will result in monetary losses, however. (REQUIRES APEX DLC)<br/>
				"]];
player createDiaryRecord["controls", ["Controls", "
				LoonyBin offers a wide range of custom controls for doing specific actions.<br/>
				Custom 1-17 can be changed in:<br/>
				ESC > Configure > Controls > Custom controls.<br/><br/>


				1: Wanted Menu <br/>
				5: Open phone messaging<br/>
				6: Activate vehicle nitrous<br/>
				8: Medic Respond (TT only) <br/>
				9: Accept Admin Event (When Available) <br/>

				TAB: Surrender<br/>
				H: Holster active weapon<br/>
				Y: Open player menu<br/>
				U: Lock and unlock cars<br/>
				F: Siren (if cop or TT)<br/>
				Shift + F: Phaser Siren (if cop)<br/>
				Ctrl + F: Yelp Siren (if cop)<br/>
				Shift + L: Cop Lights (if cop)<br/>
				T: Vehicle trunk<br/><br/>
				Shift + B: Spray Can (Subscriber Only)<br/>

				Custom 1: Open player menu<br/>
				Custom 2: Pickup nearby items<br/>
				Custom 3: Open virtual inventory<br/>
				Custom 4: Restrain hotkey<br/>
				Custom 5: Toggle AutoRun,AutoDrive<br/>
				Custom 6: Use Virtual FAK<br/>
				Custom 7: Toggle Lethals (If cop)<br/>
				Custom 8: Speed radar (if cop)<br/>
				Custom 9: Activate spike strip<br/>
				Custom 10: Interaction key<br/>
				Custom 11: Consume Red Gull<br/>
				Custom 12: Toggle Earplugs<br/>
				Custom 13: Lockpick<br/>
				Custom 15: Detonate Suicide Vest<br/>
				Custom 16: Open Wanted Menu (Cop/BH Only)<br/>
				Custom 17: Nod Yes<br/>
				Custom 18: Nod No<br/>
				Custom 19: Point<br/>
				Custom 20: Open Cyberdeck menu (aim at your target first; Cyberdeck required)<br/>
				"]];
player createDiaryRecord["chatcommands", ["Chat Commands", "
					!comp - Check Mailbox for comp<br/>
					!911 'messagehere' - Emergency request to MaxSec<br/>
					!311 'messagehere' - Emergency request to Trauma Team<br/>
					!r 'messagehere' - Respond to last player that texted you<br/>
					!e 'emotename'- Plays given emote<br/>
					!spray - Change spray can spray<br/>
					!stats - Check MyLoonyBin stats<br/>
					!loginbonus - Receive your login bonus loot<br/>
					"]];
