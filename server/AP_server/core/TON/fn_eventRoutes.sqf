/*
    APS_fnc_eventRoutes  (LooneyBin, owner 2026-07-17) -- shared route geometry for the HC-driven world events.
    Returns [supplyRouteA_west, supplyRouteB_east, smugglerLoop] as arrays of Altis world [x,y] waypoints.

    These polylines were traced directly off the owner's hand-drawn map routes (black lines on the full-island
    map for the two Supply Bomber flight paths; the closed loop on the central-bay map for the Smuggler Speedboat)
    and calibrated to world coordinates (planes map 20.576 m/px, boat map 13.605 m/px, both anchored on known
    landmarks -- Hunting Grounds / Bank of Altis -- and cross-checked against Molos/Sofia/Kavala).

    Tweak a waypoint here and every consumer (supply bomber, scheduler, boat) picks it up. Z is left 0 (ground/sea).
    Usage: (call APS_fnc_eventRoutes) params ["_routeA","_routeB","_boatLoop"];
*/
private _routeA = [   // Supply Bomber -- WEST route (Peach Field area -> SW toward Kavala outskirts)
    [14670,20472],[12819,19978],[11582,17525],[10305,16199], [10370,15297],[10041,14463],[7772,12967],[7029,11659]];
private _routeB = [   // Supply Bomber -- EAST route (Oil Barrel Processing -> SE toward DP24)
    [22318,19114],[20679,18507],[20968,18399],[20391,18177],[20061,17488],[20061,15935],
    [20471,14887],[20082,13311],[19238,12540],[19022,10256],[19609,7982]];
private _boatLoop = [ // Smuggler Speedboat -- closed loop through the central-south bay (drive it, then repeat)
    [15060,15607],[16462,15198],[16883,14505],[16707,14069],[16054,13620],[16067,12233],[14611,11811],
    [14271,11226],[14299,10382],[17047,8532],[17455,7961],[17523,6818],[16503,6328],[14924,6763],
    [14312,7212],[13496,8314],[13360,10151],[12475,11321],[12720,12083],[13455,12600],[13020,12654],
    [13020,13158],[13496,13158],[13673,12872],[14952,13117],[14543,13743],[13305,14260],[15060,15607]];
[_routeA, _routeB, _boatLoop]
