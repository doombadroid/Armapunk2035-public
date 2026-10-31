// Fifty Shades of Female (FSOF) female heads — created by Zeealex ("Zee").
// Redistributed under the author's stated terms: "You can repack, retexture, re-configure, do
// anything you want, just make sure credit is given." Credit is carried here, in CfgPatches
// below, in the addon mod.cpp description, and in radio/addon/PROVENANCE.md.
// Assets below are Zeealex's originals and are UNMODIFIED; only this CfgPatches block is ours.
class CfgPatches {
	class zee_fsof {
		name = "Fifty Shades of Female (FSOF) — heads";
		author = "Zeealex";
		units[]={};
		weapons[]={};
		requiredVersion=0.1;
		requiredAddons[]={"A3_Characters_F_BLUFOR"};
	};
};
class CfgFaces
{
	class Default;
	class Man_A3: Default
	{
		class Default;
		class fsof_femaleCauc01_BlueEyes_NoHair: Default
		{
			name="Caucasian Female (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female (No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BrownEyes_NoHair: Default
		{
			name="Caucasian Female (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_GreenEyes_NoHair: Default
		{
			name="Caucasian Female (No Hair/Green)";
			scope=2;
			displayname="Caucasian Female (No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_HazelEyes_NoHair: Default
		{
			name="Caucasian Female (No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01t2_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 2 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 2(No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01t2_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 2 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 2(No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01t2_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 2(No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 2(No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc01t2_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 2(No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 2(No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 2 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 2 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 2 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 2 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 2 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 2 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t2_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 2 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 2 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 3 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 3(No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 3 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 3(No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 3(No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 3(No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 3(No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 3(No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 3 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 3 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 3 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 3 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 3 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 3 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t3_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 3 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 3 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 4 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 4(No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 4 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 4(No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 4(No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 4(No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 4(No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 4(No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 4 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 4 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 4 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 4 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 4 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 4 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_FemaleCauc01t4_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 4 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 4 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc01t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 5 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 5 (No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 5 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 5 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 5 (No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 5 (No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 5 (No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 5 (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 5 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 5 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 5 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 5 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 5 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 5 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 5 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 5 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 6 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 6(No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 6 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 6 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleCauc02t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 6 (No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 6 (No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 6 (No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 6 (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 6 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 6(Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 6(Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 6 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 6 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 6 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 6 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 6(Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 6(Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 6 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t2_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 6 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 6 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t2_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 7 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 7 (No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 7 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 7 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 7 (No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 7 (No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 7 (No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 7 (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 7 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 7 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 7 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 7 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Blue/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 7 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 7 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t3_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 7 (Bun/Hazel/Black)";
			scope=2;
			displayname="Caucasian Female 7 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t3_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BlueEyes_NoHair: Default
		{
			name="Caucasian Female 8 (No Hair/Blue)";
			scope=2;
			displayname="Caucasian Female 8 (No Hair/Blue)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBlue_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BrownEyes_NoHair: Default
		{
			name="Caucasian Female 8 (No Hair/Brown)";
			scope=2;
			displayname="Caucasian Female 8 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_GreenEyes_NoHair: Default
		{
			name="Caucasian Female 8 (No Hair/Green)";
			scope=2;
			displayname="Caucasian Female 8 (No Hair/Green)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeGreen_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_HazelEyes_NoHair: Default
		{
			name="Caucasian Female 8 (No Hair/Hazel)";
			scope=2;
			displayname="Caucasian Female 8 (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BlueEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 8 (Bun/Blue/Blonde)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Blue/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BrownEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Blonde)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Brown/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_GreenEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 8 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Green/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_HazelEyes_Bun_BlondeHair: Default
		{
			name="Caucasian Female 8 (Bun/Hazel/Blonde)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Hazel/Blonde)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_blonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BlueEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Blue/Light Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Blue/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BrownEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Brown/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_GreenEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Green/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_HazelEyes_Bun_LBrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Light Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Hazel/Light Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_dirtyblonde_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BlueEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Blue/Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BrownEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Brown/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_GreenEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Green/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_HazelEyes_Bun_BrownHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Brown)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Hazel/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BlueEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 8 (Bun/Blue/Black)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Blue/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BlueEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_brown_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_BrownEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_BrownEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_GreenEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Green/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_GreenEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleCauc02t4_HazelEyes_Bun_BlackHair: Default
		{
			name="Caucasian Female 8 (Bun/Brown/Black)";
			scope=2;
			displayname="Caucasian Female 8 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_femaleCauc02t4_HazelEyes";
			material="zee_fsof\Data\fsof_hair.rvmat";
			texture="zee_fsof\Data\fsof_hair_black_ca.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_White.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_White_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_White.rvmat";
		};
		class fsof_femaleBlk01_HazelEyes_BlkHair: Default
		{
			name="African Female 1 (Bun/Hazel/Black)";
			scope=2;
			displayname="African Female 1 (Bun/Hazel/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleBlk01";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
		class fsof_femaleBlk01_BrownEyes_BlkHair: Default
		{
			name="African Female 1 (Bun/Brown/Black)";
			scope=2;
			displayname="African Female 1 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleBlk01";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
		class fsof_femaleBlk01_BrownEyes_NoHair: Default
		{
			name="African Female 1 (No Hair/Brown)";
			scope=2;
			displayname="African Female 1 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleBlk01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
		class fsof_femaleBlk01_HazelEyes_NoHair: Default
		{
			name="African Female 1 (No Hair/Hazel)";
			scope=2;
			displayname="African Female 1 (No Hair/Hazel)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleBlk01_NoHair";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeHazel_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
		class fsof_femaleAsi01_BrownEyes_BlkHair: Default
		{
			name="Asian Female 1 (Bun/Brown/Black)";
			scope=2;
			displayname="Asian  Female 1 (Bun/Brown/Black)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleAsi01";
			material="zee_fsof\Data\fsof_eye.rvmat";
			texture="zee_fsof\Data\fsof_eyeBrown_co.paa";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
		class fsof_femaleAsi01_BrownEyes_NoHair: Default
		{
			name="Asian Female 1 (No Hair/Brown)";
			scope=2;
			displayname="Asian  Female 1 (No Hair/Brown)";
			identityTypes[]=
			{
				"G_CIVIL_female"
			};
			head="fsof_head_FemaleAsi01_NoHair";
			disabled=0;
			textureHL="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
			textureHL2="\A3\Characters_F\Heads\Data\hl_Black_bald_co.paa";
			materialHL2="\A3\Characters_F\Heads\Data\hl_black_bald_muscular.rvmat";
		};
	};
};
class CfgHeads
{
	class Default_A3;
	class fsof_head_FemaleCauc01_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc01_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc01_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc01_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc01_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01_NoHair.p3d";
	};
	class fsof_head_FemaleCauc01t2_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t2_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc01t2_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t2_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc01t2_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t2_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc01t2_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t2_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc01t2_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t2_NoHair.p3d";
	};
	class fsof_head_FemaleCauc01t3_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t3_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc01t3_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t3_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc01t3_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t3_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc01t3_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t3_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc01t3_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t3_NoHair.p3d";
	};
	class fsof_head_FemaleCauc01t4_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t4_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc01t4_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t4_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc01t4_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t4_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc01t4_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t4_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc01t4_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc01t4_NoHair.p3d";
	};
	class fsof_head_FemaleCauc02_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc02_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc02_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc02_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc02_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02_NoHair.p3d";
	};
	class fsof_head_FemaleCauc02t2_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t2_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc02t2_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t2_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc02t2_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t2_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc02t2_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t2_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc02t2_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t2_NoHair.p3d";
	};
	class fsof_head_FemaleCauc02t3_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t3_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc02t3_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t3_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc02t3_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t3_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc02t3_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t3_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc02t3_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t3_NoHair.p3d";
	};
	class fsof_head_FemaleCauc02t4_BlueEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t4_BlueEyes.p3d";
	};
	class fsof_head_FemaleCauc02t4_BrownEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t4_BrownEyes.p3d";
	};
	class fsof_head_FemaleCauc02t4_GreenEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t4_GreenEyes.p3d";
	};
	class fsof_head_FemaleCauc02t4_HazelEyes: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t4_HazelEyes.p3d";
	};
	class fsof_head_FemaleCauc02t4_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleCauc02t4_NoHair.p3d";
	};
	class fsof_head_FemaleBlk01: Default_A3
	{
		model="zee_fsof\fsof_femaleBlk_BlackHair.p3d";
	};
	class fsof_head_FemaleBlk01_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleBlk_NoHair.p3d";
	};
	class fsof_head_FemaleAsi01: Default_A3
	{
		model="zee_fsof\fsof_femaleAsi_BlackHair.p3d";
	};
	class fsof_head_FemaleAsi01_NoHair: Default_A3
	{
		model="zee_fsof\fsof_femaleAsi_NoHair.p3d";
	};
};
class CfgIdentities
{
	class G_CIVIL_female;
};
class cfgMods
{
	author="Zee";
	timepacked="1598192983";
};
