// @MaldenRadio — marker addon. Carries NO content beyond this class + the extension DLL
// shipped beside it; the mission detects it via isClass (configFile >> "CfgPatches" >> "MaldenRadio").
class CfgPatches {
    class MaldenRadio {
        name = "Armapunk 2035 Client Mod";
        author = "Doomba";
        units[] = {};
        weapons[] = {};
        requiredVersion = 1.98;
        requiredAddons[] = {};
        maldenradio_version = 1; // bump on breaking extension-contract changes
    };
};
