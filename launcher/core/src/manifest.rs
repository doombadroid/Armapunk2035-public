//! Release manifest: schema, signature, path safety (LAUNCHER_SPEC §3.1, §1.6).

use crate::Os;
use anyhow::{anyhow, bail, Result};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Server { pub name: String, pub host: String, pub port: u16 }

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FileEntry { pub set: String, pub os: String, pub path: String, pub size: u64, pub sha256: String }

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Preset { pub id: String, pub name: String, pub path: String }

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Manifest {
    pub schema: u32,
    pub channel: String,
    pub release: String,
    pub min_launcher: String,
    pub server: Server,
    pub files: Vec<FileEntry>,
    #[serde(default)]
    pub presets: Vec<Preset>,
}

pub fn safe_path(p: &str) -> bool {
    !p.is_empty()
        && !p.starts_with('/')
        && !p.contains('\\')
        && !p.contains(':')
        && p.split('/').all(|seg| !seg.is_empty() && seg != ".." && seg != ".")
}

pub fn compiled_keys() -> Vec<[u8; 32]> {
    include_str!("../pubkeys.txt")
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .filter_map(|l| hex::decode(l).ok()?.try_into().ok())
        .collect()
}

pub fn verify(manifest_bytes: &[u8], sig_bytes: &[u8], keys: &[[u8; 32]]) -> Result<Manifest> {
    let sig = Signature::from_slice(sig_bytes).map_err(|_| anyhow!("malformed signature"))?;
    let ok = keys.iter().any(|k| {
        VerifyingKey::from_bytes(k).map(|vk| vk.verify(manifest_bytes, &sig).is_ok()).unwrap_or(false)
    });
    if !ok { bail!("manifest signature does not verify against any trusted key"); }
    let m: Manifest = serde_json::from_slice(manifest_bytes)?;
    if m.schema != 1 { bail!("unsupported manifest schema {}", m.schema); }
    for f in &m.files {
        if !safe_path(&f.path) { bail!("unsafe path in manifest: {:?}", f.path); }
        if !matches!(f.os.as_str(), "all" | "windows" | "linux") { bail!("bad os {:?}", f.os); }
        if f.sha256.len() != 64 || !f.sha256.bytes().all(|b| b.is_ascii_hexdigit()) { bail!("bad sha256 for {}", f.path); }
    }
    for p in &m.presets { if !safe_path(&p.path) { bail!("unsafe preset path {:?}", p.path); } }
    Ok(m)
}

impl Manifest {
    pub fn select(&self, os: Os, sets: &[String]) -> Vec<FileEntry> {
        self.files
            .iter()
            .filter(|f| sets.iter().any(|s| s == &f.set) && (f.os == "all" || f.os == os.tag()))
            .cloned()
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};

    fn sample() -> Vec<u8> {
        br#"{"schema":1,"channel":"test","release":"r1","min_launcher":"0.1.0",
             "server":{"name":"Armapunk 2035","host":"10.1.24.96","port":2302},
             "files":[{"set":"mod","os":"all","path":"@Armapunk2035/addons/a.pbo","size":3,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
                      {"set":"dxvk","os":"windows","path":"d3d11.dll","size":1,"sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
                      {"set":"d3dcompiler","os":"linux","path":"d3dcompiler_47.dll","size":1,"sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}],
             "presets":[{"id":"armapunk-neon","name":"Armapunk Neon","path":"reshade-presets/armapunk-neon.ini"}]}"#.to_vec()
    }
    fn key(n: u8) -> SigningKey { SigningKey::from_bytes(&[n; 32]) }

    #[test]
    fn good_signature_parses_and_selects() {
        let m = sample();
        let sig = key(1).sign(&m).to_bytes();
        let man = verify(&m, &sig, &[key(1).verifying_key().to_bytes()]).unwrap();
        assert_eq!(man.server.port, 2302);
        let sel = man.select(Os::Linux, &["mod".into(), "dxvk".into(), "d3dcompiler".into()]);
        let paths: Vec<_> = sel.iter().map(|f| f.path.as_str()).collect();
        assert_eq!(paths, vec!["@Armapunk2035/addons/a.pbo", "d3dcompiler_47.dll"]);
    }

    #[test]
    fn second_key_slot_accepted() {
        let m = sample();
        let sig = key(2).sign(&m).to_bytes();
        assert!(verify(&m, &sig, &[key(1).verifying_key().to_bytes(), key(2).verifying_key().to_bytes()]).is_ok());
    }

    #[test]
    fn tampered_or_wrong_key_rejected() {
        let mut m = sample();
        let sig = key(1).sign(&m).to_bytes();
        assert!(verify(&m, &sig, &[key(3).verifying_key().to_bytes()]).is_err());
        m[10] ^= 1;
        assert!(verify(&m, &sig, &[key(1).verifying_key().to_bytes()]).is_err());
    }

    #[test]
    fn unsafe_paths_rejected() {
        for p in ["../x", "/etc/x", "C:/x", "a\\b", "a/../b", "", "a//b"] { assert!(!safe_path(p), "{p}"); }
        assert!(safe_path("reshade-shaders/Shaders/iMMERSE/MartysMods_MXAO.fx"));
        let m = String::from_utf8(sample()).unwrap().replace("d3d11.dll", "../d3d11.dll").into_bytes();
        let sig = key(1).sign(&m).to_bytes();
        assert!(verify(&m, &sig, &[key(1).verifying_key().to_bytes()]).is_err());
    }
}
