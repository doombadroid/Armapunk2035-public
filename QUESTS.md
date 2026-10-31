# LooneyBin / Armapunk quest catalogue — deobfuscated

Extracted from `core/config/fn_questsCfg.sqf` (minified, 24 KB, 2 lines) on 2026-08-12.

Row shape: `[id, side, questType, multiStage, qreserved, ?, [xp,?,cash], [[virtualItems],[gear]], name, requirement, award]`

`questType` **1** = restart-cycle (resets every server restart) · **2** = LIFETIME (permanent).

**⚔** marks a quest whose wording requires another player — it cannot be finished solo.


## Civilian — Easy  ·  16 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 101 | **Speedster** | Blow a speed camera 10 times | $2,500 |
| 102 | **Pardon Me Officer?** ⚔ | Get a pardon from the cops | $5,000 |
| 103 | **Im Dead!** | Get revived by an TT paramedic  | $10,000 |
| 104 | **Blood For The Blood God** | Use 5 Blood bags on a person | $5,000 |
| 105 | **2nd Amendment** | Buy a weapon from gun store | $2,500 and Tactical vest |
| 106 | **Shake n bake** | Take a bong rip | 1 of each medical dispensary item |
| 107 | **player100 Life Saver** ⚔ | Revive another player | $5,000 |
| 108 | **Lines In The Bathroom** | Snort 2 lines of cocaine | $4,500 and 1 cocaine |
| 109 | **Diamonds Are A Girls Best Friend** | Sell 10 flawless diamonds | $5,000 and 5 flawless diamonds |
| 110 | **Cut Above The Rest** | Sell 25 Cut diamonds | $6,000 and 9 flawless diamonds |
| 111 | **Oil** | Sell 25 processed oil | 3 rubber |
| 112 | **Fizhies** | Collect and sell 5 fish with your bare hands | $5,000 |
| 113 | **Excaved** | Get a full inventory from excavation. | $9,850 |
| 114 | **Timber** | Chop down 25 tree's | $4,600 |
| 115 | **Speed Racer** | Complete any time trial | $7,500 |
| 116 | **Sky Diver** | Go Sky-Diving at the Tourism NPC | $3,500 |

## Civilian — Medium  ·  13 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 151 | **I Am The Law** ⚔ | Kill a cop | $7,500 |
| 152 | **Don't Judge Me** ⚔ | Attend jury duty | $10,000 |
| 153 | **Shank'd** ⚔ | Shank a fellow inmate | $10,000 |
| 154 | **Pocket Cash** | Rob a gas station | $9,800 |
| 155 | **GTA** | Lockpick a vehicle | $6,500 |
| 156 | **Cop Chop** ⚔ | Chop a cop hatchback | $12,500 |
| 157 | **420 Blaze It** | Smoke a pre-rolled joint | 5 pre-rolled joints |
| 158 | **Thats A Rush** | Snort a line of cocaine | 5 cocaine |
| 160 | **Plastic Straws** ⚔ | Kill a sea turtle | 10 Turtle Meat, 1 Sdar and $7,900 |
| 161 | **I Am An Addict** | Use lsd | 5 lsd |
| 163 | **Le Funny Number** | Pick 69 Barley | $420 and 21 barley |
| 164 | **Burn Baby Burn!** | Light a house on fire | $12,500 and 1 arsonistkit |
| 165 | **Cleaning Up The Streets** ⚔ | Kill enemy gang member in gang war | $11,000 |

## Civilian — Hard  ·  13 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 201 | **Chop Chop** | Chop police hummingbird | $14,000 |
| 202 | **No Armor? No Power** | Chop a police ifrit | $20,000 |
| 203 | **No Law? No Order!** ⚔ | Kill 10 MaxSec officers | $19,000 |
| 204 | **Yoink** ⚔ | Claim another players frit | $15,000 |
| 205 | **Chop a Orca** ⚔ | Chop a civilian orca | $26,000 |
| 206 | **Chop a Civilian Ifrit** | Chop a civ frit  | $32,000 |
| 207 | **World Burn** | Light 2 houses on fire | 1 Phone Bomb |
| 208 | **Meth Dealer** | Sell 90 Meth | 15 meth |
| 209 | **Uranium Dealer** | Sell 90 processed uranium | 20 Uranium |
| 210 | **Crank Dealer** | Sell 90 crank | 18 Crank |
| 211 | **Scotch Dealer** | Sell 90 25 year old scotch | 16 Scotch |
| 212 | **Moonshine Dealer** | Sell 90 moonshine | 20 moonshine |
| 213 | **Drug Runner** | Complete 4 drug running missions | $35,000 |

