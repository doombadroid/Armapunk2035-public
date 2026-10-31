//! Toggles -> Arma parameters, session sets and generated files (LAUNCHER_SPEC §2).

use crate::manifest::Server;
use crate::Os;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum Allocator { ArmapunkMimalloc, ArmaMimalloc, Tbb, System }

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum WindowMode { Fullscreen, Windowed }

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct LinuxOpts { pub gamemode: bool, pub wayland: bool, pub dxvk_hud: bool, pub frame_cap: Option<u32> }
impl Default for LinuxOpts { fn default() -> Self { LinuxOpts { gamemode: true, wayland: false, dxvk_hud: false, frame_cap: None } } }

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct Toggles {
    pub reshade: bool,
    pub preset: String,
    pub key_effects: u32,
    pub key_overlay: u32,
    pub allocator: Allocator,
    pub huge_pages: bool,
    pub dxvk: bool,
    pub enable_ht: bool,
    pub ex_threads: u8,
    pub cpu_count: Option<u32>,
    pub main_thread_affinity: Option<String>,
    pub cpu_affinity: Option<String>,
    pub set_thread_characteristics: bool,
    pub max_mem: Option<u32>,
    pub max_vram: Option<u32>,
    pub no_logs: bool,
    pub auto_join: bool,
    pub window: WindowMode,
    pub skip_intro: bool,
    pub no_splash: bool,
    pub empty_world: bool,
    pub no_pause: bool,
    pub show_script_errors: bool,
    pub profile_name: Option<String>,
    pub linux: LinuxOpts,
}

