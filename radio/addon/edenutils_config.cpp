// armapunk_edenutils — Eden editor conveniences for this box's editing setup.
// Editor-only: adds Tools-menu entries in 3DEN. Never required by the mission.
class CfgPatches {
    class armapunk_edenutils {
        units[] = {}; weapons[] = {};
        requiredVersion = 1.0;
        requiredAddons[] = {"3DEN"};
    };
};

class ctrlMenuStrip;
class display3DEN {
    class Controls {
        class MenuStrip : ctrlMenuStrip {
            class Items {
                class Tools {
                    items[] += { "APK_DrawModels", "APK_DrawModelsAuto" };
                };
                class APK_DrawModels {
                    text = "APK: Draw MAD Models (edenDraw)";
                    action = "call compile preprocessFileLineNumbers 'edenDraw.sqf';";
                };
                class APK_DrawModelsAuto {
                    text = "APK: Auto-redraw on every save";
                    action = "if (isNil 'APK_edenAutoDraw') then { APK_edenAutoDraw = add3DENEventHandler ['OnMissionSave', { call compile preprocessFileLineNumbers 'edenDraw.sqf'; }]; systemChat 'APK: auto-redraw armed for this session'; } else { systemChat 'APK: already armed'; };";
                };
            };
        };
    };
};