## Civilian — Completionist  ·  1 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 250 | **Completionist** | Activate this when you have completed all previous quests | $35,000 |

## TT / Medic  ·  7 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 251 | **Defib Paramedic** ⚔ | Revive 10 people | $20,000 |
| 252 | **Adrenaline Boost** | Use 10 adrenaline Shots | $15,000 |
| 253 | **Bloodbagger** | Use 10 bloodbags on others | $30,000 |
| 254 | **Repair Man** | Repair 2 buildings | $35,000 |
| 255 | **Singed Eyebrows** | Report for firefighting duty | $10,000 |
| 256 | **F.A.K. Off** | Use 3 virtual FAKs | $1,000 |
| 257 | **New Whip** | Buy any vehicle | $2,500 |

## MaxSec / Cop  ·  15 quests  ·  questType 1 (restart cycle)

| id | quest | requirement | award |
|---|---|---|---|
| 351 | **The Warden** ⚔ | Arrest 5 people | $24,000 |
| 352 | **Ticket Master** | Hand out 10 tickets | $10,000 |
| 353 | **Restrain Frenzy** ⚔ | Restrain 10 criminals | $12,500 |
| 354 | **Tow Truck** | Impound 10 Vehicles | $10,000 |
| 355 | **Bigfoot Hunter** | Apply a tracker 3 times | $5,000 |
| 356 | **Pardon Me?** ⚔ | Pardon 3 players | $2,500 |
| 357 | **MaxSec Medic** ⚔ | Revive 5 civs | $5,000 |
| 358 | **Bad Cop** ⚔ | Search 10 criminals in a drug field | $10,000 |
| 359 | **Patrol Officer** | Spend 25,000 on land vehicles | $5,000 |
| 360 | **Bad Gamer** | Equip loadout 10 times | $4,500 |
| 361 | **Gear'd** | Re-gear 10 times | $4,500 |
| 362 | **Strip Searcher** ⚔ | Disarm 2 civilians | $7,500 |
| 363 | **Big Bust** ⚔ | Seize 50,000 worth of illegal items from vehicles | $10,000 |
| 364 | **Blood God** | Bloodbag yourself 5 times | $3,500 |
| 365 | **Battle Buddy** ⚔ | Revive an MaxSec officer 3 times | $6,500 |

## Civilian — LIFETIME  ·  45 quests  ·  questType 2 (lifetime)

