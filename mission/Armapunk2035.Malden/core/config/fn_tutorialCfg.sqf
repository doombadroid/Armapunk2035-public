private _carShopWP = ["car1_1_2", "car1_2_1_1", "car1_1", "car1_2", "car1_2_1_1_1"];
private _generalStoreWP = ["Gearshop", "Gen_2", "Gen_2_1", "Gen_4", "Gen_4_1"];
private _gunStoreWP = ["gs1", "gun_store_1_1", "gun_store_1_1_2", "gun_store_1_1_2_1", "gun_store_1_1_3"];
private _jewelryStoreWP = ["oil_trader_2_1", "oil_trader_2_1_1", "oil_trader_2_2", "oil_trader_2_2_2"];
private _marketStoreWP = ["Gen_3_1", "Gen_3_1_1_2", "Gen_3_1_1_2_1", "Gen_3_1_1_3", "Gen_3_1_1_1"];
private _commoditiesStoreWP = ["commod_1", "commod_1_1", "commod_1_1_1"];
private _drugDealerWP = ["Dealer_1", "Dealer_1_1", "Dealer_1_3", "Dealer_1_4"];
private _wongsDealerWP = ["wong_1", "wong_1_1", "wong_2"];
private _atmWP = ["atm", "Atm1_1_1", "Atm1_1_1_2", "atm_1_3_11_1", "atm_1_3_11_3", "atm_1_3_11_5_1", "atm_1_3_11_5_1_1", "atm_1_3_11_5_1_1_1", "atm_1_3_11_5_2", "atm_1_3_11_5_3", "atm_1_3_11_6", "atm_1_1_1_1"];
private _mineralProcessorWP = ["quarryproc", "quarryproc_1", "quarryproc_2", "quarryproc_3"];
private _minesWP = ["mine_2", "mine_3", "mine_4", "mine_5"];
private _highYieldMinesWP = ["mine_1", "mine_6"];
private _peachfieldsWP = ["peaches_3", "peaches_4", "peaches_2"];
private _drugRunner = ["drugrunner_marker_1", "drugrunner_marker_2", "drugrunner_marker_3", "drugrunner_marker_4", "drugrunner_marker_5"];
private _dpMission = ["dp_1_1", "dp_1_2", "dp_1_3", "dp_1_4", "dp_1_5", "dp_1_6", "dp_1_7", "dp_1_8", "dp_1_9", "dp_1_10", "dp_1_11", "dp_1_12", "dp_1_13", "dp_1_14", "dp_1_15", "dp_1_16", "dp_1_17", "dp_1_18", "dp_1_19", "dp_1_20", "dp_1_21", "dp_1_22", "dp_1_23", "dp_1_24", "dp_1_25", "dp_mission"];
params[["_mode", "", [""]], ["_tutorialToFind", -1, [0]]];
if (_mode isEqualTo "") exitWith {};
private _buyCarAdditional = [[0, _carShopWP, 3, "We have marked the DMV for you, here you can buy cars. <br/><br/>Walk over to the NPC"],
    [1, _carShopWP, 3, "Every vehicle has its own special abilities. <br/><br/>Think about protection, speed, amount of trunk space <br/><br/>You can lookup everything in the store. For making money its advised to have a car with a lot of trunk space."],
    [2, [], 5, "Hop in your vehicle now, (unlock it by pressing U)"]];
