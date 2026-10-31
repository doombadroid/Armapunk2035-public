//! Per-session install into the Arma folder (LAUNCHER_SPEC §1.5).

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub enum Source { File(PathBuf), Bytes(Vec<u8>) }
pub struct Placement { pub rel: String, pub source: Source }

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct SessionRecord {
    pub game_dir: PathBuf,
    pub placed: Vec<String>,
    pub created_dirs: Vec<String>,
    pub backups: Vec<String>,
    pub byproducts: Vec<String>,
}

fn record_path(data_dir: &Path) -> PathBuf { data_dir.join("session.json") }

fn save(data_dir: &Path, r: &SessionRecord) -> Result<()> {
    std::fs::create_dir_all(data_dir)?;
    let tmp = data_dir.join("session.json.tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(r)?)?;
    std::fs::rename(tmp, record_path(data_dir))?;
    Ok(())
}

pub fn begin(game_dir: &Path, data_dir: &Path, items: &[Placement], byproducts: &[&str]) -> Result<SessionRecord> {
    end(data_dir)?; // clean any leftover session first
    let mut r = SessionRecord { game_dir: game_dir.to_path_buf(), ..Default::default() };
    r.byproducts = byproducts.iter().filter(|b| !game_dir.join(b).exists()).map(|b| b.to_string()).collect();
    save(data_dir, &r)?;
    for it in items {
        let dest = game_dir.join(&it.rel);
        // record every directory we are about to create, outermost first
        let mut missing = Vec::new();
        let mut p = dest.parent();
        while let Some(dir) = p {
            if dir == game_dir || dir.exists() { break; }
            missing.push(dir.strip_prefix(game_dir)?.to_string_lossy().replace('\\', "/"));
            p = dir.parent();
        }
        for d in missing.into_iter().rev() {
            if !r.created_dirs.iter().any(|c| d.starts_with(&format!("{c}/")) || *c == d) { r.created_dirs.push(d); }
        }
        if dest.exists() {
            let bak = data_dir.join("backup").join(&it.rel);
            std::fs::create_dir_all(bak.parent().unwrap())?;
            r.backups.push(it.rel.clone());
            save(data_dir, &r)?;
            std::fs::rename(&dest, &bak)?;
        }
        r.placed.push(it.rel.clone());
        save(data_dir, &r)?;
        std::fs::create_dir_all(dest.parent().unwrap())?;
        match &it.source {
            Source::File(src) => { std::fs::copy(src, &dest)?; }
            Source::Bytes(b) => { std::fs::write(&dest, b)?; }
        }
    }
    Ok(r)
}

pub fn end(data_dir: &Path) -> Result<bool> {
    let Ok(bytes) = std::fs::read(record_path(data_dir)) else { return Ok(false) };
    let r: SessionRecord = serde_json::from_slice(&bytes)?;
    let g = &r.game_dir;
    for rel in r.placed.iter().chain(r.byproducts.iter()) { let _ = std::fs::remove_file(g.join(rel)); }
    for d in r.created_dirs.iter().rev() { let _ = std::fs::remove_dir_all(g.join(d)); }
    for rel in &r.backups {
        let bak = data_dir.join("backup").join(rel);
        if bak.exists() { std::fs::rename(&bak, g.join(rel))?; }
    }
    let _ = std::fs::remove_dir_all(data_dir.join("backup"));
    std::fs::remove_file(record_path(data_dir))?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    fn snapshot(dir: &Path) -> BTreeMap<String, Vec<u8>> {
        let mut m = BTreeMap::new();
        fn walk(base: &Path, d: &Path, m: &mut BTreeMap<String, Vec<u8>>) {
            for e in std::fs::read_dir(d).unwrap() {
                let p = e.unwrap().path();
                let rel = p.strip_prefix(base).unwrap().to_string_lossy().to_string();
                if p.is_dir() { m.insert(rel + "/", vec![]); walk(base, &p, m); } else { m.insert(rel, std::fs::read(&p).unwrap()); }
            }
        }
        walk(dir, dir, &mut m);
        m
    }

    fn setup() -> (tempfile::TempDir, tempfile::TempDir) {
        let game = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(game.path().join("Dll")).unwrap();
        std::fs::write(game.path().join("Dll/tbb4malloc_bi_x64.dll"), b"bi").unwrap();
        std::fs::write(game.path().join("dxgi.dll"), b"players-own-reshade").unwrap();
        std::fs::write(game.path().join("arma3_x64.exe"), b"exe").unwrap();
        (game, tempfile::tempdir().unwrap())
    }
    fn items() -> Vec<Placement> {
        vec![
            Placement { rel: "Dll/mimalloc_ap.dll".into(), source: Source::Bytes(b"mi".to_vec()) },
            Placement { rel: "dxgi.dll".into(), source: Source::Bytes(b"reshade".to_vec()) },
            Placement { rel: "reshade-shaders/Shaders/iMMERSE/a.fx".into(), source: Source::Bytes(b"fx".to_vec()) },
        ]
    }

    #[test]
    fn begin_then_end_restores_byte_identical() {
        let (game, data) = setup();
        let before = snapshot(game.path());
        begin(game.path(), data.path(), &items(), &["ReShade.log"]).unwrap();
        assert_eq!(std::fs::read(game.path().join("dxgi.dll")).unwrap(), b"reshade");
        std::fs::write(game.path().join("ReShade.log"), b"log").unwrap();
        std::fs::write(game.path().join("reshade-shaders/cache.bin"), b"c").unwrap();
        assert!(end(data.path()).unwrap());
        assert_eq!(snapshot(game.path()), before);
        assert!(!end(data.path()).unwrap());
    }

    #[test]
    fn preexisting_byproduct_is_left_alone() {
        let (game, data) = setup();
        std::fs::write(game.path().join("ReShade.log"), b"theirs").unwrap();
        begin(game.path(), data.path(), &items(), &["ReShade.log"]).unwrap();
        end(data.path()).unwrap();
        assert_eq!(std::fs::read(game.path().join("ReShade.log")).unwrap(), b"theirs");
    }

    #[test]
    fn crash_recovery_from_record_alone() {
        let (game, data) = setup();
        let before = snapshot(game.path());
        begin(game.path(), data.path(), &items(), &[]).unwrap();
        // simulate a launcher crash: only the record on disk survives
        assert!(end(data.path()).unwrap());
        assert_eq!(snapshot(game.path()), before);
    }
}
