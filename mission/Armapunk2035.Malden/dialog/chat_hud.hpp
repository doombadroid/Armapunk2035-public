// LooneyBin (owner, 2026-06-11): persistent chat history HUD. Vanilla chat fades after a few seconds;
// this keeps the last ~12 messages on screen (bottom-left) so you can read recent side/global/direct
// chat. Fed by fn_handleChatMessage (the HandleChatMessage EH), rendered into the structured text ctrl.
class AP_chat_hud {idd = 246000;
    duration = 1e+011;
    fadein = 0;
    fadeout = 0;
    name = "AP_chat_hud";
    onLoad = "uiNamespace setVariable ['AP_chat_hud', _this select 0]";
    onUnload = "uiNamespace setVariable ['AP_chat_hud', nil]";
    class controls {class ChatHistory: AP_RscStructuredText {idc = 246001;
            x = 0.012 * safezoneW + safezoneX;
            y = 0.620 * safezoneH + safezoneY;
            w = 0.340 * safezoneW;
            h = 0.250 * safezoneH;
            text = "";
            class Attributes {font = "PuristaMedium";
                color = "#ffffff";
                align = "left";
                shadow = 1;};
            size = "0.034 * safezoneH";
            shadow = 2;};};};

// LooneyBin (owner, 2026-06-11): prison-break countdown HUD. An active break runs for 10 minutes before
// prisoners can escape, with no on-screen timer. This top-center bar (fed by the SRV_prisonData watcher in
// initPlayerLocal) shows the remaining time + a block-bar so everyone can see the break's progress.
class AP_prison_hud {idd = 247000;
    duration = 1e+011;
    fadein = 0;
    fadeout = 0;
    name = "AP_prison_hud";
    onLoad = "uiNamespace setVariable ['AP_prison_hud', _this select 0]";
    onUnload = "uiNamespace setVariable ['AP_prison_hud', nil]";
    class controls {class PrisonTimer: AP_RscStructuredText {idc = 247001;
            x = 0.300 * safezoneW + safezoneX;
            y = 0.140 * safezoneH + safezoneY;
            w = 0.400 * safezoneW;
            h = 0.075 * safezoneH;
            text = "";
            class Attributes {font = "PuristaMedium";
                color = "#ffffff";
                align = "center";
                shadow = 1;};
            size = "0.040 * safezoneH";
            shadow = 2;};
        class PrisonBar: AP_RscProgress {idc = 247002;
            x = 0.330 * safezoneW + safezoneX;
            y = 0.218 * safezoneH + safezoneY;
            w = 0.340 * safezoneW;
            h = 0.018 * safezoneH;
            colorBar[] = {0.92, 0.30, 0.20, 1};};};};

// LooneyBin 2026-06-11: bank vault drill progress bar (the 10-min server drill had no on-screen feedback).
// Driven by the initPlayerLocal watcher off AP_bank_drilling + AP_bank_robbed[1]; shown to anyone near
// the bank so robbers see their progress and cops see how long until the vault opens / time left to disarm.
class AP_bank_hud {idd = 247003;
    duration = 1e+011;
    fadein = 0;
    fadeout = 0;
    name = "AP_bank_hud";
    onLoad = "uiNamespace setVariable ['AP_bank_hud', _this select 0]";
    onUnload = "uiNamespace setVariable ['AP_bank_hud', nil]";
    class controls {class BankTimer: AP_RscStructuredText {idc = 247011;
            x = 0.300 * safezoneW + safezoneX;
            y = 0.140 * safezoneH + safezoneY;
            w = 0.400 * safezoneW;
            h = 0.075 * safezoneH;
            text = "";
            class Attributes {font = "PuristaMedium";
                color = "#ffffff";
                align = "center";
                shadow = 1;};
            size = "0.040 * safezoneH";
            shadow = 2;};
        class BankBar: AP_RscProgress {idc = 247012;
            x = 0.330 * safezoneW + safezoneX;
            y = 0.218 * safezoneH + safezoneY;
            w = 0.340 * safezoneW;
            h = 0.018 * safezoneH;
            colorBar[] = {0.945, 0.239, 0.659, 0.9};   // NIGHT CITY magenta -- matches AP_RscProgress (the bar every other event/drill/gather uses)
        };};};