private _miningAdditional = [
    [0, _marketStoreWP, 4, "For mining we are going to need a pickaxe, walk over to the market and get yourself a pickaxe."],
    [1, _generalStoreWP, 4, "After you bought a pickaxe it might be wise to increase your virtual inventory, you can do so by buying a backpack over at the general store. Preferably a big one like a carryall"],
    [2, _carShopWP, 3, "We have marked the DMV for you, here you can buy cars. <br/><br/> Cars are valuable on runs as we can store virtual items in their trunks"],
    [3, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [4, _minesWP, 100, "All set now, lets head over to the mines."],
    [5, _minesWP, 100, "You've made it! Now you can start mining by using your scrollwheel and pressing mine."],
    [6, _minesWP, 100, "You will start gathering materials you can store those in your car by using the trunk (remember press T when in / looking at your car)."],
    [7, _jewelryStoreWP, 5, "Once you are all full (car and inventory) you can head on over to the next marker. Over there you can sell your beloved jewels."],
    [8, _commoditiesStoreWP, 5, "You've made it in one piece congratulations, over here you can sell your jewels. I'll mark the commodities store so you can sell the rest of the items you have"],
    [9, _atmWP, 5, "Once you have sold everything you need to store all your cash in your bank acount, here's a marker to a ATM nearby."]];
private _highYieldMiningAdditional = [
    [0, _gunStoreWP, 5, "We expect you've done the basic mining tutorial and understand a thing or two, with the starter cash you made you should buy a pistol, something to protect yourself with from robbers. I've marked the store for you"],
    [1, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [2, _highYieldMinesWP, 100, "All set now, lets head over to the mines."],
    [3, _highYieldMinesWP, 100, "You've made it! Now you can start mining by using your scrollwheel and pressing mine."],
    [4, _highYieldMinesWP, 100, "You will start gathering materials you can store those in your car by using the trunk (remember press T when in / looking at your car)."],
    [5, _jewelryStoreWP, 5, "Once you are all full (car and inventory) you can head on over to the next marker. Over there you can sell your beloved jewels."],
    [6, _commoditiesStoreWP, 5, "You've made it in one piece congratulations, over here you can sell your jewels. I'll mark the commodities store so you can sell the rest of the items you have"],
    [7, _atmWP, 5, "Once you have sold everything you need to store all your cash in your bank acount, here's a marker to a ATM nearby."]];
private _peachesAdditional = [
    [1, _carShopWP, 3, "We have marked the DMV for you, here you can buy cars. <br/><br/> Cars are valuable on runs as we can store virtual items in their trunks"],
    [2, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [3, _peachfieldsWP, 50, "I've marked the peach field for you move over so you can gather some of those sweet peaches"],
    [4, _marketStoreWP, 5, "You've reached the peach fields congratulations! Go gather some peaches by using the scroll action <\br><\br>Once you are done go ahead and move over to the market store"],
    [5, _atmWP, 5, "Once you have sold everything you need to store all your cash in your bank acount, here's a marker to a ATM nearby."]];
private _dpAdditional = [
    [1, _carShopWP, 3, "We have marked the DMV for you, here you can buy cars. <br/><br/> Cars are valuable on runs as we can store virtual items in their trunks"],
    [2, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [3, _dpMission, 5, "I've marked a DP mission guy over there you can start a delivery mission for some small cash"]];
private _cocaineAdditional = [
    [0, _gunStoreWP, 5, "We expect you've done the basic mining tutorial and understand a thing or two, with the starter cash you made you should buy a pistol, something to protect yourself with from robbers. I've marked the store for you"],
    [1, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [2, ["illegal_marker_2_0"], 150, "All set lets head over to the smash field to gather some smash!"],
    [3, ["illegal_marker_2_0"], 150, "Welcome to the smash field over here you can gather smash for use or for sales (i'd sell it) gather some but watch out of the cops and robbers!"],
    [4, ["illegal_marker_2_1"], 150, "Once you are done head on over to the next marker to process your smash."],
    [5, ["illegal_marker_2_1"], 150, "Welcome to the smash processor over here you can process your precious smash into the pure form for sales."],
    [6, _drugDealerWP, 15, "Once you are all set head on over to the drug dealer to sell."],
    [7, _atmWP, 5, "Once you have sold everything you need to store all your cash in your bank acount, here's a marker to a ATM nearby."]];
private _drugRunnerAdditional = [
    [0, _gunStoreWP, 5, "We expect you've done the basic mining tutorial and understand a thing or two, with the starter cash you made you should buy a pistol, something to protect yourself with from robbers. I've marked the store for you"],
    [1, [], 5, "Hop in your vehicle now, (unlock it by pressing U). <br/><br/> Did you know you can open the trunk by pressing T"],
    [2, _drugRunner, 5, "Drive over to the drug runner location"]];
private _tutorialsLegal = [
    [0, true, "Buy a car", "I think you are ready now for a basic money making method (you should try the 'Normal mining' tutorial)", _buyCarAdditional],
    [1, true, "Basics to mining", "Once you are ready you should try doing the high yield mining tutorial for some extra cash I heard those mines have better stuff", _miningAdditional],
    [2, true, "- High yield mining", "", _highYieldMiningAdditional], [3, true, "Peaches", "", _peachesAdditional],
    [4, true, "Delivery missions", "Talk to the guy now and he will take you on further endeavours", _dpAdditional]];
private _tutorialsIllegal = [[200, false, "Smash", "", _cocaineAdditional],
    // 2026-07-26: the Heroin track (201) died with the opium field. 202 had been borrowing its steps;
    // it now runs the drug-runner steps it always claimed to.
    [202, false, "Drug runner", "Congrats you can now start a drug runner mission which will take you on further endeavours", _drugRunnerAdditional]
];
private _tutorials = [];
_tutorials append _tutorialsLegal;
_tutorials append _tutorialsIllegal;
private "_returnValue";
switch (_mode) do {case "getTutorialArray": {_returnValue = _tutorials;}; case "getTutorialByID": {if (_tutorialToFind == -1) exitWith {};
                _returnValue = _tutorials param[_tutorials findIf {_tutorialToFind isEqualTo(_x select 0)}, []];};}; _returnValue ;