impl Default for Toggles {
    fn default() -> Self {
        Toggles {
            reshade: true, preset: "armapunk-neon".into(), key_effects: 35, key_overlay: 36,
            allocator: Allocator::ArmapunkMimalloc, huge_pages: true, dxvk: false, enable_ht: true, ex_threads: 7,
            cpu_count: None, main_thread_affinity: None, cpu_affinity: None, set_thread_characteristics: false,
            max_mem: None, max_vram: None, no_logs: false, auto_join: true, window: WindowMode::Fullscreen,
            skip_intro: true, no_splash: true, empty_world: true, no_pause: false, show_script_errors: false,
            profile_name: None, linux: LinuxOpts::default(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct LaunchPlan { pub args: Vec<String>, pub sets: Vec<String>, pub generated: Vec<(String, String)>, pub byproducts: Vec<String> }

pub fn reshade_ini(t: &Toggles, preset_path: &str) -> String {
    format!(
        "[GENERAL]\nEffectSearchPaths=.\\reshade-shaders\\Shaders\\**\nTextureSearchPaths=.\\reshade-shaders\\Textures\\**\n\
PresetPath=.\\{}\nPerformanceMode=1\n\
PreprocessorDefinitions=RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000.0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0\n\n\
[INPUT]\nKeyOverlay={},0,0,0\nKeyEffects={},0,0,0\n\n[OVERLAY]\nTutorialProgress=4\n\n\
[DEPTH]\nDepthCopyBeforeClears=0\nUseAspectRatioHeuristics=1\n\n[ADDON]\nAddonPath=.\\reshade-addons\n",
        preset_path.replace('/', "\\"), t.key_overlay, t.key_effects
    )
}

pub fn plan(t: &Toggles, os: Os, mod_arg: &str, server: Option<(&Server, &str)>, avx2: bool, preset_path: Option<&str>) -> LaunchPlan {
    let mut p = LaunchPlan::default();
    let a = &mut p.args;
    a.push(format!("-mod={mod_arg}"));
    let alloc = if t.allocator == Allocator::ArmapunkMimalloc && !avx2 { Allocator::ArmaMimalloc } else { t.allocator };
    match alloc {
        Allocator::ArmapunkMimalloc => { a.push("-malloc=mimalloc_ap".into()); p.sets.push("mimalloc".into()); }
        Allocator::ArmaMimalloc => a.push("-malloc=mimalloc_bi".into()),
        Allocator::Tbb => a.push("-malloc=tbb4malloc_bi".into()),
        Allocator::System => a.push("-malloc=system".into()),
    }
    if t.huge_pages { a.push("-hugePages".into()); }
    if t.enable_ht { a.push("-enableHT".into()); }
    a.push(format!("-exThreads={}", t.ex_threads));
    if let Some(n) = t.cpu_count { a.push(format!("-cpuCount={n}")); }
    if let Some(m) = &t.main_thread_affinity { a.push(format!("-cpuMainThreadAffinity={m}")); }
    if let Some(m) = &t.cpu_affinity { a.push(format!("-cpuAffinity={m}")); }
    if t.set_thread_characteristics && os == Os::Windows { a.push("-setThreadCharacteristics".into()); }
    if let Some(n) = t.max_mem { a.push(format!("-maxMem={n}")); }
    if let Some(n) = t.max_vram { a.push(format!("-maxVRAM={n}")); }
    if t.no_logs { a.push("-noLogs".into()); }
    if t.window == WindowMode::Windowed { a.push("-window".into()); }
    if t.skip_intro { a.push("-skipIntro".into()); }
    if t.no_splash { a.push("-noSplash".into()); }
    if t.empty_world { a.push("-world=empty".into()); }
    if t.no_pause { a.push("-noPause".into()); }
    if t.show_script_errors { a.push("-showScriptErrors".into()); }
    if let Some(n) = &t.profile_name { a.push(format!("-name={n}")); }
    if t.auto_join {
        if let Some((s, pw)) = server {
            a.push(format!("-connect={}", s.host));
            a.push(format!("-port={}", s.port));
            if !pw.is_empty() { a.push(format!("-password={pw}")); }
        }
    }
    if t.reshade {
        p.sets.push("reshade".into());
        p.sets.push("immerse".into());
        if os == Os::Linux { p.sets.push("d3dcompiler".into()); }
        p.generated.push(("ReShade.ini".into(), reshade_ini(t, preset_path.unwrap_or("ReShadePreset.ini"))));
        p.byproducts.push("ReShade.log".into());
    }
    if t.dxvk && os == Os::Windows { p.sets.push("dxvk".into()); }
    p
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::manifest::Server;

    fn srv() -> Server { Server { name: "A".into(), host: "10.1.24.96".into(), port: 2302 } }

    #[test]
    fn defaults_linux() {
        let p = plan(&Toggles::default(), Os::Linux, "Z:\\m\\@Armapunk2035", Some((&srv(), "pw")), true, Some("reshade-presets/armapunk-neon.ini"));
        assert_eq!(p.args, vec![
            "-mod=Z:\\m\\@Armapunk2035", "-malloc=mimalloc_ap", "-hugePages", "-enableHT", "-exThreads=7",
            "-skipIntro", "-noSplash", "-world=empty", "-connect=10.1.24.96", "-port=2302", "-password=pw",
        ]);
        assert_eq!(p.sets, vec!["mimalloc", "reshade", "immerse", "d3dcompiler"]);
        assert_eq!(p.byproducts, vec!["ReShade.log"]);
        assert_eq!(p.generated.len(), 1);
        assert_eq!(p.generated[0].0, "ReShade.ini");
        assert!(p.generated[0].1.contains("PresetPath=.\\reshade-presets\\armapunk-neon.ini"));
    }

    #[test]
    fn allocator_fallback_without_avx2_and_everything_off() {
        let mut t = Toggles::default();
        t.reshade = false; t.huge_pages = false; t.enable_ht = false; t.ex_threads = 3;
        t.skip_intro = false; t.no_splash = false; t.empty_world = false; t.auto_join = false;
        t.window = WindowMode::Windowed; t.no_logs = true; t.cpu_count = Some(8);
        t.max_mem = Some(16384); t.show_script_errors = true; t.profile_name = Some("Doomba".into());
        let p = plan(&t, Os::Linux, "M", None, false, None);
        assert_eq!(p.args, vec![
            "-mod=M", "-malloc=mimalloc_bi", "-exThreads=3", "-cpuCount=8", "-maxMem=16384", "-noLogs",
            "-window", "-showScriptErrors", "-name=Doomba",
        ]);
        assert!(p.sets.is_empty());
        assert!(p.generated.is_empty());
    }

    #[test]
    fn windows_only_bits() {
        let mut t = Toggles::default();
        t.dxvk = true; t.set_thread_characteristics = true; t.reshade = false;
        let p = plan(&t, Os::Windows, "M", None, true, None);
        assert!(p.sets.contains(&"dxvk".to_string()));
        assert!(!p.sets.contains(&"d3dcompiler".to_string()));
        assert!(p.args.contains(&"-setThreadCharacteristics".to_string()));
        let linux = plan(&t, Os::Linux, "M", None, true, None);
        assert!(!linux.sets.contains(&"dxvk".to_string()));
        assert!(!linux.args.contains(&"-setThreadCharacteristics".to_string()));
    }
}
