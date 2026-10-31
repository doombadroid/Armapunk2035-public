//! Headless M1 end-to-end: the same core calls the UI's SYNC and LAUNCH buttons make.
//! cargo run --release --example e2e_linux -- http://127.0.0.1:8750 test
use apl_core::{launch, manifest, orchestrate, paths, profile, sync, Os};
use std::time::Duration;

fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let (base, channel) = (args[1].trim_end_matches('/').to_string(), args[2].clone());
    let c = reqwest::blocking::Client::new();
    let m = c.get(format!("{base}/{channel}/manifest.json")).send()?.error_for_status()?.bytes()?.to_vec();
    let s = c.get(format!("{base}/{channel}/manifest.json.sig")).send()?.error_for_status()?.bytes()?.to_vec();
    let man = manifest::verify(&m, &s, &manifest::compiled_keys())?;
    println!("[e2e] verified release {} ({} files)", man.release, man.files.len());
    let mut t = profile::Toggles::default();
    t.auto_join = false;
    let data = paths::data_dir();
    let files = data.join("files");
    let mut sets = vec!["mod".to_string()];
    sets.extend(profile::plan(&t, Os::current(), "", None, true, None).sets);
    let wanted = man.select(Os::current(), &sets);
    let mut last = 0u64;
    sync::sync_all(&base, &wanted, &files, &mut |_, done, total| { if done - last > 50 << 20 || done == total { last = done; println!("[e2e] sync {}/{} MB", done >> 20, total >> 20); } })?;
    println!("[e2e] synced {} files", wanted.len());
    let found = paths::find_linux(&dirs::home_dir().unwrap())?;
    let preset = man.presets.iter().find(|p| p.id == t.preset).map(|p| p.path.clone());
    let plan = profile::plan(&t, Os::current(), &paths::proton_path(&files.join("@Armapunk2035")), None,
        std::arch::is_x86_feature_detected!("avx2"), preset.as_deref());
    println!("[e2e] args {:?}\n[e2e] sets {:?}", plan.args, plan.sets);
    let session_files = man.select(Os::current(), &plan.sets);
    let ctx = orchestrate::Ctx { game_dir: found.arma_dir, data_dir: data, files_root: files };
    let out = orchestrate::run(&ctx, &plan, &session_files, &launch::SteamLinux, Duration::from_secs(120), Duration::from_secs(2))?;
    println!("[e2e] outcome {:?}", out);
    Ok(())
}
