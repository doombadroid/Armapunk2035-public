#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
use apl_core::{launch, manifest, orchestrate, paths, profile, session, steamcfg, sync, Os};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::time::Duration;
use tauri::Emitter;

#[derive(Serialize, Deserialize, Clone)]
struct Settings { toggles: profile::Toggles, cdn_base: String, channel: String, password: String }

impl Default for Settings {
    fn default() -> Self {
        Settings { toggles: profile::Toggles::default(), cdn_base: "http://127.0.0.1:8750".into(), channel: "test".into(), password: String::new() }
    }
}

#[derive(Serialize)]
struct StateView {
    toggles: profile::Toggles, cdn_base: String, channel: String, password: String,
    release: Option<String>, server: Option<manifest::Server>, presets: Vec<manifest::Preset>,
    arma_dir: Option<String>, launch_options_ok: bool, error: Option<String>,
}

fn data() -> PathBuf { paths::data_dir() }
fn load_settings() -> Settings {
    if let Some(s) = std::fs::read(data().join("settings.json")).ok().and_then(|b| serde_json::from_slice(&b).ok()) {
        return s;
    }
    // First run: adopt the player's existing Steam launch options as the Linux defaults.
    let mut s = Settings::default();
    if let Ok(f) = paths::find_linux(&home()) {
        if let Some(cur) = std::fs::read_to_string(&f.localconfig).ok().and_then(|t| steamcfg::current_launch_options(&t, "107410")) {
            s.toggles.linux = steamcfg::import_opts(&cur);
        }
    }
    s
}
fn cached_manifest(channel: &str) -> anyhow::Result<manifest::Manifest> {
    let m = std::fs::read(data().join(format!("{channel}.manifest.json")))?;
    let s = std::fs::read(data().join(format!("{channel}.manifest.json.sig")))?;
    manifest::verify(&m, &s, &manifest::compiled_keys())
}
fn home() -> PathBuf { std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default() }
fn wanted_sets(t: &profile::Toggles) -> Vec<String> {
    let mut v = vec!["mod".to_string()];
    v.extend(profile::plan(t, Os::current(), "", None, true, None).sets);
    v
}

#[tauri::command]
fn get_state() -> StateView {
    let s = load_settings();
    let found = paths::find_linux(&home());
    let man = cached_manifest(&s.channel).ok();
    let lo_ok = found.as_ref().ok().and_then(|f| std::fs::read_to_string(&f.localconfig).ok())
        .map(|t| {
            let cur = steamcfg::current_launch_options(&t, "107410").unwrap_or_default();
            steamcfg::managed_options(&cur, &s.toggles.linux, s.toggles.reshade) == cur
        }).unwrap_or(false);
    StateView {
        release: man.as_ref().map(|m| m.release.clone()),
        server: man.as_ref().map(|m| m.server.clone()),
        presets: man.as_ref().map(|m| m.presets.clone()).unwrap_or_default(),
        arma_dir: found.as_ref().ok().map(|f| f.arma_dir.display().to_string()),
        launch_options_ok: lo_ok,
        error: found.err().map(|e| e.to_string()),
        toggles: s.toggles, cdn_base: s.cdn_base, channel: s.channel, password: s.password,
    }
}

#[tauri::command]
fn save_settings(toggles: profile::Toggles, cdn_base: String, channel: String, password: String) -> Result<(), String> {
    std::fs::create_dir_all(data()).map_err(|e| e.to_string())?;
    let s = Settings { toggles, cdn_base, channel, password };
    std::fs::write(data().join("settings.json"), serde_json::to_vec_pretty(&s).unwrap()).map_err(|e| e.to_string())
}

#[tauri::command]
async fn sync(app: tauri::AppHandle) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || -> anyhow::Result<String> {
        let s = load_settings();
        let base = s.cdn_base.trim_end_matches('/').to_string();
        let c = reqwest::blocking::Client::builder().timeout(Duration::from_secs(20)).build()?;
        let m = c.get(format!("{base}/{}/manifest.json", s.channel)).send()?.error_for_status()?.bytes()?.to_vec();
        let sig = c.get(format!("{base}/{}/manifest.json.sig", s.channel)).send()?.error_for_status()?.bytes()?.to_vec();
        let man = manifest::verify(&m, &sig, &manifest::compiled_keys())?;
        std::fs::create_dir_all(data())?;
        std::fs::write(data().join(format!("{}.manifest.json", s.channel)), &m)?;
        std::fs::write(data().join(format!("{}.manifest.json.sig", s.channel)), &sig)?;
        let wanted = man.select(Os::current(), &wanted_sets(&s.toggles));
        sync::sync_all(&base, &wanted, &data().join("files"), &mut |path, done, total| {
            let _ = app.emit("sync-progress", serde_json::json!({ "path": path, "done": done, "total": total }));
        })?;
        Ok(man.release)
    }).await.map_err(|e| e.to_string())?.map_err(|e| format!("{e:#}"))
}

#[tauri::command]
async fn launch() -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(|| -> anyhow::Result<String> {
        let s = load_settings();
        let found = paths::find_linux(&home())?;
        let man = cached_manifest(&s.channel)?;
        let files = data().join("files");
        let mod_arg = paths::proton_path(&files.join("@Armapunk2035"));
        let preset = man.presets.iter().find(|p| p.id == s.toggles.preset).map(|p| p.path.clone());
        let avx2 = std::arch::is_x86_feature_detected!("avx2");
        let plan = profile::plan(&s.toggles, Os::current(), &mod_arg, Some((&man.server, &s.password)), avx2, preset.as_deref());
        let session_files = man.select(Os::current(), &plan.sets);
        let ctx = orchestrate::Ctx { game_dir: found.arma_dir, data_dir: data(), files_root: files };
        let out = orchestrate::run(&ctx, &plan, &session_files, &launch::SteamLinux, Duration::from_secs(120), Duration::from_secs(2))?;
        Ok(match out { launch::Outcome::Exited => "exited", launch::Outcome::NeverStarted => "never-started" }.into())
    }).await.map_err(|e| e.to_string())?.map_err(|e| format!("{e:#}"))
}

#[tauri::command]
fn repair() -> Result<bool, String> { session::end(&data()).map_err(|e| e.to_string()) }

#[tauri::command]
fn apply_launch_options() -> Result<bool, String> {
    let s = load_settings();
    let found = paths::find_linux(&home()).map_err(|e| e.to_string())?;
    steamcfg::apply(&found.localconfig, &s.toggles.linux, s.toggles.reshade).map_err(|e| e.to_string())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![get_state, save_settings, sync, launch, repair, apply_launch_options])
        .run(tauri::generate_context!())
        .expect("error while running the Armapunk launcher");
}
