//! Linux: keep Steam's Arma 3 launch options carrying the Wine overrides and env toggles (LAUNCHER_SPEC §2.4).

use crate::profile::LinuxOpts;
use crate::vdf::{self, Value};
use anyhow::{bail, Context, Result};
use std::path::Path;

const OURS: [&str; 4] = ["WINEDLLOVERRIDES=", "DXVK_HUD=", "DXVK_FRAME_RATE=", "PROTON_ENABLE_WAYLAND="];

/// Splits a quote-aware launch-option string into tokens.
fn tokens(s: &str) -> Vec<String> {
    let (mut out, mut cur, mut q) = (Vec::new(), String::new(), false);
    for c in s.chars() {
        match c {
            '"' => { q = !q; cur.push(c); }
            c if c.is_whitespace() && !q => { if !cur.is_empty() { out.push(std::mem::take(&mut cur)); } }
            c => cur.push(c),
        }
    }
    if !cur.is_empty() { out.push(cur); }
    out
}

pub fn managed_options(existing: &str, o: &LinuxOpts, reshade: bool) -> String {
    let toks = tokens(existing);
    let (before, after) = match toks.iter().position(|t| t == "%command%") {
        Some(i) => (toks[..i].to_vec(), toks[i + 1..].to_vec()),
        None => (Vec::new(), toks),
    };
    let mut env: Vec<String> = before.into_iter()
        .filter(|t| t != "gamemoderun" && !OURS.iter().any(|k| t.starts_with(k)))
        .collect();
    let mut ours = Vec::new();
    if reshade { ours.push("WINEDLLOVERRIDES=\"d3dcompiler_47=n;dxgi=n,b\"".to_string()); }
    if o.wayland { ours.push("PROTON_ENABLE_WAYLAND=1".into()); }
    if o.dxvk_hud { ours.push("DXVK_HUD=fps".into()); }
    if let Some(n) = o.frame_cap { ours.push(format!("DXVK_FRAME_RATE={n}")); }
    ours.append(&mut env);
    if o.gamemode { ours.push("gamemoderun".into()); }
    ours.push("%command%".into());
    // the launcher passes -malloc itself; a stale one here would override the toggle
    ours.extend(after.into_iter().filter(|t| !t.starts_with("-malloc=")));
    ours.join(" ")
}

/// First run: adopt what the player already had in Steam's launch options, so the manager's first
/// write does not silently drop their frame cap / Wayland / HUD / GameMode.
pub fn import_opts(existing: &str) -> LinuxOpts {
    let toks = tokens(existing);
    let before: Vec<&String> = toks.iter().take_while(|t| t.as_str() != "%command%").collect();
    LinuxOpts {
        gamemode: before.iter().any(|t| t.as_str() == "gamemoderun"),
        wayland: before.iter().any(|t| t.as_str() == "PROTON_ENABLE_WAYLAND=1"),
        dxvk_hud: before.iter().any(|t| t.starts_with("DXVK_HUD=")),
        frame_cap: before.iter().find_map(|t| t.strip_prefix("DXVK_FRAME_RATE=")?.parse().ok()),
    }
}

fn app_node<'a>(root: &'a vdf::Node, appid: &str) -> Option<&'a vdf::Node> {
    root.path(&["UserLocalConfigStore", "Software", "Valve", "Steam", "apps", appid])
}

pub fn current_launch_options(text: &str, appid: &str) -> Option<String> {
    let root = vdf::parse(text).ok()?;
    app_node(&root, appid)?.child("LaunchOptions")?.str().map(str::to_string)
}

pub fn set_launch_options(text: &str, appid: &str, value: &str) -> Result<String> {
    let root = vdf::parse(text)?;
    let app = app_node(&root, appid).with_context(|| format!("app {appid} not in localconfig"))?;
    if let Some(lo) = app.child("LaunchOptions") {
        if let Value::Str { span, .. } = &lo.value {
            return Ok(format!("{}{}{}", &text[..span.0], vdf::quote(value), &text[span.1..]));
        }
        bail!("LaunchOptions is not a string");
    }
    let Value::Obj { close, .. } = &app.value else { bail!("app {appid} is not an object") };
    let line_start = text[..*close].rfind('\n').map(|i| i + 1).unwrap_or(*close);
    let indent: String = text[line_start..*close].chars().take_while(|c| c.is_whitespace()).collect();
    let insert = format!("{indent}\t\"LaunchOptions\"\t\t{}\n", vdf::quote(value));
    Ok(format!("{}{}{}", &text[..line_start], insert, &text[line_start..]))
}

