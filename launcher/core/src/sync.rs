//! Content-addressed sync (LAUNCHER_SPEC §3.2).

use crate::manifest::FileEntry;
use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::io::{Read, Write};
use std::path::Path;

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct IndexEntry { pub size: u64, pub sha256: String }

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Index { pub files: BTreeMap<String, IndexEntry> }

impl Index {
    pub fn load(p: &Path) -> Index {
        std::fs::read(p).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default()
    }
    pub fn save(&self, p: &Path) -> Result<()> {
        let tmp = p.with_extension("json.tmp");
        std::fs::write(&tmp, serde_json::to_vec_pretty(self)?)?;
        std::fs::rename(tmp, p)?;
        Ok(())
    }
}

pub fn sha256_file(p: &Path) -> Result<String> {
    let mut f = std::fs::File::open(p)?;
    let mut h = Sha256::new();
    let mut buf = vec![0u8; 1 << 20];
    loop { let n = f.read(&mut buf)?; if n == 0 { break; } h.update(&buf[..n]); }
    Ok(hex::encode(h.finalize()))
}

/// Quick check: a file is current when the index agrees with the manifest and the on-disk size matches.
pub fn plan(wanted: &[FileEntry], root: &Path, index: &Index) -> (Vec<FileEntry>, Vec<String>) {
    let get = wanted.iter().filter(|f| {
        let ok_index = index.files.get(&f.path).map(|e| e.sha256 == f.sha256 && e.size == f.size).unwrap_or(false);
        let ok_disk = std::fs::metadata(root.join(&f.path)).map(|m| m.len() == f.size).unwrap_or(false);
        !(ok_index && ok_disk)
    }).cloned().collect();
    let prune = index.files.keys().filter(|p| !wanted.iter().any(|f| &f.path == *p)).cloned().collect();
    (get, prune)
}

pub fn fetch(client: &reqwest::blocking::Client, base_url: &str, f: &FileEntry, root: &Path, progress: &mut dyn FnMut(u64)) -> Result<()> {
    let dest = root.join(&f.path);
    if let Some(parent) = dest.parent() { std::fs::create_dir_all(parent)?; }
    let part = dest.with_file_name(format!("{}.part", dest.file_name().unwrap().to_string_lossy()));
    let url = format!("{}/blobs/{}", base_url.trim_end_matches('/'), f.sha256);
    for attempt in 0..3 {
        let have = std::fs::metadata(&part).map(|m| m.len()).unwrap_or(0);
        if have < f.size {
            let mut req = client.get(&url);
            if have > 0 { req = req.header(reqwest::header::RANGE, format!("bytes={have}-")); }
            let mut resp = req.send().with_context(|| format!("GET {url}"))?.error_for_status()?;
            let resumed = resp.status() == reqwest::StatusCode::PARTIAL_CONTENT;
            let mut out = std::fs::OpenOptions::new().create(true).write(true).append(resumed).truncate(!resumed).open(&part)?;
            let mut buf = vec![0u8; 1 << 16];
            loop {
                let n = match resp.read(&mut buf) { Ok(n) => n, Err(_) => break };
                if n == 0 { break; }
                out.write_all(&buf[..n])?;
                progress(n as u64);
            }
        }
        let have = std::fs::metadata(&part).map(|m| m.len()).unwrap_or(0);
        if have < f.size && attempt < 2 { continue; }
        if have == f.size && sha256_file(&part)? == f.sha256 {
            std::fs::rename(&part, &dest)?;
            return Ok(());
        }
        let _ = std::fs::remove_file(&part);
    }
    bail!("download failed or hash mismatch for {}", f.path)
}

fn available_space(root: &Path) -> Option<u64> {
    let disks = sysinfo::Disks::new_with_refreshed_list();
    let root = root.canonicalize().ok()?;
    disks.list().iter()
        .filter(|d| root.starts_with(d.mount_point()))
        .max_by_key(|d| d.mount_point().as_os_str().len())
        .map(|d| d.available_space())
}

