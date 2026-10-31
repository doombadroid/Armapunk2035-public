//! Linux Steam / Arma 3 / Proton discovery (LAUNCHER_SPEC §1.1 `paths`).

use crate::vdf::{self, Value};
use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};

pub struct Found { pub steam_root: PathBuf, pub arma_dir: PathBuf, pub prefix: PathBuf, pub localconfig: PathBuf }

pub fn data_dir() -> PathBuf { dirs::data_dir().unwrap_or_else(|| PathBuf::from(".")).join("armapunk-launcher") }

pub fn proton_path(p: &Path) -> String { format!("Z:{}", p.to_string_lossy().replace('/', "\\")) }

pub fn arma_library(libraryfolders: &str) -> Option<PathBuf> {
    let root = vdf::parse(libraryfolders).ok()?;
    let lf = root.child("libraryfolders")?;
    let Value::Obj { children, .. } = &lf.value else { return None };
    children.iter().find(|lib| lib.path(&["apps", "107410"]).is_some())
        .and_then(|lib| lib.child("path")?.str().map(PathBuf::from))
}

pub fn active_account(loginusers: &str) -> Option<u64> {
    let root = vdf::parse(loginusers).ok()?;
    let Value::Obj { children, .. } = &root.child("users")?.value else { return None };
    // Older Steam marks the active user MostRecent=1; current Steam dropped that key and only keeps
    // Timestamp (last login), so fall back to the newest Timestamp.
    let ts = |u: &&vdf::Node| u.child("Timestamp").and_then(|t| t.str()).and_then(|t| t.parse::<u64>().ok()).unwrap_or(0);
    let user = children.iter().find(|u| u.child("MostRecent").and_then(|m| m.str()) == Some("1"))
        .or_else(|| children.iter().max_by_key(ts))?;
    let id64: u64 = user.key.parse().ok()?;
    id64.checked_sub(76561197960265728)
}

pub fn find_linux(home: &Path) -> Result<Found> {
    let candidates = [".local/share/Steam", ".steam/steam", ".var/app/com.valvesoftware.Steam/.local/share/Steam"];
    let steam_root = candidates.iter().map(|c| home.join(c))
        .find(|p| p.join("steamapps/libraryfolders.vdf").exists())
        .context("Steam not found")?;
    let lf = std::fs::read_to_string(steam_root.join("steamapps/libraryfolders.vdf"))?;
    let lib = arma_library(&lf).context("Arma 3 is not installed in any Steam library")?;
    let arma_dir = lib.join("steamapps/common/Arma 3");
    if !arma_dir.join("arma3_x64.exe").exists() { bail!("Arma 3 folder missing: {}", arma_dir.display()); }
    let prefix = lib.join("steamapps/compatdata/107410/pfx");
    let lu = std::fs::read_to_string(steam_root.join("config/loginusers.vdf")).context("no Steam login found")?;
    let acct = active_account(&lu).context("no most-recent Steam user")?;
    let localconfig = steam_root.join(format!("userdata/{acct}/config/localconfig.vdf"));
    Ok(Found { steam_root, arma_dir, prefix, localconfig })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn library_and_account() {
        assert_eq!(arma_library(include_str!("../tests/fixtures/libraryfolders.vdf")).unwrap(), PathBuf::from("/mnt/games/SteamLibrary"));
        assert_eq!(active_account(include_str!("../tests/fixtures/loginusers.vdf")).unwrap(), 76561197960265731 - 76561197960265728);
    }
    #[test]
    fn current_steam_format_has_no_most_recent_so_newest_timestamp_wins() {
        assert_eq!(active_account(include_str!("../tests/fixtures/loginusers_timestamp.vdf")).unwrap(), 3);
    }
    #[test]
    fn proton_path_maps_to_z() { assert_eq!(proton_path(Path::new("/home/u/x y/@M")), "Z:\\home\\u\\x y\\@M"); }
}
