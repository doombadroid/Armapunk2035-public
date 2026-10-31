// Armapunk 2035 main menu — RscDisplayMain overlay (spec: repo mainmenu.md).
//
// Strategy: re-declare RscDisplayMain WITH its real parent (RscStandardDisplay)
// so the config MERGES cleanly — a parentless re-declare strips the base class
// ("Updating base class 'RscStandardDisplay'->''" in the RPT) and broke the
// whole display on 2026-08-03; CBA's own cba_settings patch is the working
// precedent for the correct shape. Vanilla onLoad/BIS_fnc_initDisplay chain
// and all original controls stay intact underneath; menu.sqf hides them and
// activates the originals by IDC.
// Bootstrap: CfgFunctions preInit watcher (fn_menuWatch.sqf) — the ONLY
// spawner. Display/control EHs fire before the intro mission exists and
// anything they spawn dies in the mission-start scheduler wipe; they carry
// diagnostic tags only. menu.sqf marks its own successful entry
// (AP35_bootedDisplay), so a dead spawn can never satisfy the guard.

class CfgPatches {
    class ArmapunkMenu {
        units[] = {};
        weapons[] = {};
        requiredVersion = 1.0;
        requiredAddons[] = {"A3_UI_F"};   // merge our override after the vanilla display
        author = "Doomba";
        name = "Armapunk 2035 Main Menu";
    };
};

// Mod settings (read by menu.sqf via configFile >> "ArmapunkMenu").
class ArmapunkMenu {
    // {"host", port, "password"} -> DEPLOY jacks straight into the darknet.
    // Empty -> DEPLOY opens the server browser until the Armapunk server exists.
    deployServer[] = {};
};

class RscText;
class RscPicture;
class RscButton;
class RscVideo;   // RscPicture + autoplay/loops (vanilla spotlights use it)
class RscStandardDisplay;

class AP35_Video: RscVideo {
    idc = -1;
    text = "";        // menu.sqf assigns the .ogv; assignment starts playback
    autoplay = 1;
    x = 0; y = 0; w = 0; h = 0;   // all geometry set by menu.sqf letterbox math
};

// Sole bootstrap: CfgFunctions preInit watcher — the main menu runs an intro
// mission, so preInit fires there (and again on every return to the menu),
// with no CBA or event-handler dependency. See fn_menuWatch.sqf.
class CfgFunctions {
    class AP35 {
        class menu {
            file = "\armapunk_menu";
            class menuWatch { preInit = 1; };
        };
    };
};

// Diagnostic tag only — display/control EHs fire BEFORE the intro mission
// starts, and scripts spawned there die in the 0:22:15 scheduler transition
// without executing a single line (root cause of the silent v1-v3 boots).
// The preInit watcher is the sole spawner; these tags remain as evidence.
class Extended_DisplayLoad_EventHandlers {
    class RscDisplayMain {
        armapunk_menu = "diag_log 'AP35 hook: XEH (tag only)';";
    };
};

class RscDisplayMain: RscStandardDisplay {
    class Controls {
        // Ink backdrop + 16:9 letterbox bars + fallback bootstrap hook.
        class AP35_Letterbox: RscText {
            idc = 941600;
            colorBackground[] = {0.0196, 0.0118, 0.0078, 1};   // #050302
            x = "safezoneXAbs"; y = "safezoneY";
            w = "safezoneWAbs"; h = "safezoneH";
            // Real bootstrap again, not just a tag: without the intro MISSION
            // (players launching with -skipIntro) the CfgFunctions preInit
            // watcher never runs and the menu never appears. There is no
            // mission-start scheduler wipe in that case, so a spawn from here
            // survives; when the intro DOES run, menu.sqf's own
            // AP35_bootedDisplay marker keeps this from double-booting.
            onLoad = "diag_log 'AP35 hook: ctrlOnLoad'; private _d = ctrlParent param [0, _this]; if (isNil {uiNamespace getVariable 'AP35_boot'}) then {uiNamespace setVariable ['AP35_boot', compile preprocessFileLineNumbers '\armapunk_menu\menu.sqf']}; if !(_d isEqualTo (uiNamespace getVariable ['AP35_bootedDisplay', displayNull])) then {[_d] spawn (uiNamespace getVariable 'AP35_boot')};";
        };
        class AP35_VideoIntro: AP35_Video { idc = 941601; loops = 0; };
        class AP35_VideoLoop: AP35_Video { idc = 941602; loops = 1; };   // belt only; VideoStopped re-arms it

        // Three menu rows (baked strips; texture = whole visual state) ...
        class AP35_Row0: RscPicture {
            idc = 941610;
            text = "\armapunk_menu\ui\row_0_dim.paa";
            x = 0; y = 0; w = 0; h = 0;
        };
        class AP35_Row1: AP35_Row0 { idc = 941611; text = "\armapunk_menu\ui\row_1_dim.paa"; };
        class AP35_Row2: AP35_Row0 { idc = 941612; text = "\armapunk_menu\ui\row_2_dim.paa"; };

        // ... their invisible hitboxes (buttons: reliable hover + click + no chrome) ...
        class AP35_Hit0: RscButton {
            idc = 941620;
            text = "";
            colorBackground[] = {0, 0, 0, 0};
            colorBackgroundActive[] = {0, 0, 0, 0};
            colorFocused[] = {0, 0, 0, 0};
            colorText[] = {0, 0, 0, 0};
            colorDisabled[] = {0, 0, 0, 0};
            colorShadow[] = {0, 0, 0, 0};
            colorBorder[] = {0, 0, 0, 0};
            shadow = 0;
            soundEnter[] = {"", 0, 1};
            soundPush[] = {"", 0, 1};
            soundClick[] = {"", 0, 1};
            soundEscape[] = {"", 0, 1};
            x = 0; y = 0; w = 0; h = 0;
        };
        class AP35_Hit1: AP35_Hit0 { idc = 941621; };
        class AP35_Hit2: AP35_Hit0 { idc = 941622; };

        // ... and the bottom-bar hint strip.
        class AP35_Hint: RscPicture {
            idc = 941630;
            text = "\armapunk_menu\ui\hint_0.paa";
            x = 0; y = 0; w = 0; h = 0;
        };
    };
};