| id | quest | requirement | award |
|---|---|---|---|
| 451 | **Red Gull Glugger** | Drink 5,000 Redgulls | $50,000 + 50 redgulls and Redgulls will provide effects for 4 minutes. |
| 452 | **FAK This** | Use 150 Virtual FAKS | 42 FAK kits + 25% chance to not consume virtual FAK on use. |
| 453 | **7-11 Maniac** | Rob a gas station 25 times | $25,000 + 5 PDW's |
| 454 | **The Unrestrainer** ⚔ | Lockpick 150 players from cop restraints | $50,000 + 2 Flashbangs + 10% increased chance to lockpick a player out of cuffs. |
| 455 | **The Grinch** | Open 150 Admin Gifts | $75,000 + 10 Admin Gifts |
| 456 | **Adrenaline Demon** | Use 150 Adrenaline Shots in combat | $10,000 + 20% chance not consume Adrenaline Shot and 5% chance to automatically use Adrenaline Shot from inventory when downed. |
| 457 | **Michael Myers** ⚔ | Execute 250 people | $30,000 + 5 organs + Ability to skin scalps with a Skinning Kinfe. |
| 458 | **Field Medicine** ⚔ | Defib 300 people | 1 RPG + 1 RPG Projectile + 15% increase to speed when using a defibrillator. |
| 459 | **Locksmith** | Successfully lockpick 100 MaxSec Vehicles | $45,000 + 10% chance to lockpick any police vehicle. |
| 460 | **Dp Mission** | Complete 100 DP Missions | 5 Gold Nuggets |
| 461 | **High Value Miner** | Sell 2500 Flawless Diamonds | $150,000 |
| 462 | **Paul Bunyan** | Sell 1,000 Timber | $150,000 |
| 463 | **Radioactive Man** | Sell 8,000 processed uranium | $250,000 |
| 464 | **Los Pollos Hermanos** | Sell 7,500 Blue Meth | $345,000 |
| 466 | **Pablo Escobar** | Sell 6,500 Coke Bricks | $345,000 |
| 467 | **Snoop Doggy OG** | Sell 5,000 Golden Wax | $105,000 |
| 468 | **Transfusion Delusion** | Use a Blood Bag 300 times on yourself. | 15% faster blood bag usage and perform transfusions on self while prone. |
| 469 | **Transfusion Delusion Pt 2** | Use a Blood Bag 300 times on others. | Perform transfusion while prone on others. |
| 470 | **The Dropper** | Drop 300 Bounties | 15,000 Honor + Drop a players bounty every 4 minutes. |
| 471 | **The Punisher** | Earn 100,000 Honor | 5,000 Honor + Ability to lethal with P07 pistols. |
| 472 | **Vigilante Flash** ⚔ | Arrest bounty 100 targets | 5,000 Honor + Send your bounty to jail 10% faster. |
| 473 | **Crusader** ⚔ | Arrest bounty 50 targets | 10,000 Honor |
| 474 | **Master Blacksmith** | 10,000 Honor + Spend $1,000,000 at Skiptracer weapon shop. | 2 Green MXM's + 10x 30rnd Magazines |
| 475 | **No Kneepads** ⚔ | Kill 150 police members that are SGT+. | $185,000 + 8 New Drachma + 1 Speedbomb + 3 Admin Gifts + 2 MK200s with 5 Magazines |
| 476 | **MaxSec Mald Generator** ⚔ | Kill 25 police Captains. | $40,000 + 2 LIM's with 5 Magazines + Diabolical Achievement unlocked |
| 477 | **Pig Sniper** ⚔ | Headshot 150 police officers. | $150,000 + 3 MK-1 rifles |
| 478 | **Anti-MaxTac** ⚔ | Kill 100 active MaxTac members. | $150,000 + 1 Zafir with 3 magazines |
| 479 | **Deerstand Defender** ⚔ | Kill 200 MaxSec Officers while in a Federal Reserve deerstand. | 10 MK-1's + Deerstand Defender title unlocked |
| 480 | **Making Bank** ⚔ | Kill 200 Officers at an active Bank. | $100,000 + 8 New Drachma + 2 RPK with 5 Magazines + Menace Achievement unlocked |
| 481 | **RIP** ⚔ | Kill 50 officers inside Ifrit/Strider/Hunter | $50,000 + 8 New Drachma + 2 RPG Shells |
| 482 | **MaxSec's Most Hated** ⚔ | Kill 1,000 MaxSec Officers. | $230,000 + 1 Phone Bomb + 1 Suicide Vest + Obliterator Achievement |
| 483 | **Ghillie in the mist** ⚔ | Kill 200 people while wearing a Ghillie Suit | $115,000 + 5 Ghillie Suits + 10 AK-12's + Ghillie In Mist Title |
| 484 | **Gang Hitman** ⚔ | Kill 150 Rival Gang members | 18 New Drachma |
| 485 | **Nope!** ⚔ | Kill 100 Bounty Hunters who have your bounty active | 10 New Drachma |
| 486 | **Rambo** ⚔ | Kill 300 players with an armed vehicle | $105,000 + 18 New Drachma + 10 Vehicle Reloads + 50% off garage fee's at Rebel Outposts |
| 487 | **Ripper** ⚔ | Kill 50 civilians seated in Ifrits | 16.5 New Drachma + 2 Speed Bombs |
| 488 | **Bounty HuntDEAD** ⚔ | Kill 250 Bounty Hunters | $120,000 |
| 489 | **Career Racer** | Complete Any Time Trial 125 times | $45,000 |
| 490 | **Black Market (Air)** | Craft 100 Aircraft (Excluding M900 and MH-9 Hummingbird) | All crafted aircraft cash requirements are reduced by 10%. |
| 491 | **Black Market (Armor)** | Craft 150 Armored Vehicles at the Black Market (Ifirt/Hunter) | All crafted armor material requirements are reduced by 10%. |
| 492 | **Black Market (7.62)** | Craft 200 7.62mm rifles at the Black Market. | 5x MK-1 + All crafted firearms require 10% less materials to craft |
| 493 | **Turf Terrorist** | Capture the turf flag for your gang 100 times | $100,000 + Turf Terrorist Title |
| 494 | **Premium Plates** | Press 1000 Plates | $35,000 + Plates Reduce Prison Time 20% More |
| 495 | **Free Shamu** | Chop 25 Orca's | Shamu Title + 10,000 cash |
| 496 | **Tax Man** | Pay $500,000 In Property Tax | Tax Man Title + 2 RPGs |

