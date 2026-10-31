// Armapunk 2035 client mod -- custom player animations. OPTIONAL: the mission tests
// isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> "AP_WallRunL_rfl") and falls back to vanilla states.
// Source clip: Mixamo "Wall Run", retargeted to the A3 skeleton (~/blender_work/wallrun/retarget.py), root motion
// stripped -- the mission's mover (fn_parkourMove.sqf) owns the trajectory. L = wall on the player's LEFT.
// One rtm per side, three states per side: the weapon set decides the action class, exactly like the
// vanilla Meva states the mission used before (a rifle state on an unarmed unit is corrected by the engine).
class CfgPatches {
    class AP_Anims {
        name = "Armapunk 2035 - Animations";
        author = "Doomba";
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Anims_F_Config_Sdr"};
    };
};

class CfgMovesBasic;
class CfgMovesMaleSdr: CfgMovesBasic {
    class States {
        class AmovPercMevaSrasWrflDf;
        class AmovPercMevaSnonWnonDf;
        class AmovPercMevaSrasWpstDf;
        class AP_WallRunL_rfl: AmovPercMevaSrasWrflDf {
            file = "ap_anims\anims\AP_wallrun_L.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
        class AP_WallRunR_rfl: AmovPercMevaSrasWrflDf {
            file = "ap_anims\anims\AP_wallrun_R.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
        class AP_WallRunL_non: AmovPercMevaSnonWnonDf {
            file = "ap_anims\anims\AP_wallrun_L.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
        class AP_WallRunR_non: AmovPercMevaSnonWnonDf {
            file = "ap_anims\anims\AP_wallrun_R.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
        class AP_WallRunL_pst: AmovPercMevaSrasWpstDf {
            file = "ap_anims\anims\AP_wallrun_L.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
        class AP_WallRunR_pst: AmovPercMevaSrasWpstDf {
            file = "ap_anims\anims\AP_wallrun_R.rtm";
            speed = -1.1;                 // seconds. Keep equal to fn_parkourCfg "wallClipRunTime"
            looped = 0;
            variantsPlayer[] = {};
            variantsAI[] = {};
            aiming = "aimingNo";          // pure mocap: no mouse-aim, head-look or leg blending on top
            aimingBody = "aimingUpNo";
            head = "headNo";
            legs = "legsNo";
            leftHandIKCurve[] = {};       // the rtm drives both hands; the weapon bone rides the right hand
            rightHandIKCurve[] = {};
            weaponIK = 0;
            enableOptics = 0;
            disableWeapons = 1;
            disableWeaponsLong = 1;
            canPullTrigger = 0;
            canReload = 0;
            headBobMode = 2;
            headBobStrength = 0.1;
            soundEnabled = 0;
            relSpeedMin = 1;
            relSpeedMax = 1;
            interpolationSpeed = 6;
            interpolationRestart = 1;
            // owner 2026-09-20 (first in-engine test): NO ConnectTo / InterpolateTo override. With the only edge out being
            // InterpolateTo Unconscious, the engine (which wants "stop" for an idle player) left the state at once THROUGH
            // Unconscious -> incapacitated -> healed -> stand: prone, clip never seen. The base state's graph stays, and
            // minPlayTime holds the clip the way BI's step-over does (AovrPercMstpSrasWrflDf: looped 0, minPlayTime 0.69).
            minPlayTime = 0.95;
            canBlendStep = 0;
        };
    };
};
