#include "..\..\macro.h"
if (scriptAvailable(10)) exitWith {};
params[["_type", 0, [0]]];
waitUntil {uiSleep 2;
    (alive player && !(AP_maxWeight isEqualTo AP_carryWeight))};
private _giftName =
switch (_type) do {case 0: {"an Admin gift"};
    case 1: {"a Halloween gift"};
    case 2: {"a Christmas gift"};
    default {"a gift"};}; private _item =
switch (_type) do {case 0: {"giftAdmin"};
    case 1: {"giftHallo"};
    case 2: {"giftXmas"};
    default {"giftAdmin"};};
[ true , _item, 1] call AP_fnc_handleInv;
[format["<t color='#8034EB' align='center'><t size='1'>Gift Received</t></t><br/>You have been given %1! Open your inventory and use the item to see what is inside! Warning, some gifts may be illegal! Thanks for playing at LoonyBin!", _giftName], "basic"] spawn AP_fnc_handleMessage;