## MaxSec — LIFETIME  ·  12 quests  ·  questType 2 (lifetime)

| id | quest | requirement | award |
|---|---|---|---|
| 651 | **Sherlock Holmes** ⚔ | Arrest the APB | $70,000 |
| 652 | **The Snitch** ⚔ | Seize $2,500,000 worth of illegal items from vehicles | $125,000 |
| 653 | **Robo Cop** | Give $5,000,000 worth of tickets | $225,000 |
| 654 | **Homer Simpson** | Eat 300 Donuts | $20,000 |
| 655 | **HVT'd** ⚔ | Arrest 25 players whom had a bounty above $150,000 | $150,000 |
| 656 | **Personal Vehicle** | Buy $1,000,000 worth of hatchback sports | $100,000 |
| 657 | **Top Gun** | Buy $2,500,000 worth of aircraft | $250,000 |
| 658 | **Up-Armored** | Buy $5,000,000 worth of armor | $335,000 |
| 659 | **Alcatraz Guard** | Stop prison 3 times via laptop | $50,000 |
| 660 | **Blood Drive** | Use 250 Bloodbags on others | $45,000 |
| 661 | **Blood bank** | Use 500 Bloodbags on others | $60,000 + perform transfusions on others while prone. |
| 662 | **MaxTac Officer** | Report for MaxTac duty 150 Times | $75,000 + 2 Flashbangs |

## TT — LIFETIME  ·  10 quests  ·  questType 2 (lifetime)

| id | quest | requirement | award |
|---|---|---|---|
| 801 | **No Life** ⚔ | Revive 500 players | $260,000 |
| 802 | **Blood Drive** | Use 250 Bloodbags on others | $45,000 + 10% faster blood bag usage and perform transfusions on self while prone. |
| 803 | **Blood bank** | Use 500 Bloodbags on others | $60,000 + perform transfusions on others while prone. |
| 804 | **Frequent Flyer** | Use 271 Adrenaline Shots | $100,000 + 50% chance of Adrenaline Shots not being consumed upon use. |
| 805 | **Cleanup Crew** | Remove wreck 50 times | $30,000 + $500 per wreck removed. |
| 806 | **Combat Medic** | Pull out 250 Aircraft | $25,000 + 50% off garage fee to pull aircraft. |
| 807 | **Bob The Builder** | Repair 100 Houses | $150,000 |
| 808 | **Driver** | Buy 1,000,000 Worth of vehicles | $50,000 + 2% off all land vehicle purchases. |
| 809 | **Persistent Pilot** | Buy 2,000,000 Worth of aircraft | $100,000 + 2% off all air vehicle purchases. |
| 810 | **FDNY** | Report for firefighting duty 500 Times | $250,000 |

## Hidden  ·  2 quests  ·  questType 2 (lifetime)

| id | quest | requirement | award |
|---|---|---|---|
| 1000 | **DevOPS** ⚔ | Kill a Developer 5 Times | 'Develop some skill' title |
| 1001 | **BADMin** ⚔ | Kill an Admin 25 Times | 1 Admin Gift |

---

**134 quests total.** 89 have no wording requiring another player; 45 do.
