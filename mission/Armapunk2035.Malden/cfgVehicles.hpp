// owner 2026-06-14: mission-side CfgVehicles overrides.
//
// RADAR off on the two PURCHASABLE jets (I_Plane_Fighter_03_CAS_F = Gryphon CAS, I_Plane_Fighter_04_F =
// Gryphon). There is NO runtime script command to toggle a vehicle's radar sensor, so it must be done at
// config level. We reach the Jets-DLC sensor through the forward-declared parent chain and set the active
// radar component inactive (active = 0). IR / visual / passive-radar sensors are left untouched -- only the
// jet's own emitting radar (used to scan + lock other aircraft) is disabled.
//
// THERMAL note: not done here. fn_prepareVehicle already runs `disableTIEquipment true` on every spawned /
// garage-pulled vehicle (incl. the rebel-shop Ifrit HMG), which removes thermal optics. A config TI strip is
// only needed if a vehicle is spawned OUTSIDE that path (admin/debug) -- add per-turret here if it shows up.

class Plane;
class Plane_Base_F: Plane {class Components;};

class Plane_Fighter_03_base_F: Plane_Base_F {class Components: Components {class SensorsManager;};};
class I_Plane_Fighter_03_CAS_F: Plane_Fighter_03_base_F {class Components: Components {class SensorsManager: SensorsManager {
            class Components: Components {class ActiveRadarSensorComponent {active = 0;};};};};};

class Plane_Fighter_04_base_F: Plane_Base_F {class Components: Components {class SensorsManager;};};
class I_Plane_Fighter_04_F: Plane_Fighter_04_base_F {class Components: Components {class SensorsManager: SensorsManager {
            class Components: Components {class ActiveRadarSensorComponent {active = 0;};};};};};

// THERMAL: strip the Ti (thermal) vision mode from the armed Ifrit gunner optics at config level so it's
// gone permanently for ALL gunners + admin/debug-spawned vehicles, not just per-spawn disableTIEquipment.
// Covers the HMG (the rebel-shop one) and the GMG. Merges into the existing gunner optics modes -- if a
// turret's optics class names differ this is a harmless no-op (disableTIEquipment stays as the fallback).
class Car;
class Car_F: Car {class Turrets;};
class MRAP_02_base_F: Car_F {class Turrets: Turrets {class MainTurret;};};
// owner 2026-07-23: the ARMED Ifrits inherit through HMG/GMG-specific base classes (BIS_fnc_returnParents:
// O_MRAP_02_hmg_F -> MRAP_02_hmg_base_F -> MRAP_02_base_F). The RCWS MainTurret + its optics/zeroing live on
// those *_hmg_base_F / *_gmg_base_F classes, so the override chain MUST pass through them. The earlier
// version declared MRAP_02_base_F as the direct parent, which re-parented the class -> the override never
// merged onto the real turret (only disableTIEquipment's thermal took, masking the failure).
class MRAP_02_hmg_base_F: MRAP_02_base_F {class Turrets: Turrets {class MainTurret;};};
class MRAP_02_gmg_base_F: MRAP_02_base_F {class Turrets: Turrets {class MainTurret;};};
// owner 2026-07-23: zoom / T-zero / thermal lock PARKED mid-diagnosis. The parent chain above is now
// correct (the override finally merges), but the exact optic properties are still unconfirmed and a wrong
// guess brought thermal back. Rather than keep blind-guessing (the in-game debug console is dead, so the
// merged config can't be read), the turret override is emptied back to a no-op -- disableTIEquipment in
// fn_prepareVehicle keeps thermal off on purchased/garaged Ifrit HMGs exactly as before. Revisit once the
// debug console is restored so the merged config can be inspected.
// owner 2026-07-24: Ifrit HMG optic lock via mission CfgVehicles is a DEAD END -- PROVEN by an in-game
// merged-config dump: the turret reads pure BASE values (ViewOptics_min 0.03482, discreteDistance [100..1500])
// no matter what this override declares. Mission description.ext CfgVehicles does NOT merge into a binarized
// BASE vehicle's turret hierarchy for existing instances; only a client-side ADDON could, which a public
// no-mod server can't require. Zoom / T-auto-zero must be handled by SCRIPT (block the keys for the Ifrit HMG
// gunner), not config. Left as a no-op so the class chain stays valid for the jet-radar block above.
class O_MRAP_02_hmg_F: MRAP_02_hmg_base_F {class Turrets: Turrets {class MainTurret: MainTurret {};};};
class O_MRAP_02_gmg_F: MRAP_02_gmg_base_F {class Turrets: Turrets {class MainTurret: MainTurret {};};};

// owner 2026-07-10 (owner request): STRIDER (I_MRAP_03_F) GLASS buff. Bump each windscreen/window pane's armor
// 1.5 -> 3.0 (2x). Stock Strider glass is ALREADY identical to the Ifrit's per pane (both armor 1.5,
// explosionShielding 3) -- the Ifrit only feels tougher because it has 11 glass panes vs the Strider's 5. This
// makes the Strider's 5 panes each twice as resistant. HitPoints is INHERITED (class HitPoints: HitPoints) so
// every OTHER hitpoint (engine/wheels/body/fuel) is left stock -- only the 5 HitGlass armor values change.
// (Water/"boat mode" speed boost was tried + abandoned -- too janky; Strider water travel left at stock.)
class MRAP_03_base_F: Car_F {class HitPoints;};
class I_MRAP_03_F: MRAP_03_base_F {class HitPoints: HitPoints {class HitGlass1 { armor = 3.0; };
        class HitGlass2 { armor = 3.0; };
        class HitGlass3 { armor = 3.0; };
        class HitGlass4 { armor = 3.0; };
        class HitGlass5 { armor = 3.0; };};};
