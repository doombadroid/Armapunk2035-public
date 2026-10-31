/*
    AP_fnc_itemDemand  (LooneyBin Economy — dynamic market depth, owner request 2026-06-11)
    Per-good "market DEPTH" = how much accumulated net trade pressure (units) it takes to move the
    price the full way to its cap. Used BOTH sides:
      - server APS_fnc_marketTick   : random-walk step (depth*0.08) + event target (+/- depth) + d clamp
      - client AP_fnc_marketFactor: price multiplier = f(d / depth)

    ANTI-ARBITRAGE (2026-06-12): depths are deliberately LARGE relative to the 100-unit per-transaction
    cap so a single trade can only nudge the factor a few percent — far less than any good's buy/sell
    spread. This makes a buy-then-sell (or sell-then-buyback) round-trip always lose the spread, closing
    the money-pump that small depths allowed, while AGGREGATE volume + drift + events still move prices.
    A round-trip can only profit if sell_price > buy_price*(1 - 100/depth*AP_marketSwing); at depth 800
    that needs sell > ~92% of buy (essentially never). Low depth = thinner/more reactive; high = deeper.
    Unlisted items default to 1000.
*/
params [["_class", "", [""]]];
if (_class isEqualTo "") exitWith {1000};
private _c = toLower _class;
private _tbl = [
    // luxury / high-value — thinnest markets (most reactive), but still arbitrage-safe
    ["smash",800],["smashbrick",800],["cocainepure",800], ["diamond",800],["diamondc",800],["diamondf",800],["diamondr",800],
    ["goldbar",800],["goldnugget",800],["ruby",800],["uraniump",700],["turtle",800],
    // mid-tier drugs / spirits
    ["blacklace",1000],["blacklaceprime",1000],["marijuana",1000],["marijuanam",1000],["toxicslurry",1000],
        ["redshift",1000],["glitter",1000],["lacebase",1000],
    ["scotch_2",900],["scotch_3",900],["rum_3",900],["moonshine",900],["moonshinep",900],["gingerale_0",900],
    // livestock / misc
    ["dog",1000],["dogp",1000],["goatp",1000],["sheep",1200],["sheepp",1200],["manfleshp",900],["humanscalp",800],
    // bulk commodities — deepest markets, barely move per trade
    ["salt_r",1800],["iron_r",1800],["copper_r",1800],["timber",1800],["timberh",1800],["timberl",1800],
    ["plank",1800],["oilp",1500],["rubber",1500]];
private _i = _tbl findIf {(_x select 0) isEqualTo _c};
if (_i isEqualTo -1) exitWith {1000};
(_tbl select _i) select 1