fn steam_running() -> bool {
    let mut s = sysinfo::System::new();
    s.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
    s.processes().values().any(|p| {
        let n = p.name().to_string_lossy();
        n == "steam" || n == "steamwebhelper"
    })
}

pub fn apply(localconfig: &Path, opts: &LinuxOpts, reshade: bool) -> Result<bool> {
    let text = std::fs::read_to_string(localconfig)?;
    let cur = current_launch_options(&text, "107410").unwrap_or_default();
    let want = managed_options(&cur, opts, reshade);
    if want == cur { return Ok(false); }
    if steam_running() { bail!("close Steam so the launcher can update Arma 3's launch options"); }
    let secs = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?.as_secs();
    std::fs::copy(localconfig, localconfig.with_extension(format!("vdf.apl-bak-{secs}")))?;
    let out = set_launch_options(&text, "107410", &want)?;
    let tmp = localconfig.with_extension("vdf.apl-tmp");
    std::fs::write(&tmp, out)?;
    std::fs::rename(tmp, localconfig)?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    const FX: &str = include_str!("../tests/fixtures/localconfig.vdf");

    #[test]
    fn managed_options_replace_ours_and_keep_the_rest() {
        let o = LinuxOpts { gamemode: true, wayland: false, dxvk_hud: true, frame_cap: None };
        let s = managed_options(" DXVK_HUD=fps,frametimes DXVK_FRAME_RATE=90 PROTON_ENABLE_WAYLAND=1 gamemoderun %command% -malloc=system -debug", &o, true);
        assert_eq!(s, "WINEDLLOVERRIDES=\"d3dcompiler_47=n;dxgi=n,b\" DXVK_HUD=fps gamemoderun %command% -debug");
        assert_eq!(managed_options("", &LinuxOpts::default(), false), "gamemoderun %command%");
    }

    #[test]
    fn import_keeps_the_players_existing_choices() {
        let o = import_opts(" DXVK_HUD=fps,frametimes DXVK_FRAME_RATE=90 PROTON_ENABLE_WAYLAND=1 gamemoderun %command% -malloc=system -debug");
        assert_eq!(o, LinuxOpts { gamemode: true, wayland: true, dxvk_hud: true, frame_cap: Some(90) });
        assert_eq!(import_opts("%command%"), LinuxOpts { gamemode: false, wayland: false, dxvk_hud: false, frame_cap: None });
    }

    #[test]
    fn edits_only_the_target_value() {
        let out = set_launch_options(FX, "107410", "NEW %command%").unwrap();
        assert_eq!(current_launch_options(&out, "107410").unwrap(), "NEW %command%");
        assert_eq!(current_launch_options(&out, "440").unwrap(), "-novid");
        assert_eq!(out.lines().count(), FX.lines().count());
        let q = set_launch_options(FX, "107410", "A=\"x\" %command%").unwrap();
        assert_eq!(current_launch_options(&q, "107410").unwrap(), "A=\"x\" %command%");
    }

    #[test]
    fn inserts_when_missing() {
        let no_lo = FX.replace("\t\t\t\t\t\t\"LaunchOptions\"\t\t\"-novid\"\n", "");
        let out = set_launch_options(&no_lo, "440", "X").unwrap();
        assert_eq!(current_launch_options(&out, "440").unwrap(), "X");
        assert!(set_launch_options(FX, "999", "X").is_err());
    }
    #[test]
    #[ignore]
    fn real_steam_files_parse() {
        let home = dirs::home_dir().unwrap();
        let f = crate::paths::find_linux(&home).unwrap();
        let text = std::fs::read_to_string(&f.localconfig).unwrap();
        let cur = current_launch_options(&text, "107410");
        println!("arma={} lo={:?}", f.arma_dir.display(), cur);
        assert!(cur.is_some());
    }
}