// LooneyBin (owner, 2026-06-11): RESTORE the player nametag HUD. The RscTitles class was lost in deobf,
// so fn_playerTags `500 cutRsc ["AP_hud_nametags",...]` errored "not found" and no names showed over
// heads. 64 structured-text controls (idc 78000+i); fn_playerTags positions + sets each per frame via
// worldToScreen. Overflow past 64 simultaneous tags is skipped gracefully (ops on a null ctrl no-op).
class AP_hud_nametags {idd = 78100;
    duration = 1e+011;
    fadein = 0;
    fadeout = 0;
    name = "AP_hud_nametags";
    onLoad = "uiNamespace setVariable ['AP_hud_nametags', _this select 0]";
    class controls {class AP_NameTagBase: AP_RscStructuredText {idc = -1;
            x = 0; y = 0; w = 0.30; h = 0.10;   // owner 2026-06-19 (#400): h 0.05 -> 0.10. The tag stacks up to 3 structured-text lines (name + gang/group + title); 0.05 only fit ~2 so a title clipped the name ("title cuts the name in half"). Box grows downward from the head, so single-line tags are unaffected.
            size = "0.0176 * safezoneH";   // owner 2026-06-13: ~30% smaller nametags (was 0.028; effective 0.028*0.9 scale -> now 0.0176 @ scale 1)
            shadow = 2;
            class Attributes { align = "center"; color = "#FFFFFF"; font = "PuristaMedium"; shadow = 1; };};
        class AP_NameTag0: AP_NameTagBase { idc = 78000; };
        class AP_NameTag1: AP_NameTagBase { idc = 78001; };
        class AP_NameTag2: AP_NameTagBase { idc = 78002; };
        class AP_NameTag3: AP_NameTagBase { idc = 78003; };
        class AP_NameTag4: AP_NameTagBase { idc = 78004; };
        class AP_NameTag5: AP_NameTagBase { idc = 78005; };
        class AP_NameTag6: AP_NameTagBase { idc = 78006; };
        class AP_NameTag7: AP_NameTagBase { idc = 78007; };
        class AP_NameTag8: AP_NameTagBase { idc = 78008; };
        class AP_NameTag9: AP_NameTagBase { idc = 78009; };
        class AP_NameTag10: AP_NameTagBase { idc = 78010; };
        class AP_NameTag11: AP_NameTagBase { idc = 78011; };
        class AP_NameTag12: AP_NameTagBase { idc = 78012; };
        class AP_NameTag13: AP_NameTagBase { idc = 78013; };
        class AP_NameTag14: AP_NameTagBase { idc = 78014; };
        class AP_NameTag15: AP_NameTagBase { idc = 78015; };
        class AP_NameTag16: AP_NameTagBase { idc = 78016; };
        class AP_NameTag17: AP_NameTagBase { idc = 78017; };
        class AP_NameTag18: AP_NameTagBase { idc = 78018; };
        class AP_NameTag19: AP_NameTagBase { idc = 78019; };
        class AP_NameTag20: AP_NameTagBase { idc = 78020; };
        class AP_NameTag21: AP_NameTagBase { idc = 78021; };
        class AP_NameTag22: AP_NameTagBase { idc = 78022; };
        class AP_NameTag23: AP_NameTagBase { idc = 78023; };
        class AP_NameTag24: AP_NameTagBase { idc = 78024; };
        class AP_NameTag25: AP_NameTagBase { idc = 78025; };
        class AP_NameTag26: AP_NameTagBase { idc = 78026; };
        class AP_NameTag27: AP_NameTagBase { idc = 78027; };
        class AP_NameTag28: AP_NameTagBase { idc = 78028; };
        class AP_NameTag29: AP_NameTagBase { idc = 78029; };
        class AP_NameTag30: AP_NameTagBase { idc = 78030; };
        class AP_NameTag31: AP_NameTagBase { idc = 78031; };
        class AP_NameTag32: AP_NameTagBase { idc = 78032; };
        class AP_NameTag33: AP_NameTagBase { idc = 78033; };
        class AP_NameTag34: AP_NameTagBase { idc = 78034; };
        class AP_NameTag35: AP_NameTagBase { idc = 78035; };
        class AP_NameTag36: AP_NameTagBase { idc = 78036; };
        class AP_NameTag37: AP_NameTagBase { idc = 78037; };
        class AP_NameTag38: AP_NameTagBase { idc = 78038; };
        class AP_NameTag39: AP_NameTagBase { idc = 78039; };
        class AP_NameTag40: AP_NameTagBase { idc = 78040; };
        class AP_NameTag41: AP_NameTagBase { idc = 78041; };
        class AP_NameTag42: AP_NameTagBase { idc = 78042; };
        class AP_NameTag43: AP_NameTagBase { idc = 78043; };
        class AP_NameTag44: AP_NameTagBase { idc = 78044; };
        class AP_NameTag45: AP_NameTagBase { idc = 78045; };
        class AP_NameTag46: AP_NameTagBase { idc = 78046; };
        class AP_NameTag47: AP_NameTagBase { idc = 78047; };
        class AP_NameTag48: AP_NameTagBase { idc = 78048; };
        class AP_NameTag49: AP_NameTagBase { idc = 78049; };
        class AP_NameTag50: AP_NameTagBase { idc = 78050; };
        class AP_NameTag51: AP_NameTagBase { idc = 78051; };
        class AP_NameTag52: AP_NameTagBase { idc = 78052; };
        class AP_NameTag53: AP_NameTagBase { idc = 78053; };
        class AP_NameTag54: AP_NameTagBase { idc = 78054; };
        class AP_NameTag55: AP_NameTagBase { idc = 78055; };
        class AP_NameTag56: AP_NameTagBase { idc = 78056; };
        class AP_NameTag57: AP_NameTagBase { idc = 78057; };
        class AP_NameTag58: AP_NameTagBase { idc = 78058; };
        class AP_NameTag59: AP_NameTagBase { idc = 78059; };
        class AP_NameTag60: AP_NameTagBase { idc = 78060; };
        class AP_NameTag61: AP_NameTagBase { idc = 78061; };
        class AP_NameTag62: AP_NameTagBase { idc = 78062; };
        class AP_NameTag63: AP_NameTagBase { idc = 78063; };};};
