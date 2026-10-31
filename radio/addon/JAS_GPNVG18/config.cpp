// GPNVG-18 panoramic (quad-tube) night vision — created by SweetJason / "ColdJason".
// Included with the author's permission, granted directly on 2026-08-02. The upstream release
// carries no written licence, so that conversation is the whole permission record — see
// radio/addon/PROVENANCE.md.
// Assets below are the author's originals and are UNMODIFIED; only this CfgPatches block is ours.
class CfgPatches{
	class JAS_GPNVG18 {
		name = "GPNVG-18 Panoramic Night Vision";
		author = "SweetJason (ColdJason)";
		units[]={};
		weapons[]={
			"JAS_GPNVG18_Tan","JAS_GPNVG18_blk",
			"JAS_GPNVG18_Tan_TI","JAS_GPNVG18_blk_TI",
			"JAS_GPNVG18_Full_Tan_TI","JAS_GPNVG18_Full_blk_TI"
		};
		requiredVersion=0.1;
		requiredAddons[]={};
	};
};
class CfgWeapons
{
	class Default;
	class ItemCore: Default{};
	class InventoryItem_Base_F;
	class HeadgearItem;
	class NVGoggles;
	class JAS_GPNVG18_Tan: NVGoggles{
		scope=1;
		displayName="GPNVG-18 (Tan)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Tan.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Tan_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Tan_OFF.p3d";
			mass=4;
		};
	};
	class JAS_GPNVG18_blk: NVGoggles
	{
		scope=1;
		displayName="GPNVG-18 (Black)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Blk.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Blk_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Blk_OFF.p3d";
			mass=4;
		};
	};
	class JAS_GPNVG18_Tan_TI: NVGoggles
	{
		scope=1;
		displayName="GPNVG-18 TI (Tan)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Tan.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		visionMode[]=
		{
			"Normal",
			"NVG",
			"TI"
		};
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Tan_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Tan_OFF.p3d";
			mass=4;
		};
	};
	class JAS_GPNVG18_blk_TI: NVGoggles
	{
		scope=1;
		displayName="GPNVG-18 TI (Black)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Blk.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		visionMode[]=
		{
			"Normal",
			"NVG",
			"TI"
		};
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Blk_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Blk_OFF.p3d";
			mass=4;
		};
	};
	class JAS_GPNVG18_Full_Tan_TI: NVGoggles
	{
		scope=1;
		displayName="GPNVG-18 TI Overwatch (Tan)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene_1.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Tan.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		visionMode[]=
		{
			"Normal",
			"NVG",
			"TI"
		};
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Tan_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Tan_OFF.p3d";
			mass=4;
		};
	};
	class JAS_GPNVG18_Full_blk_TI: NVGoggles
	{
		scope=1;
		displayName="GPNVG-18 TI Overwatch (Black)";
		nameSound="nvgoggles";
		simulation="NVGoggles";
		showEmpty=0;
		muzzlePos="usti hlavne";
		muzzleEnd="konec hlavne";
		value=5;
		opticsZoomMin=1;
		opticsZoomMax=1;
		modelOptics="\JAS_GPNVG18\NVG_Scene_1.p3d";
		model="\A3\Weapons_f\binocular\nvg_proxy";
		picture="\JAS_GPNVG18\ui\GPNVG18_Blk.paa";
		descriptionUse="$STR_A3_cfgWeapons_Default_NVGoggles1";
		visionMode[]=
		{
			"Normal",
			"NVG",
			"TI"
		};
		class Library
		{
			libTextDesc="$STR_LIB_NV_GOGGLES";
		};
		descriptionShort="$STR_DSS_NV_GOGGLES";
		class ItemInfo
		{
			type=616;
			hmdType=0;
			uniformModel="\JAS_GPNVG18\JAS_GPNVG18_Blk_ON.p3d";
			modelOff="\JAS_GPNVG18\JAS_GPNVG18_Blk_OFF.p3d";
			mass=4;
		};
	};
};
class cfgMods
{
	author="ColdJason";
	timepacked="1555418919";
};