pub fn sync_all(base_url: &str, wanted: &[FileEntry], root: &Path, progress: &mut dyn FnMut(&str, u64, u64)) -> Result<()> {
    std::fs::create_dir_all(root)?;
    let index_path = root.join(".apl-index.json");
    let mut index = Index::load(&index_path);
    let (get, prune) = plan(wanted, root, &index);
    let need: u64 = get.iter().map(|f| f.size).sum();
    if let Some(free) = available_space(root) {
        if free < need + need / 10 { bail!("not enough disk space: need {} MB, have {} MB", (need + need / 10) >> 20, free >> 20); }
    }
    let client = reqwest::blocking::Client::builder().timeout(std::time::Duration::from_secs(600)).build()?;
    let (total, mut done) = (need, 0u64);
    for f in &get {
        fetch(&client, base_url, f, root, &mut |n| { done += n; progress(&f.path, done, total); })?;
        index.files.insert(f.path.clone(), IndexEntry { size: f.size, sha256: f.sha256.clone() });
        index.save(&index_path)?;
    }
    for p in &prune {
        let _ = std::fs::remove_file(root.join(p));
        index.files.remove(p);
    }
    index.save(&index_path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;

    fn serve(blobs: Vec<(String, Vec<u8>)>, fail_first: bool) -> (String, std::thread::JoinHandle<()>) {
        let server = tiny_http::Server::http("127.0.0.1:0").unwrap();
        let url = format!("http://{}", server.server_addr().to_ip().unwrap());
        let h = std::thread::spawn(move || {
            let mut failed = !fail_first;
            for req in server.incoming_requests() {
                let name = req.url().trim_start_matches("/blobs/").to_string();
                let Some((_, data)) = blobs.iter().find(|(h, _)| *h == name) else { let _ = req.respond(tiny_http::Response::empty(404)); continue };
                let from = req.headers().iter().find(|h| h.field.equiv("Range"))
                    .and_then(|h| h.value.as_str().strip_prefix("bytes=")?.trim_end_matches('-').parse::<usize>().ok()).unwrap_or(0);
                let mut body = data[from..].to_vec();
                if !failed { body.truncate(body.len() / 2); failed = true; }
                let code = if from > 0 { 206 } else { 200 };
                let _ = req.respond(tiny_http::Response::from_data(body).with_status_code(code));
            }
        });
        (url, h)
    }
    fn entry(path: &str, data: &[u8]) -> FileEntry {
        FileEntry { set: "mod".into(), os: "all".into(), path: path.into(), size: data.len() as u64, sha256: hex::encode(sha2::Sha256::digest(data)) }
    }

    #[test]
    fn plan_downloads_missing_and_prunes_stale() {
        let d = tempfile::tempdir().unwrap();
        let a = entry("x/a.bin", b"hello");
        let mut idx = Index::default();
        idx.files.insert("old.bin".into(), IndexEntry { size: 1, sha256: "00".into() });
        let (get, prune) = plan(&[a.clone()], d.path(), &idx);
        assert_eq!(get, vec![a]);
        assert_eq!(prune, vec!["old.bin".to_string()]);
    }

    #[test]
    fn fetch_resumes_after_truncated_response_and_verifies() {
        let d = tempfile::tempdir().unwrap();
        let data = vec![7u8; 100_000];
        let a = entry("big.bin", &data);
        let (url, _h) = serve(vec![(a.sha256.clone(), data.clone())], true);
        let client = reqwest::blocking::Client::new();
        let mut seen = 0;
        fetch(&client, &url, &a, d.path(), &mut |n| seen += n).unwrap();
        let mut got = Vec::new();
        std::fs::File::open(d.path().join("big.bin")).unwrap().read_to_end(&mut got).unwrap();
        assert_eq!(got, data);
        assert!(!d.path().join("big.bin.part").exists());
    }

    #[test]
    fn fetch_rejects_wrong_hash() {
        let d = tempfile::tempdir().unwrap();
        let mut a = entry("f.bin", b"good");
        let (url, _h) = serve(vec![(a.sha256.clone(), b"evil".to_vec())], false);
        a.size = 4;
        assert!(fetch(&reqwest::blocking::Client::new(), &url, &a, d.path(), &mut |_| {}).is_err());
        assert!(!d.path().join("f.bin").exists());
    }

    #[test]
    fn sync_all_writes_index_and_prunes() {
        let d = tempfile::tempdir().unwrap();
        std::fs::write(d.path().join("old.bin"), b"x").unwrap();
        let mut idx = Index::default();
        idx.files.insert("old.bin".into(), IndexEntry { size: 1, sha256: "00".into() });
        idx.save(&d.path().join(".apl-index.json")).unwrap();
        let a = entry("a.bin", b"abc");
        let (url, _h) = serve(vec![(a.sha256.clone(), b"abc".to_vec())], false);
        sync_all(&url, &[a.clone()], d.path(), &mut |_, _, _| {}).unwrap();
        assert!(!d.path().join("old.bin").exists());
        let idx = Index::load(&d.path().join(".apl-index.json"));
        assert_eq!(idx.files.get("a.bin").unwrap().sha256, a.sha256);
    }
}
