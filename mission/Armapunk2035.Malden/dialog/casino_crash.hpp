/*
    casino_crash.hpp  (LooneyBin -- Casino). idd 930360.
    CRASH / "aviator": DEAL a bet, the multiplier climbs, CASH OUT before it pops. Server owns the bust point.
    Shares the casino idc scheme: 1010 bank, 1011 bet, 1012 banner, 1006 big multiplier, 1252 cash-out value,
    1200-1204 chips, 1210 DEAL, 1230 PLAY AGAIN, 1231 CASH OUT, 1240 LOBBY.
*/
class AP_casino_crash {idd = 930360;
    name = "AP_casino_crash";
    movingEnable = false;
    enableSimulation = true;
    onUnload = "if ((missionNamespace getVariable ['AP_crashRound', [false]]) param [0, false]) then { [['crash','quit',[]],'APS_fnc_casinoSRV',2] spawn AP_fnc_MP; }; AP_crashRound = [false, 0, 0];";
    class controlsBackground {
        class Dim: AP_RscText { idc=-1; x=safezoneX; y=safezoneY; w=safezoneW; h=safezoneH; colorBackground[]={0,0,0,0.55}; };
        class CasFelt: AP_RscPicture { idc=-1; x=-18.6734*UI_GRID_W + UI_GRID_X; y=-6.3465*UI_GRID_H + UI_GRID_Y; w=35.2047*UI_GRID_W; h=14.7931*UI_GRID_H; colorText[]={1,1,1,1}; text="images\casino\casino_felt.paa"; };
        class CasFrame: AP_RscPicture { idc=-1; x=-20*UI_GRID_W + UI_GRID_X; y=-10*UI_GRID_H + UI_GRID_Y; w=40*UI_GRID_W; h=20*UI_GRID_H; colorText[]={1,1,1,1}; text="images\phone_deck_blank.paa"; };
    };
    class controls {
        class Back: AP_CasinoBtn { idc=1240; x=-16.9346*UI_GRID_W + UI_GRID_X; y=-5.91*UI_GRID_H + UI_GRID_Y; w=5.4135*UI_GRID_W; h=0.8*UI_GRID_H; sizeEx=0.4681*UI_GRID_H; text="< LOBBY"; colorText[]={1,1,1,1}; colorBackground[]={0.2,0.2,0.24,1}; colorBackgroundActive[]={0.3,0.3,0.36,1}; colorFocused[]={0.3,0.3,0.36,1}; };
        class Brand: AP_RscStructuredText { idc=-1; x=-8.273*UI_GRID_W + UI_GRID_X; y=-6.342*UI_GRID_H + UI_GRID_Y; w=14.436*UI_GRID_W; h=1.04*UI_GRID_H; class Attributes { align="center"; }; size=0.6596*UI_GRID_H; text="<t size='1.3' shadow='1' font='PuristaBold' color='#e7c757'>CRASH</t>"; };
        class BankReadout: AP_RscStructuredText { idc=1010; x=-17.476*UI_GRID_W + UI_GRID_X; y=-4.998*UI_GRID_H + UI_GRID_Y; w=10.1052*UI_GRID_W; h=0.72*UI_GRID_H; class Attributes { align="left"; }; size=0.6596*UI_GRID_H; text=""; };
        class BetReadout: AP_RscStructuredText { idc=1011; x=5.2608*UI_GRID_W + UI_GRID_X; y=-4.998*UI_GRID_H + UI_GRID_Y; w=10.1052*UI_GRID_W; h=0.72*UI_GRID_H; class Attributes { align="right"; }; size=0.6596*UI_GRID_H; text=""; };
        class MultBig: AP_RscStructuredText { idc=1006; x=-15.491*UI_GRID_W + UI_GRID_X; y=-3.43*UI_GRID_H + UI_GRID_Y; w=28.872*UI_GRID_W; h=3.2*UI_GRID_H; class Attributes { align="center"; }; size=1.2766*UI_GRID_H; text=""; };
        class CashValue: AP_RscStructuredText { idc=1252; x=-13.6865*UI_GRID_W + UI_GRID_X; y=0.73*UI_GRID_H + UI_GRID_Y; w=25.263*UI_GRID_W; h=0.96*UI_GRID_H; class Attributes { align="center"; }; size=0.5957*UI_GRID_H; text=""; onLoad="(_this select 0) ctrlShow false"; };
        class ResultBanner: AP_RscStructuredText { idc=1012; x=-11.882*UI_GRID_W + UI_GRID_X; y=2.01*UI_GRID_H + UI_GRID_Y; w=21.654*UI_GRID_W; h=1.44*UI_GRID_H; class Attributes { align="center"; }; size=0.6596*UI_GRID_H; text=""; colorBackground[]={0,0,0,0.6}; onLoad="(_this select 0) ctrlShow false"; };
        class CashOut: AP_CasinoBtn { idc=1231; x=-11.1602*UI_GRID_W + UI_GRID_X; y=4.01*UI_GRID_H + UI_GRID_Y; w=20.2104*UI_GRID_W; h=0.96*UI_GRID_H; sizeEx=0.6809*UI_GRID_H; text="CASH OUT"; colorText[]={1,1,1,1}; colorBackground[]={0.72,0.55,0.15,1}; colorBackgroundActive[]={0.8,0.65,0.25,1}; colorFocused[]={0.8,0.65,0.25,1}; onLoad="(_this select 0) ctrlShow false"; };
        class Chip0: AP_CasinoBtn { idc=1200; x=-17.769*UI_GRID_W + UI_GRID_X; y=5.3537*UI_GRID_H + UI_GRID_Y; w=6.053*UI_GRID_W; h=1.0942*UI_GRID_H; sizeEx=0.5957*UI_GRID_H; text="$10K"; colorText[]={1,1,1,1}; colorBackground[]={0.15,0.22,0.35,1}; colorBackgroundActive[]={0.24,0.34,0.52,1}; colorFocused[]={0.24,0.34,0.52,1}; };
        class Chip1: AP_CasinoBtn { idc=1201; x=-10.9509*UI_GRID_W + UI_GRID_X; y=5.3537*UI_GRID_H + UI_GRID_Y; w=6.053*UI_GRID_W; h=1.0942*UI_GRID_H; sizeEx=0.5957*UI_GRID_H; text="$50K"; colorText[]={1,1,1,1}; colorBackground[]={0.15,0.22,0.35,1}; colorBackgroundActive[]={0.24,0.34,0.52,1}; colorFocused[]={0.24,0.34,0.52,1}; };
        class Chip2: AP_CasinoBtn { idc=1202; x=-4.1324*UI_GRID_W + UI_GRID_X; y=5.3537*UI_GRID_H + UI_GRID_Y; w=6.053*UI_GRID_W; h=1.0942*UI_GRID_H; sizeEx=0.5957*UI_GRID_H; text="$100K"; colorText[]={1,1,1,1}; colorBackground[]={0.15,0.22,0.35,1}; colorBackgroundActive[]={0.24,0.34,0.52,1}; colorFocused[]={0.24,0.34,0.52,1}; };
        class Chip3: AP_CasinoBtn { idc=1203; x=2.6857*UI_GRID_W + UI_GRID_X; y=5.3537*UI_GRID_H + UI_GRID_Y; w=6.053*UI_GRID_W; h=1.0942*UI_GRID_H; sizeEx=0.5957*UI_GRID_H; text="$250K"; colorText[]={1,1,1,1}; colorBackground[]={0.15,0.22,0.35,1}; colorBackgroundActive[]={0.24,0.34,0.52,1}; colorFocused[]={0.24,0.34,0.52,1}; };
        class Chip4: AP_CasinoBtn { idc=1204; x=9.5042*UI_GRID_W + UI_GRID_X; y=5.3537*UI_GRID_H + UI_GRID_Y; w=6.053*UI_GRID_W; h=1.0942*UI_GRID_H; sizeEx=0.5957*UI_GRID_H; text="$500K"; colorText[]={1,1,1,1}; colorBackground[]={0.15,0.22,0.35,1}; colorBackgroundActive[]={0.24,0.34,0.52,1}; colorFocused[]={0.24,0.34,0.52,1}; };
        class Deal: AP_CasinoBtn { idc=1210; x=-17.769*UI_GRID_W + UI_GRID_X; y=6.6666*UI_GRID_H + UI_GRID_Y; w=33.3955*UI_GRID_W; h=1.0504*UI_GRID_H; sizeEx=0.6383*UI_GRID_H; text="DEAL"; colorText[]={1,1,1,1}; colorBackground[]={0.192,0.639,0.322,1}; colorBackgroundActive[]={0.24,0.76,0.4,1}; colorFocused[]={0.24,0.76,0.4,1}; };
        class PlayAgain: AP_CasinoBtn { idc=1230; x=-11.5074*UI_GRID_W + UI_GRID_X; y=6.6666*UI_GRID_H + UI_GRID_Y; w=20.8723*UI_GRID_W; h=1.0504*UI_GRID_H; sizeEx=0.6383*UI_GRID_H; text="PLAY AGAIN"; colorText[]={1,1,1,1}; colorBackground[]={0.192,0.639,0.322,1}; colorBackgroundActive[]={0.24,0.76,0.4,1}; colorFocused[]={0.24,0.76,0.4,1}; onLoad="(_this select 0) ctrlShow false"; };
    };};
