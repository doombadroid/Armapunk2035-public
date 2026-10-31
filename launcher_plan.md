# Armapunk Launcher M0+M1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Linux build of the Armapunk launcher that syncs `@Armapunk2035` plus the session file sets from a signed manifest, launches Arma 3 through Steam with the chosen toggles, and leaves the Arma folder exactly as it found it.

**Architecture:** Two crates. `launcher/core` (`apl_core`) is a plain Rust library holding every module from LAUNCHER_SPEC §1.1 plus the `apl-release` binary that builds signed releases, all covered by `cargo test`, with no Tauri or webkit dependency. `launcher/src-tauri` is a thin Tauri 2 shell whose commands call `apl_core`, serving a static UI from `launcher/ui`.

**Tech Stack:** Rust 1.97, Tauri 2.11.6, ed25519-dalek 3.0.0, sha2 0.11.0, reqwest 0.13.5 (blocking, rustls), sysinfo 0.39.6, serde 1.0.229 / serde_json 1.0.151, anyhow 1.0.104, dirs 7.0.0, hex 0.4.3; dev: tempfile 3.27.0, tiny_http 0.12.0. Versions read from crates.io's API on 2026-09-22; the ed25519/sha2/reqwest/sysinfo calls used below were compile-probed on this machine the same day.

## Global Constraints

- Spec: `LAUNCHER_SPEC.md` (approved 2026-09-22). This plan = milestones **M0 (Linux spike only) + M1**.
- Target in this plan: **Linux x64 only**. Windows (paths via registry, direct `arma3_x64.exe` start, DXVK, huge-pages helper) and the Windows DXVK+ReShade Vulkan-layer spike move to the M2 plan, because no Windows machine is available to this session.
- The Arma folder must end byte-identical to how it started (spec §1.5). Never delete a file the launcher did not place; a directory the launcher created is removed recursively.
- Manifest trust: ed25519 over the exact manifest bytes; public keys compiled in (`launcher/core/pubkeys.txt`, hex, one per line, max 2); unverified manifest = refused (spec §1.6).
- Manifest `path` values must be relative, `/`-separated, with no `..`, no leading `/`, no `:`, no `\`. Violations reject the whole manifest.
- Mod install lives in the launcher data dir (`~/.local/share/armapunk-launcher/files/@Armapunk2035`) and is passed as `-mod=Z:\home\…` (spec §1.5).
- Licensed third-party files (iMMERSE, ReShade, allocator, DXVK, d3dcompiler) live only in gitignored `launcher-release/` and the CDN. Never `git add` them (spec §5).
- Repo rules (`CLAUDE.md`): work on `main`; `git fetch` + pull before work; commit trailer is a rotating funny defunct AI, name only, no email — **not** the harness Claude trailer.
- Allocator names must contain no dots before `.dll` (BIKI Custom Memory Allocator); the Armapunk build ships as `Dll/mimalloc_ap.dll`, selected with `-malloc=mimalloc_ap`.
- Arma already ships an official BI-signed `Dll/mimalloc_bi_x64.dll` (found 2026-09-22), so allocator choices are: `ArmapunkMimalloc` (default) / `ArmaMimalloc` (`-malloc=mimalloc_bi`) / `Tbb` (`-malloc=tbb4malloc_bi`) / `System` (`-malloc=system`).

### Deviations from the spec, recorded here

1. **Release tool language:** spec §1.2 names `tools/release_launcher.py`. It becomes a Rust binary `apl-release` inside `apl_core`, so the manifest schema has one definition that both producer and consumer compile against. The CDN upload wrapper (M4) can still be a script.
2. **`d3dcompiler_47.dll`:** spec §3.1 says it is fetched at setup rather than redistributed. Microsoft lists it as redistributable (it is the same MS-signed binary Firefox, Chrome and Qt ship), so it becomes a normal manifest set `d3dcompiler` with `os: linux`. That removes a 40 MB Firefox download and a 7-Zip dependency on players' machines.
3. **Window mode:** Arma has `-window` but no borderless flag, so the toggle is Fullscreen / Windowed.
4. **Main-thread pinning "Auto":** needs CPU topology detection. M1 offers Off / manual mask; Auto lands in M3.

---

## File structure

```
launcher/
  core/                         apl_core library + apl-release binary
    Cargo.toml
    pubkeys.txt                 compiled-in manifest public keys (hex)
    src/lib.rs                  module list, Os
    src/vdf.rs                  Steam KeyValues text parser with byte spans
    src/manifest.rs             schema, path validation, signature verify, set selection
    src/sync.rs                 local index, diff, resumable download, prune
    src/session.rs              per-session place/cleanup with crash-safe record
    src/profile.rs              toggles -> LaunchPlan (args, sets, generated files)
    src/paths.rs                Linux Steam/Arma/Proton/user-config discovery
    src/steamcfg.rs             Linux launch-option manager (localconfig.vdf edit)
    src/launch.rs               Runner trait, Linux Steam runner, process wait
    src/orchestrate.rs          recover -> place -> launch -> wait -> cleanup
    src/bin/apl-release.rs      keygen + build signed release from staging
    tests/fixtures/             sample VDF files
  src-tauri/                    Tauri shell
    Cargo.toml  build.rs  tauri.conf.json  capabilities/default.json  icons/icon.png
    src/main.rs                 commands: get_state, set_toggles, sync, launch, repair
  ui/                           index.html  style.css  app.js
  spikes/linux_launch.md        M0 spike record
```

---

### Task 1: M0 spike — Linux launch through Steam and process identity

Proves the two unknowns the Linux runner depends on: (a) `steam -applaunch 107410 -noLauncher -mod=<Z:\ absolute path outside the game folder>` loads that mod; (b) what the Arma process looks like under Proton so `is_running` can match it. The manual launch on 2026-09-22 proved `-noLauncher -mod=@Armapunk2035` with a game-folder-relative path only.

**Files:**
- Create: `launcher/spikes/linux_launch.md`

- [ ] **Step 1: Stage a copy of the mod outside the game folder**

```bash
mkdir -p ~/.local/share/armapunk-launcher/files
cp -r ~/Armapunk2035/radio/dist/@Armapunk2035 ~/.local/share/armapunk-launcher/files/
ls ~/.local/share/armapunk-launcher/files/@Armapunk2035/addons | grep -c pbo
```
Expected: `13`

- [ ] **Step 2: Observe the red state — nothing matches before launch**

```bash
ps -eo pid,comm,args | grep -i "arma3_x64" | grep -v grep ; echo "exit=$?"
```
Expected: no lines, `exit=1`.

- [ ] **Step 3: Launch through Steam with the absolute Proton path and record the process**

```bash
setsid -f steam -applaunch 107410 -noLauncher "-mod=Z:\\home\\timb\\.local\\share\\armapunk-launcher\\files\\@Armapunk2035" -skipIntro -noSplash -world=empty >/dev/null 2>&1
for i in $(seq 1 60); do ps -eo pid,comm,args | grep -i "arma3_x64" | grep -v grep && break; sleep 3; done
```
Expected: at least one line. Record the exact `comm` value and whether `args` contains `Arma3_x64.exe`.

- [ ] **Step 4: Confirm the mod loaded from the absolute path**

```bash
R=$(ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1)
grep -iE "Command line|armapunk-launcher.*ap_vcity" "$R" | head -3
```
Expected: the command line shows the `Z:\home\timb\.local\share\armapunk-launcher\...` mod path and an `ap_vcity.pbo` line from that folder. If the RPT shows the mod missing, the fallback is a symlink `@Armapunk2035` in the game folder placed as a session file; record which one worked.

- [ ] **Step 5: Quit Arma from its menu, then confirm the matcher goes back to empty**

```bash
for i in $(seq 1 40); do ps -eo comm,args | grep -i "arma3_x64" | grep -v grep || break; sleep 3; done; echo "gone"
```
Expected: `gone`.

- [ ] **Step 6: Write the record and commit**

Write `launcher/spikes/linux_launch.md` with: the date, the exact command from Step 3, the `comm`/`args` observed, the RPT lines from Step 4, and the chosen match rule (e.g. "process `args` contains `arma3_x64.exe`, case-insensitive"). Task 8's `is_arma` must implement exactly that rule.

```bash
cd ~/Armapunk2035 && git add launcher/spikes/linux_launch.md && git commit -m "launcher: M0 Linux launch spike record

Co-Authored-By: Clippy"
```

---

### Task 2: Crate scaffold, `Os`, and the VDF parser

**Files:**
- Create: `launcher/core/Cargo.toml`, `launcher/core/pubkeys.txt`, `launcher/core/src/lib.rs`, `launcher/core/src/vdf.rs`
- Modify: `.gitignore` (add `launcher/core/target/`, `launcher/src-tauri/target/`)

**Interfaces:**
- Produces: `apl_core::Os { Windows, Linux }` with `Os::current()` and `Os::tag(&self) -> &'static str` (`"windows"`/`"linux"`).
- Produces: `apl_core::vdf::{parse(text:&str) -> anyhow::Result<Node>, Node, Value}`; `Node { key: String, key_span: (usize,usize), value: Value }`; `Value::Str { text: String, span: (usize,usize) }` (span covers the quoted token) | `Value::Obj { children: Vec<Node>, open: usize, close: usize }` (byte offsets of `{` and `}`); `Node::child(&self, key) -> Option<&Node>` case-insensitive; `Node::path(&self, keys:&[&str]) -> Option<&Node>`; `vdf::quote(s:&str) -> String` (escapes `\` and `"`).

- [ ] **Step 1: Write `Cargo.toml`, `pubkeys.txt`, `lib.rs` and a failing VDF test**

`launcher/core/Cargo.toml`:
```toml
[package]
name = "apl_core"
version = "0.1.0"
edition = "2021"

[dependencies]
anyhow = "1.0.104"
dirs = "7.0.0"
ed25519-dalek = { version = "3.0.0", features = ["rand_core"] }
hex = "0.4.3"
reqwest = { version = "0.13.5", default-features = false, features = ["blocking", "rustls"] }
serde = { version = "1.0.229", features = ["derive"] }
serde_json = "1.0.151"
sha2 = "0.11.0"
sysinfo = "0.39.6"

[dev-dependencies]
tempfile = "3.27.0"
tiny_http = "0.12.0"
```

`launcher/core/pubkeys.txt` (filled by Task 9's keygen; one hex key per line):
```
```

`launcher/core/src/lib.rs`:
```rust
//! Armapunk launcher core. See LAUNCHER_SPEC.md; every module is usable without Tauri.
pub mod vdf;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Os { Windows, Linux }

impl Os {
    pub fn current() -> Os { if cfg!(windows) { Os::Windows } else { Os::Linux } }
    pub fn tag(&self) -> &'static str { match self { Os::Windows => "windows", Os::Linux => "linux" } }
}
```

`launcher/core/src/vdf.rs` (test first; implementation in Step 3):
```rust
//! Steam KeyValues (text VDF) parser that keeps byte spans, so callers can
//! edit one value in place without reformatting the rest of the file.

#[cfg(test)]
mod tests {
    use super::*;
    const SAMPLE: &str = "\"Root\"\n{\n\t\"Apps\"\n\t{\n\t\t\"107410\"\n\t\t{\n\t\t\t\"LaunchOptions\"\t\t\"a \\\"q\\\" %command%\"\n\t\t}\n\t}\n\t\"x\"\t\"1\"\n}\n";

    #[test]
    fn finds_nested_value_case_insensitive_with_spans() {
        let root = parse(SAMPLE).unwrap();
        let lo = root.path(&["apps", "107410", "launchoptions"]).unwrap();
        match &lo.value {
            Value::Str { text, span } => {
                assert_eq!(text, "a \"q\" %command%");
                assert_eq!(&SAMPLE[span.0..span.1], "\"a \\\"q\\\" %command%\"");
            }
            _ => panic!("expected string"),
        }
        let app = root.path(&["Apps", "107410"]).unwrap();
        match &app.value { Value::Obj { close, .. } => assert_eq!(&SAMPLE[*close..*close + 1], "}"), _ => panic!() }
    }

    #[test]
    fn quote_escapes() { assert_eq!(quote("a\"b\\c"), "\"a\\\"b\\\\c\""); }

    #[test]
    fn rejects_unbalanced() { assert!(parse("\"a\" { \"b\" \"c\"").is_err()); }
}
```

- [ ] **Step 2: Run the test and observe it fail**

Run: `cd ~/Armapunk2035/launcher/core && cargo test vdf 2>&1 | tail -5`
Expected: compile error `cannot find function 'parse' in this scope`.

- [ ] **Step 3: Implement the parser above the test module**

```rust
use anyhow::{bail, Result};

#[derive(Debug, Clone)]
pub enum Value {
    Str { text: String, span: (usize, usize) },
    Obj { children: Vec<Node>, open: usize, close: usize },
}

#[derive(Debug, Clone)]
pub struct Node { pub key: String, pub key_span: (usize, usize), pub value: Value }

impl Node {
    pub fn child(&self, key: &str) -> Option<&Node> {
        match &self.value {
            Value::Obj { children, .. } => children.iter().find(|c| c.key.eq_ignore_ascii_case(key)),
            _ => None,
        }
    }
    pub fn path(&self, keys: &[&str]) -> Option<&Node> {
        let mut n = self;
        for k in keys { n = n.child(k)?; }
        Some(n)
    }
    pub fn str(&self) -> Option<&str> { if let Value::Str { text, .. } = &self.value { Some(text) } else { None } }
}

pub fn quote(s: &str) -> String { format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\"")) }

enum Tok { Str(String, usize, usize), Open(usize), Close(usize) }

fn lex(t: &str) -> Result<Vec<Tok>> {
    let b = t.as_bytes();
    let (mut i, mut out) = (0usize, Vec::new());
    while i < b.len() {
        match b[i] {
            b' ' | b'\t' | b'\r' | b'\n' => i += 1,
            b'/' if b.get(i + 1) == Some(&b'/') => { while i < b.len() && b[i] != b'\n' { i += 1; } }
            b'{' => { out.push(Tok::Open(i)); i += 1; }
            b'}' => { out.push(Tok::Close(i)); i += 1; }
            b'"' => {
                let start = i;
                i += 1;
                let mut s = String::new();
                loop {
                    if i >= b.len() { bail!("unterminated string at byte {start}"); }
                    match b[i] {
                        b'\\' if i + 1 < b.len() => {
                            match b[i + 1] { b'n' => s.push('\n'), b't' => s.push('\t'), c => s.push(c as char) }
                            i += 2;
                        }
                        b'"' => { i += 1; break; }
                        _ => {
                            let ch = t[i..].chars().next().unwrap();
                            s.push(ch);
                            i += ch.len_utf8();
                        }
                    }
                }
                out.push(Tok::Str(s, start, i));
            }
            _ => bail!("unexpected byte {:?} at {i}", b[i] as char),
        }
    }
    Ok(out)
}

fn items(toks: &[Tok], pos: &mut usize, closing: bool) -> Result<(Vec<Node>, Option<usize>)> {
    let mut out = Vec::new();
    while *pos < toks.len() {
        match &toks[*pos] {
            Tok::Close(at) => { if !closing { bail!("unexpected '}}' at {at}"); } *pos += 1; return Ok((out, Some(*at))); }
            Tok::Open(at) => bail!("'{{' without key at {at}"),
            Tok::Str(k, ks, ke) => {
                let (key, key_span) = (k.clone(), (*ks, *ke));
                *pos += 1;
                let value = match toks.get(*pos) {
                    Some(Tok::Str(v, vs, ve)) => { *pos += 1; Value::Str { text: v.clone(), span: (*vs, *ve) } }
                    Some(Tok::Open(o)) => {
                        let open = *o;
                        *pos += 1;
                        let (children, close) = items(toks, pos, true)?;
                        Value::Obj { children, open, close: close.unwrap() }
                    }
                    _ => bail!("key {key:?} has no value"),
                };
                out.push(Node { key, key_span, value });
            }
        }
    }
    if closing { bail!("missing '}}'"); }
    Ok((out, None))
}

/// Parses a whole file into a synthetic root node (key "", object spanning the file).
pub fn parse(text: &str) -> Result<Node> {
    let toks = lex(text)?;
    let mut pos = 0;
    let (children, _) = items(&toks, &mut pos, false)?;
    Ok(Node { key: String::new(), key_span: (0, 0), value: Value::Obj { children, open: 0, close: text.len() } })
}
```

- [ ] **Step 4: Run and pass**

Run: `cargo test vdf 2>&1 | tail -3`
Expected: `test result: ok. 3 passed`

- [ ] **Step 5: Ignore build dirs and commit**

Append to `.gitignore`:
```
launcher/core/target/
launcher/src-tauri/target/
```
```bash
cd ~/Armapunk2035 && git add .gitignore launcher/core && git commit -m "launcher: core crate scaffold + span-keeping VDF parser

Co-Authored-By: Microsoft Merlin"
```

---

### Task 3: Manifest schema, path validation, signature verification

**Files:**
- Create: `launcher/core/src/manifest.rs`
- Modify: `launcher/core/src/lib.rs` (add `pub mod manifest;`)

**Interfaces:**
- Consumes: `Os` (Task 2).
- Produces:
  - `Manifest { schema: u32, channel: String, release: String, min_launcher: String, server: Server, files: Vec<FileEntry>, presets: Vec<Preset> }`
  - `Server { name: String, host: String, port: u16 }`
  - `FileEntry { set: String, os: String, path: String, size: u64, sha256: String }`
  - `Preset { id: String, name: String, path: String }`
  - `pub fn verify(manifest_bytes:&[u8], sig_bytes:&[u8], keys:&[[u8;32]]) -> anyhow::Result<Manifest>`
  - `pub fn compiled_keys() -> Vec<[u8;32]>` (parses `pubkeys.txt` via `include_str!`)
  - `impl Manifest { pub fn select(&self, os: Os, sets:&[String]) -> Vec<FileEntry> }` (entries whose `set` is listed and `os` is `"all"` or `os.tag()`)
  - `pub fn safe_path(p:&str) -> bool`

- [ ] **Step 1: Write failing tests**

```rust
//! Release manifest: schema, signature, path safety (LAUNCHER_SPEC §3.1, §1.6).

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
```

- [ ] **Step 2: Observe failure**

Add `pub mod manifest;` to `lib.rs`. Run: `cargo test manifest 2>&1 | tail -5`
Expected: compile error `cannot find function 'verify'`.

- [ ] **Step 3: Implement above the tests**

```rust
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
```

- [ ] **Step 4: Pass**

Run: `cargo test manifest 2>&1 | tail -3`
Expected: `test result: ok. 4 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: signed manifest schema with path safety

Co-Authored-By: Rover the Search Dog"
```

---

### Task 4: Sync — local index, resumable download, verify, prune

**Files:**
- Create: `launcher/core/src/sync.rs`
- Modify: `launcher/core/src/lib.rs` (add `pub mod sync;`)

**Interfaces:**
- Consumes: `FileEntry` (Task 3).
- Produces:
  - `Index { files: BTreeMap<String, IndexEntry> }` with `IndexEntry { size: u64, sha256: String }`; `Index::load(path) -> Index` (empty if missing), `Index::save(&self, path) -> Result<()>`
  - `pub fn plan(wanted:&[FileEntry], root:&Path, index:&Index) -> (Vec<FileEntry>, Vec<String>)` → (to download, paths to prune)
  - `pub fn fetch(client:&reqwest::blocking::Client, base_url:&str, f:&FileEntry, root:&Path, progress:&mut dyn FnMut(u64)) -> Result<()>` (downloads `base_url/blobs/<sha256>` to `root/path`, resuming a `.part`, verifying size+SHA-256, atomic rename)
  - `pub fn sync_all(base_url:&str, wanted:&[FileEntry], root:&Path, progress:&mut dyn FnMut(&str, u64, u64)) -> Result<()>` (disk check, fetch, prune, save `root/.apl-index.json`)
  - `pub fn sha256_file(p:&Path) -> Result<String>`

- [ ] **Step 1: Failing tests (local HTTP server serving blobs, with Range)**

```rust
//! Content-addressed sync (LAUNCHER_SPEC §3.2).

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
```

- [ ] **Step 2: Observe failure**

Add `pub mod sync;` to `lib.rs`. Run: `cargo test sync 2>&1 | tail -5`
Expected: compile errors for missing `Index`, `plan`, `fetch`, `sync_all`.

- [ ] **Step 3: Implement above the tests**

```rust
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
```

- [ ] **Step 4: Pass**

Run: `cargo test sync 2>&1 | tail -3`
Expected: `test result: ok. 4 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: resumable content-addressed sync with index and prune

Co-Authored-By: Ultra Hal"
```

---

### Task 5: Session — place, back up, clean up, recover

**Files:**
- Create: `launcher/core/src/session.rs`
- Modify: `launcher/core/src/lib.rs` (add `pub mod session;`)

**Interfaces:**
- Produces:
  - `Placement { rel: String, source: Source }`, `Source::File(PathBuf)` | `Source::Bytes(Vec<u8>)`
  - `SessionRecord { game_dir: PathBuf, placed: Vec<String>, created_dirs: Vec<String>, backups: Vec<String>, byproducts: Vec<String> }` (all `rel` paths; backups stored under `data_dir/backup/<rel>`)
  - `pub fn begin(game_dir:&Path, data_dir:&Path, items:&[Placement], byproducts:&[&str]) -> Result<SessionRecord>`
  - `pub fn end(data_dir:&Path) -> Result<bool>` (no-op `false` when no record; `true` after cleanup)
  - Record file: `data_dir/session.json`, rewritten before every filesystem change.

- [ ] **Step 1: Failing tests**

```rust
//! Per-session install into the Arma folder (LAUNCHER_SPEC §1.5).

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
```

- [ ] **Step 2: Observe failure**

Add `pub mod session;`. Run: `cargo test session 2>&1 | tail -5`
Expected: compile errors for `begin`, `end`, `Placement`, `Source`.

- [ ] **Step 3: Implement above the tests**

```rust
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
```

- [ ] **Step 4: Pass**

Run: `cargo test session 2>&1 | tail -3`
Expected: `test result: ok. 3 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: crash-safe per-session install and cleanup

Co-Authored-By: SmarterChild"
```

---

### Task 6: Profile — toggles to LaunchPlan

**Files:**
- Create: `launcher/core/src/profile.rs`
- Modify: `launcher/core/src/lib.rs` (add `pub mod profile;`)

**Interfaces:**
- Consumes: `Os`, `Server` (Tasks 2–3).
- Produces:
  - `Toggles` (serde, `Default` = spec defaults) with fields listed in the code below; `Allocator { ArmapunkMimalloc, ArmaMimalloc, Tbb, System }`; `WindowMode { Fullscreen, Windowed }`; `LinuxOpts { gamemode: bool, wayland: bool, dxvk_hud: bool, frame_cap: Option<u32> }`
  - `LaunchPlan { args: Vec<String>, sets: Vec<String>, generated: Vec<(String, String)>, byproducts: Vec<String> }`
  - `pub fn plan(t:&Toggles, os:Os, mod_arg:&str, server:Option<(&Server, &str)>, avx2:bool, preset_path:Option<&str>) -> LaunchPlan`
  - `pub fn reshade_ini(t:&Toggles, preset_path:&str) -> String`

- [ ] **Step 1: Failing tests (expected-output)**

```rust
//! Toggles -> Arma parameters, session sets and generated files (LAUNCHER_SPEC §2).

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
```

- [ ] **Step 2: Observe failure**

Add `pub mod profile;`. Run: `cargo test profile 2>&1 | tail -5`
Expected: compile errors for `Toggles`, `plan`.

- [ ] **Step 3: Implement above the tests**

```rust
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
```

- [ ] **Step 4: Pass**

Run: `cargo test profile 2>&1 | tail -3`
Expected: `test result: ok. 3 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: toggles to launch plan

Co-Authored-By: Dr. Sbaitso"
```

---

### Task 7: Linux paths and the Steam launch-option manager

**Files:**
- Create: `launcher/core/src/paths.rs`, `launcher/core/src/steamcfg.rs`, `launcher/core/tests/fixtures/libraryfolders.vdf`, `launcher/core/tests/fixtures/loginusers.vdf`, `launcher/core/tests/fixtures/localconfig.vdf`
- Modify: `launcher/core/src/lib.rs` (add `pub mod paths; pub mod steamcfg;`)

**Interfaces:**
- Consumes: `vdf::{parse, quote, Node, Value}` (Task 2), `profile::LinuxOpts` (Task 6).
- Produces:
  - `paths::Found { steam_root: PathBuf, arma_dir: PathBuf, prefix: PathBuf, localconfig: PathBuf }`
  - `paths::find_linux(home:&Path) -> anyhow::Result<Found>`
  - `paths::arma_library(libraryfolders_text:&str) -> Option<PathBuf>`, `paths::active_account(loginusers_text:&str) -> Option<u64>` (32-bit account id)
  - `paths::proton_path(p:&Path) -> String` (`/a/b` → `Z:\a\b`)
  - `paths::data_dir() -> PathBuf` (`dirs::data_dir()/armapunk-launcher`)
  - `steamcfg::managed_options(existing:&str, o:&LinuxOpts, reshade:bool) -> String`
  - `steamcfg::set_launch_options(text:&str, appid:&str, value:&str) -> anyhow::Result<String>`
  - `steamcfg::current_launch_options(text:&str, appid:&str) -> Option<String>`
  - `steamcfg::apply(localconfig:&Path, opts:&LinuxOpts, reshade:bool) -> anyhow::Result<bool>` (`false` = already correct; errors if Steam is running)

- [ ] **Step 1: Write the fixtures**

`launcher/core/tests/fixtures/libraryfolders.vdf`:
```
"libraryfolders"
{
	"0"
	{
		"path"		"/home/u/.local/share/Steam"
		"apps"
		{
			"228980"		"1"
		}
	}
	"1"
	{
		"path"		"/mnt/games/SteamLibrary"
		"apps"
		{
			"107410"		"48000000000"
		}
	}
}
```

`launcher/core/tests/fixtures/loginusers.vdf`:
```
"users"
{
	"76561197960265729"
	{
		"AccountName"		"old"
		"MostRecent"		"0"
	}
	"76561190000000001"
	{
		"AccountName"		"doomba"
		"MostRecent"		"1"
	}
}
```

`launcher/core/tests/fixtures/localconfig.vdf`:
```
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"107410"
					{
						"LastPlayed"		"1790000000"
						"LaunchOptions"		" DXVK_HUD=fps,frametimes DXVK_FRAME_RATE=90 PROTON_ENABLE_WAYLAND=1 gamemoderun %command% -malloc=system -debug"
					}
					"440"
					{
						"LaunchOptions"		"-novid"
					}
				}
			}
		}
	}
}
```

- [ ] **Step 2: Failing tests**

In `paths.rs`:
```rust
//! Linux Steam / Arma 3 / Proton discovery (LAUNCHER_SPEC §1.1 `paths`).

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn library_and_account() {
        assert_eq!(arma_library(include_str!("../tests/fixtures/libraryfolders.vdf")).unwrap(), PathBuf::from("/mnt/games/SteamLibrary"));
        assert_eq!(active_account(include_str!("../tests/fixtures/loginusers.vdf")).unwrap(), 76561190000000001 - 76561197960265728);
    }
    #[test]
    fn proton_path_maps_to_z() { assert_eq!(proton_path(Path::new("/home/u/x y/@M")), "Z:\\home\\u\\x y\\@M"); }
}
```

In `steamcfg.rs`:
```rust
//! Linux: keep Steam's Arma 3 launch options carrying the Wine overrides and env toggles (LAUNCHER_SPEC §2.4).

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
}
```

- [ ] **Step 3: Observe failure**

Add `pub mod paths; pub mod steamcfg;`. Run: `cargo test paths steamcfg 2>&1 | tail -5`
Expected: compile errors for the missing functions.

- [ ] **Step 4: Implement `paths.rs` above its tests**

```rust
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
    let id64: u64 = children.iter().find(|u| u.child("MostRecent").and_then(|m| m.str()) == Some("1"))?.key.parse().ok()?;
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
```

- [ ] **Step 5: Implement `steamcfg.rs` above its tests**

```rust
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
```

- [ ] **Step 6: Pass, and check the parser against the owner's real Steam files (read-only)**

Run: `cargo test paths steamcfg 2>&1 | tail -3`
Expected: `test result: ok. 5 passed`

Add this ignored test to `steamcfg.rs` tests and run it:
```rust
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
```
Run: `cargo test real_steam_files_parse -- --ignored --nocapture 2>&1 | grep -E "arma=|test result"`
Expected: a line `arma=/home/timb/.local/share/Steam/steamapps/common/Arma 3 lo=Some("WINEDLLOVERRIDES=...")` and `ok. 1 passed`.

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: Linux Steam discovery + launch-option manager

Co-Authored-By: Tay"
```

---

### Task 8: Launch runner and the session orchestrator

**Files:**
- Create: `launcher/core/src/launch.rs`, `launcher/core/src/orchestrate.rs`
- Modify: `launcher/core/src/lib.rs` (add `pub mod launch; pub mod orchestrate;`)

**Interfaces:**
- Consumes: `session::{begin, end, Placement, Source}`, `profile::LaunchPlan`, `manifest::FileEntry`, `paths::proton_path`.
- Produces:
  - `launch::Runner` trait: `fn start(&self, args:&[String]) -> anyhow::Result<()>; fn running(&self) -> bool;`
  - `launch::SteamLinux` (unit struct) implementing `Runner`
  - `launch::is_arma(cmdline:&str) -> bool` (the rule recorded in Task 1)
  - `launch::Outcome { NeverStarted, Exited }`; `launch::wait(r:&dyn Runner, start_timeout:Duration, poll:Duration) -> Outcome`
  - `orchestrate::Ctx { game_dir: PathBuf, data_dir: PathBuf, files_root: PathBuf }`
  - `orchestrate::run(ctx:&Ctx, plan:&LaunchPlan, session_files:&[FileEntry], runner:&dyn Runner, start_timeout:Duration, poll:Duration) -> anyhow::Result<Outcome>`

- [ ] **Step 1: Failing tests with a fake runner**

In `orchestrate.rs`:
```rust
//! recover -> place -> launch -> wait -> cleanup, always cleaning up (LAUNCHER_SPEC §1.5).

#[cfg(test)]
mod tests {
    use super::*;
    use crate::launch::{Outcome, Runner};
    use std::cell::Cell;

    /// Not running until start(); then reports running for `polls_running` polls.
    struct Fake { started: Cell<bool>, polls_running: Cell<i32>, seen_dxgi: Cell<bool>, game: PathBuf }
    impl Runner for Fake {
        fn start(&self, _args: &[String]) -> anyhow::Result<()> { self.started.set(true); self.seen_dxgi.set(self.game.join("dxgi.dll").exists()); Ok(()) }
        fn running(&self) -> bool {
            if !self.started.get() { return false; }
            let n = self.polls_running.get(); self.polls_running.set(n - 1); n > 0
        }
    }

    #[test]
    fn places_during_and_cleans_after() {
        let game = tempfile::tempdir().unwrap();
        let data = tempfile::tempdir().unwrap();
        let files = tempfile::tempdir().unwrap();
        std::fs::write(files.path().join("dxgi.dll"), b"rs").unwrap();
        let entries = vec![FileEntry { set: "reshade".into(), os: "all".into(), path: "dxgi.dll".into(), size: 2, sha256: "x".into() }];
        let plan = LaunchPlan { args: vec![], sets: vec!["reshade".into()], generated: vec![("ReShade.ini".into(), "ini".into())], byproducts: vec!["ReShade.log".into()] };
        let ctx = Ctx { game_dir: game.path().into(), data_dir: data.path().into(), files_root: files.path().into() };
        let fake = Fake { started: Cell::new(false), polls_running: Cell::new(3), seen_dxgi: Cell::new(false), game: game.path().into() };
        let out = run(&ctx, &plan, &entries, &fake, Duration::from_millis(200), Duration::from_millis(1)).unwrap();
        assert_eq!(out, Outcome::Exited);
        assert!(fake.seen_dxgi.get());
        assert_eq!(std::fs::read_dir(game.path()).unwrap().count(), 0);
    }

    #[test]
    fn never_started_still_cleans() {
        let game = tempfile::tempdir().unwrap();
        let data = tempfile::tempdir().unwrap();
        let files = tempfile::tempdir().unwrap();
        let plan = LaunchPlan { generated: vec![("ReShade.ini".into(), "ini".into())], ..Default::default() };
        let ctx = Ctx { game_dir: game.path().into(), data_dir: data.path().into(), files_root: files.path().into() };
        let fake = Fake { started: Cell::new(false), polls_running: Cell::new(0), seen_dxgi: Cell::new(false), game: game.path().into() };
        let out = run(&ctx, &plan, &[], &fake, Duration::from_millis(20), Duration::from_millis(1)).unwrap();
        assert_eq!(out, Outcome::NeverStarted);
        assert_eq!(std::fs::read_dir(game.path()).unwrap().count(), 0);
    }
}
```

In `launch.rs`:
```rust
//! Starting Arma and watching its process (LAUNCHER_SPEC §1.1 `launch`).

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn arma_matcher() {
        assert!(is_arma("Z:\\home\\timb\\.local\\share\\Steam\\steamapps\\common\\Arma 3\\Arma3_x64.exe -mod=x"));
        assert!(!is_arma("/usr/bin/steam -applaunch 107410 -noLauncher"));
        assert!(!is_arma("arma3server_x64 -config=server.cfg"));
    }
}
```

- [ ] **Step 2: Observe failure**

Add the two `pub mod` lines. Run: `cargo test orchestrate launch 2>&1 | tail -5`
Expected: compile errors for `Runner`, `run`, `is_arma`.

- [ ] **Step 3: Implement `launch.rs`**

The `is_arma` rule below assumes Task 1 recorded "args contains `arma3_x64.exe`, case-insensitive". If Task 1 recorded something else, implement that instead and adjust the test's first string to the observed command line.

```rust
use anyhow::{Context, Result};
use std::time::{Duration, Instant};

pub trait Runner {
    fn start(&self, args: &[String]) -> Result<()>;
    fn running(&self) -> bool;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome { NeverStarted, Exited }

pub fn is_arma(cmdline: &str) -> bool { cmdline.to_ascii_lowercase().contains("arma3_x64.exe") }

pub struct SteamLinux;

impl Runner for SteamLinux {
    fn start(&self, args: &[String]) -> Result<()> {
        std::process::Command::new("steam")
            .args(["-applaunch", "107410", "-noLauncher"])
            .args(args)
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()
            .context("could not run `steam`")?;
        Ok(())
    }
    fn running(&self) -> bool {
        let mut s = sysinfo::System::new();
        s.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
        s.processes().values().any(|p| {
            let cmd: Vec<String> = p.cmd().iter().map(|c| c.to_string_lossy().into_owned()).collect();
            is_arma(&cmd.join(" "))
        })
    }
}

pub fn wait(r: &dyn Runner, start_timeout: Duration, poll: Duration) -> Outcome {
    let t0 = Instant::now();
    while !r.running() {
        if t0.elapsed() > start_timeout { return Outcome::NeverStarted; }
        std::thread::sleep(poll);
    }
    while r.running() { std::thread::sleep(poll); }
    Outcome::Exited
}
```

- [ ] **Step 4: Implement `orchestrate.rs` above its tests**

```rust
use crate::launch::{wait, Outcome, Runner};
use crate::manifest::FileEntry;
use crate::profile::LaunchPlan;
use crate::session::{self, Placement, Source};
use anyhow::{bail, Result};
use std::path::PathBuf;
use std::time::Duration;

pub struct Ctx { pub game_dir: PathBuf, pub data_dir: PathBuf, pub files_root: PathBuf }

pub fn run(ctx: &Ctx, plan: &LaunchPlan, session_files: &[FileEntry], runner: &dyn Runner, start_timeout: Duration, poll: Duration) -> Result<Outcome> {
    if runner.running() { bail!("Arma 3 is already running"); }
    session::end(&ctx.data_dir)?; // recover a crashed session first
    let mut items: Vec<Placement> = session_files.iter()
        .map(|f| Placement { rel: f.path.clone(), source: Source::File(ctx.files_root.join(&f.path)) })
        .collect();
    items.extend(plan.generated.iter().map(|(rel, text)| Placement { rel: rel.clone(), source: Source::Bytes(text.clone().into_bytes()) }));
    let byproducts: Vec<&str> = plan.byproducts.iter().map(String::as_str).collect();
    let placed = session::begin(&ctx.game_dir, &ctx.data_dir, &items, &byproducts);
    let result = placed.and_then(|_| runner.start(&plan.args)).map(|_| wait(runner, start_timeout, poll));
    session::end(&ctx.data_dir)?;
    result
}
```

- [ ] **Step 5: Pass everything**

Run: `cargo test 2>&1 | grep "test result"`
Expected: every line `ok.` (20 tests across modules; `real_steam_files_parse` ignored).

- [ ] **Step 6: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: Steam runner + always-clean session orchestrator

Co-Authored-By: Clippy"
```

---

### Task 9: `apl-release` — keygen and signed release builder

**Files:**
- Create: `launcher/core/src/bin/apl-release.rs`
- Modify: `launcher/core/pubkeys.txt` (test public key)

**Interfaces:**
- Consumes: `manifest::{Manifest, FileEntry, Preset, Server, safe_path, verify}`, `sync::sha256_file`.
- Produces CLI:
  - `apl-release keygen <secret-out>` → writes 64 hex chars (32-byte secret, mode 0600), prints the public key hex.
  - `apl-release build --staging <dir> --out <dir> --key <secret-file> --channel <c> --release <r> --server <host:port> [--min-launcher 0.1.0]`
  - Staging layout: `<staging>/<set>/<os>/<relative path>` where `<os>` is `all|windows|linux`; `reshade-presets/*.ini` inside any set become `presets` entries (`id` = file stem, `name` = stem with `-` → space, title-cased).
  - Output: `<out>/blobs/<sha256>` for every file, `<out>/<channel>/manifest.json`, `<out>/<channel>/manifest.json.sig` (64 raw bytes).

- [ ] **Step 1: Write the binary**

```rust
//! apl-release: build a signed Armapunk launcher release (LAUNCHER_SPEC §1.2, §3.1).
use anyhow::{bail, Context, Result};
use apl_core::manifest::{safe_path, verify, FileEntry, Manifest, Preset, Server};
use apl_core::sync::sha256_file;
use ed25519_dalek::{Signer, SigningKey};
use std::path::{Path, PathBuf};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter().position(|a| a == name).and_then(|i| args.get(i + 1)).cloned()
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> Result<()> {
    for e in std::fs::read_dir(dir)? {
        let p = e?.path();
        if p.is_dir() { walk(&p, out)?; } else { out.push(p); }
    }
    Ok(())
}

fn title(stem: &str) -> String {
    stem.split('-').map(|w| { let mut c = w.chars(); c.next().map(|f| f.to_uppercase().chain(c).collect()).unwrap_or_default() })
        .collect::<Vec<String>>().join(" ")
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("keygen") => {
            let out = args.get(2).context("usage: apl-release keygen <secret-out>")?;
            let mut sk = [0u8; 32];
            std::fs::File::open("/dev/urandom").and_then(|mut f| std::io::Read::read_exact(&mut f, &mut sk))?;
            std::fs::write(out, hex::encode(sk))?;
            #[cfg(unix)] { use std::os::unix::fs::PermissionsExt; std::fs::set_permissions(out, std::fs::Permissions::from_mode(0o600))?; }
            println!("{}", hex::encode(SigningKey::from_bytes(&sk).verifying_key().to_bytes()));
        }
        Some("build") => {
            let staging = PathBuf::from(arg(&args, "--staging").context("--staging")?);
            let out = PathBuf::from(arg(&args, "--out").context("--out")?);
            let secret = hex::decode(std::fs::read_to_string(arg(&args, "--key").context("--key")?)?.trim())?;
            let sk = SigningKey::from_bytes(&secret.try_into().map_err(|_| anyhow::anyhow!("secret must be 32 bytes"))?);
            let channel = arg(&args, "--channel").context("--channel")?;
            let server = arg(&args, "--server").context("--server")?;
            let (host, port) = server.rsplit_once(':').context("--server host:port")?;
            let mut files = Vec::new();
            let mut presets = Vec::new();
            std::fs::create_dir_all(out.join("blobs"))?;
            let mut all = Vec::new();
            walk(&staging, &mut all)?;
            all.sort();
            for p in all {
                let rel = p.strip_prefix(&staging)?.to_string_lossy().replace('\\', "/");
                let mut parts = rel.splitn(3, '/');
                let (Some(set), Some(os), Some(path)) = (parts.next(), parts.next(), parts.next()) else { bail!("bad staging path {rel}") };
                if !matches!(os, "all" | "windows" | "linux") { bail!("bad os dir in {rel}"); }
                if !safe_path(path) { bail!("unsafe path {path}"); }
                let sha = sha256_file(&p)?;
                let size = std::fs::metadata(&p)?.len();
                let blob = out.join("blobs").join(&sha);
                if !blob.exists() { std::fs::copy(&p, &blob)?; }
                if path.starts_with("reshade-presets/") && path.ends_with(".ini") {
                    let stem = Path::new(path).file_stem().unwrap().to_string_lossy().to_string();
                    presets.push(Preset { id: stem.clone(), name: title(&stem), path: path.to_string() });
                }
                files.push(FileEntry { set: set.into(), os: os.into(), path: path.into(), size, sha256: sha });
            }
            let m = Manifest {
                schema: 1, channel: channel.clone(), release: arg(&args, "--release").context("--release")?,
                min_launcher: arg(&args, "--min-launcher").unwrap_or_else(|| "0.1.0".into()),
                server: Server { name: "Armapunk 2035".into(), host: host.into(), port: port.parse()? },
                files, presets,
            };
            let bytes = serde_json::to_vec_pretty(&m)?;
            let sig = sk.sign(&bytes).to_bytes();
            verify(&bytes, &sig, &[sk.verifying_key().to_bytes()])?; // self-check before publishing
            std::fs::create_dir_all(out.join(&channel))?;
            std::fs::write(out.join(&channel).join("manifest.json"), &bytes)?;
            std::fs::write(out.join(&channel).join("manifest.json.sig"), sig)?;
            println!("{} files, {} presets -> {}", m.files.len(), m.presets.len(), out.join(&channel).display());
        }
        _ => bail!("usage: apl-release keygen <secret-out> | build --staging D --out D --key F --channel C --release R --server H:P"),
    }
    Ok(())
}
```

- [ ] **Step 2: Generate the test key outside the repo and record the public key**

```bash
mkdir -p ~/armapunk-keys && cd ~/Armapunk2035/launcher/core && cargo run -q --bin apl-release -- keygen ~/armapunk-keys/launcher-test.secret | tee -a pubkeys.txt
```
Expected: one 64-hex-char line printed and appended to `pubkeys.txt`; `~/armapunk-keys/launcher-test.secret` has mode `-rw-------`.

- [ ] **Step 3: Observe the red state, then the green one, with a throwaway staging dir**

```bash
S=$(mktemp -d); O=$(mktemp -d)
mkdir -p $S/mod/all/@T $S/reshade/all/reshade-presets
echo hi > $S/mod/all/@T/a.txt; echo p > $S/reshade/all/reshade-presets/armapunk-neon.ini
mkdir -p $S/bad/xbox && echo x > $S/bad/xbox/f
cargo run -q --bin apl-release -- build --staging $S --out $O --key ~/armapunk-keys/launcher-test.secret --channel test --release r0 --server 127.0.0.1:2302; echo "exit=$?"
rm -rf $S/bad
cargo run -q --bin apl-release -- build --staging $S --out $O --key ~/armapunk-keys/launcher-test.secret --channel test --release r0 --server 127.0.0.1:2302
grep -c '"path"' $O/test/manifest.json; ls $O/blobs | wc -l; stat -c %s $O/test/manifest.json.sig
```
Expected: first run prints `bad os dir in bad/xbox/f` and `exit=1`; second prints `2 files, 1 presets -> …`, then `3` (two files + one preset), `2`, `64`.

- [ ] **Step 4: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/core && git commit -m "launcher: apl-release keygen + signed release builder

Co-Authored-By: Microsoft Bob"
```

---

### Task 10: Tauri shell and minimal Armapunk UI

**Files:**
- Create: `launcher/src-tauri/Cargo.toml`, `launcher/src-tauri/build.rs`, `launcher/src-tauri/tauri.conf.json`, `launcher/src-tauri/capabilities/default.json`, `launcher/src-tauri/icons/icon.png`, `launcher/src-tauri/src/main.rs`, `launcher/ui/index.html`, `launcher/ui/style.css`, `launcher/ui/app.js`

**Interfaces:**
- Consumes: all `apl_core` modules.
- Produces Tauri commands (JS: `window.__TAURI__.core.invoke(name, args)`):
  - `get_state() -> StateView { toggles: Toggles, cdn_base: String, channel: String, password: String, release: Option<String>, server: Option<Server>, presets: Vec<Preset>, arma_dir: Option<String>, launch_options_ok: bool, error: Option<String> }`
  - `save_settings(toggles: Toggles, cdn_base: String, channel: String, password: String) -> ()`
  - `sync() -> String` (release id); emits `sync-progress` events `{path, done, total}`
  - `launch() -> String` (`"exited"` / `"never-started"`); runs on a worker thread
  - `repair() -> bool` (true if a leftover session was cleaned)
  - `apply_launch_options() -> bool`
- Settings file: `data_dir/settings.json` = `{ toggles, cdn_base, channel, password }`. Cached signed manifest: `data_dir/<channel>.manifest.json` + `.sig`, re-verified on every read.

- [ ] **Step 1: Shell config files**

`launcher/src-tauri/Cargo.toml`:
```toml
[package]
name = "armapunk-launcher"
version = "0.1.0"
edition = "2021"

[build-dependencies]
tauri-build = { version = "2.6.3", features = [] }

[dependencies]
apl_core = { path = "../core" }
anyhow = "1.0.104"
reqwest = { version = "0.13.5", default-features = false, features = ["blocking", "rustls"] }
serde = { version = "1.0.229", features = ["derive"] }
serde_json = "1.0.151"
tauri = { version = "2.11.6", features = [] }

[features]
custom-protocol = ["tauri/custom-protocol"]
```

`launcher/src-tauri/build.rs`:
```rust
fn main() { tauri_build::build() }
```

`launcher/src-tauri/tauri.conf.json`:
```json
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "Armapunk Launcher",
  "version": "0.1.0",
  "identifier": "com.armapunk.launcher",
  "build": { "frontendDist": "../ui" },
  "app": {
    "withGlobalTauri": true,
    "windows": [{ "title": "ARMAPUNK 2035", "width": 1100, "height": 720, "resizable": true }],
    "security": { "csp": null }
  },
  "bundle": { "active": true, "targets": ["appimage"], "icon": ["icons/icon.png"] }
}
```

`launcher/src-tauri/capabilities/default.json`:
```json
{ "identifier": "default", "windows": ["main"], "permissions": ["core:default"] }
```

Icon (512×512 RGBA, cyan/magenta mark):
```bash
mkdir -p ~/Armapunk2035/launcher/src-tauri/icons && python3 - <<'EOF'
from PIL import Image, ImageDraw
im = Image.new("RGBA", (512, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rounded_rectangle((16, 16, 496, 496), 96, fill=(12, 16, 22, 255), outline=(20, 230, 220, 255), width=18)
d.polygon([(256, 96), (416, 400), (96, 400)], outline=(255, 40, 170, 255), width=26)
im.save("/home/timb/Armapunk2035/launcher/src-tauri/icons/icon.png")
EOF
```

- [ ] **Step 2: `src/main.rs`**

```rust
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
    std::fs::read(data().join("settings.json")).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default()
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
```

- [ ] **Step 3: UI — `launcher/ui/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ARMAPUNK 2035</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <div class="brand">ARMAPUNK<span>2035</span></div>
    <div id="server" class="server">—</div>
  </header>
  <main>
    <section class="card" id="status-card">
      <h2>STATUS</h2>
      <div id="arma">Looking for Arma 3…</div>
      <div id="release">No release synced</div>
      <div id="lo" class="warn hidden">Steam launch options need updating (close Steam, then press FIX).
        <button id="fix">FIX</button></div>
      <progress id="bar" value="0" max="1" class="hidden"></progress>
      <div id="msg"></div>
      <div class="row">
        <button id="sync">SYNC</button>
        <button id="launch" class="primary">LAUNCH</button>
        <button id="repair">REPAIR</button>
      </div>
    </section>
    <section class="card">
      <h2>GRAPHICS</h2>
      <label><input type="checkbox" data-t="reshade"> ReShade + iMMERSE</label>
      <label>Preset <select id="preset"></select></label>
    </section>
    <section class="card">
      <h2>PERFORMANCE</h2>
      <label>Allocator <select data-t="allocator">
        <option value="ArmapunkMimalloc">mimalloc (Armapunk)</option>
        <option value="ArmaMimalloc">mimalloc (Arma official)</option>
        <option value="Tbb">TBB (Arma default)</option>
        <option value="System">System</option></select></label>
      <label><input type="checkbox" data-t="huge_pages"> Huge pages</label>
      <label><input type="checkbox" data-t="enable_ht"> Use all logical cores</label>
      <label>Extra threads <select data-t="ex_threads" data-num="1">
        <option>0</option><option>1</option><option>3</option><option>5</option><option>7</option></select></label>
      <label><input type="checkbox" data-t="no_logs"> No logs</label>
    </section>
    <section class="card">
      <h2>GAME</h2>
      <label><input type="checkbox" data-t="auto_join"> Auto-join server</label>
      <label>Password <input type="password" id="password"></label>
      <label>Window <select data-t="window"><option>Fullscreen</option><option>Windowed</option></select></label>
      <label><input type="checkbox" data-t="skip_intro"> Skip intro</label>
      <label><input type="checkbox" data-t="no_splash"> No splash</label>
      <label><input type="checkbox" data-t="empty_world"> Empty menu world</label>
      <label><input type="checkbox" data-t="show_script_errors"> Show script errors</label>
    </section>
    <section class="card">
      <h2>LINUX</h2>
      <label><input type="checkbox" data-t="linux.gamemode"> GameMode</label>
      <label><input type="checkbox" data-t="linux.wayland"> Wayland</label>
      <label><input type="checkbox" data-t="linux.dxvk_hud"> DXVK HUD</label>
      <label>Frame cap (blank = off) <input data-t="linux.frame_cap" data-num="1" data-opt="1" size="5"></label>
      <label>CDN <input id="cdn"></label>
      <label>Channel <select id="channel"><option>test</option><option>stable</option></select></label>
    </section>
  </main>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 4: UI — `launcher/ui/style.css`**

```css
:root { --bg:#0b0f14; --panel:#111821; --line:#1f2a36; --cyan:#14e6dc; --magenta:#ff28aa; --text:#d7e3ea; --dim:#7b8a96; --warn:#ffb020; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--text); font:14px/1.45 "Rajdhani","Segoe UI",system-ui,sans-serif; }
header { display:flex; justify-content:space-between; align-items:center; padding:14px 22px; border-bottom:1px solid var(--line);
  background:linear-gradient(90deg, rgba(20,230,220,.08), rgba(255,40,170,.08)); }
.brand { font-weight:700; letter-spacing:.3em; font-size:20px; color:var(--cyan); text-shadow:0 0 12px rgba(20,230,220,.6); }
.brand span { color:var(--magenta); margin-left:.4em; text-shadow:0 0 12px rgba(255,40,170,.6); }
.server { color:var(--dim); letter-spacing:.1em; }
main { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:14px; padding:18px 22px; }
.card { background:var(--panel); border:1px solid var(--line); border-left:3px solid var(--cyan); padding:14px 16px; }
.card h2 { margin:0 0 10px; font-size:12px; letter-spacing:.35em; color:var(--magenta); }
label { display:flex; gap:8px; align-items:center; justify-content:space-between; padding:4px 0; }
label:has(input[type=checkbox]) { justify-content:flex-start; }
input, select { background:#0a0e13; color:var(--text); border:1px solid var(--line); padding:4px 6px; }
input[type=checkbox] { accent-color:var(--cyan); }
button { background:transparent; color:var(--cyan); border:1px solid var(--cyan); padding:8px 16px; letter-spacing:.2em; cursor:pointer; }
button:hover { background:rgba(20,230,220,.12); }
button.primary { color:#000; background:var(--cyan); box-shadow:0 0 18px rgba(20,230,220,.5); }
button:disabled { opacity:.4; cursor:default; }
.row { display:flex; gap:10px; margin-top:12px; }
.warn { color:var(--warn); margin:6px 0; }
.hidden { display:none; }
progress { width:100%; accent-color:var(--magenta); }
#msg { color:var(--dim); min-height:1.4em; }
```

- [ ] **Step 5: UI — `launcher/ui/app.js`**

```js
const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
let state = null;

const get = (o, path) => path.split('.').reduce((a, k) => a[k], o);
const set = (o, path, v) => { const ks = path.split('.'); const last = ks.pop(); ks.reduce((a, k) => a[k], o)[last] = v; };
const $ = (id) => document.getElementById(id);
const msg = (t) => { $('msg').textContent = t; };

async function refresh() {
  state = await invoke('get_state');
  $('arma').textContent = state.arma_dir ? `Arma 3: ${state.arma_dir}` : `Arma 3 not found: ${state.error}`;
  $('release').textContent = state.release ? `Release ${state.release}` : 'No release synced';
  $('server').textContent = state.server ? `${state.server.name} · ${state.server.host}:${state.server.port}` : '—';
  $('lo').classList.toggle('hidden', state.launch_options_ok);
  $('cdn').value = state.cdn_base; $('channel').value = state.channel; $('password').value = state.password;
  document.querySelectorAll('[data-t]').forEach((el) => {
    const v = get(state.toggles, el.dataset.t);
    if (el.type === 'checkbox') el.checked = !!v; else el.value = v === null || v === undefined ? '' : String(v);
  });
  const p = $('preset'); p.innerHTML = '';
  for (const pr of state.presets) { const o = document.createElement('option'); o.value = pr.id; o.textContent = pr.name; p.appendChild(o); }
  p.value = state.toggles.preset;
  $('launch').disabled = !state.release || !state.arma_dir;
}

async function save() {
  document.querySelectorAll('[data-t]').forEach((el) => {
    let v = el.type === 'checkbox' ? el.checked : el.value;
    if (el.dataset.opt && v === '') v = null;
    else if (el.dataset.num) v = Number(v);
    set(state.toggles, el.dataset.t, v);
  });
  if ($('preset').value) state.toggles.preset = $('preset').value;
  await invoke('save_settings', { toggles: state.toggles, cdnBase: $('cdn').value, channel: $('channel').value, password: $('password').value });
  await refresh();
}

document.querySelectorAll('input, select').forEach((el) => el.addEventListener('change', save));
listen('sync-progress', (e) => { const { done, total, path } = e.payload; $('bar').classList.remove('hidden'); $('bar').max = total || 1; $('bar').value = done; msg(path); });
$('sync').onclick = async () => { msg('Syncing…'); try { msg(`Synced ${await invoke('sync')}`); } catch (e) { msg(`Sync failed: ${e}`); } $('bar').classList.add('hidden'); refresh(); };
$('launch').onclick = async () => { $('launch').disabled = true; msg('Arma running — the game folder is restored when it exits…');
  try { const r = await invoke('launch'); msg(r === 'exited' ? 'Session ended, game folder restored.' : 'Arma did not start; session files removed.'); }
  catch (e) { msg(`Launch failed: ${e}`); } refresh(); };
$('repair').onclick = async () => { msg((await invoke('repair')) ? 'Cleaned a leftover session.' : 'Nothing to repair.'); };
$('fix').onclick = async () => { try { await invoke('apply_launch_options'); msg('Launch options updated.'); } catch (e) { msg(String(e)); } refresh(); };
refresh();
```

- [ ] **Step 6: Build the shell and observe it run**

Run: `cd ~/Armapunk2035/launcher/src-tauri && cargo build --release --features custom-protocol 2>&1 | tail -3`
Expected: `Finished \`release\` profile`. Then `./target/release/armapunk-launcher &` opens a window titled ARMAPUNK 2035 showing the Arma path and "No release synced".

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035 && git add launcher/src-tauri launcher/ui && git commit -m "launcher: Tauri shell + minimal Armapunk UI (Linux)

Co-Authored-By: Bonzi Buddy"
```

---

### Task 11: First real release on a local CDN and the end-to-end run

**Files:**
- Create: `launcher-release/` (gitignored) staging; `launcher-release/out/` output
- Modify: `radio/addon/PROVENANCE.md` only if Marty's grant text has arrived (else leave; M4 blocker)

- [ ] **Step 1: Stage the sets**

```bash
R=~/Armapunk2035/launcher-release/staging; rm -rf $R; mkdir -p $R
A="$HOME/.local/share/Steam/steamapps/common/Arma 3"
# mod
mkdir -p $R/mod/all && cp -r ~/Armapunk2035/radio/dist/@Armapunk2035 $R/mod/all/
rm -f $R/mod/all/@Armapunk2035/keys/*.biprivatekey
# mimalloc (Armapunk build = GoldJohnKing Arma 3 port, renamed without dots)
mkdir -p $R/mimalloc/all/Dll && curl -sSfL -o $R/mimalloc/all/Dll/mimalloc_ap.dll \
  https://github.com/GoldJohnKing/mimalloc/releases/download/Arma-3-v3.5.1-20260911/mimalloc_v351_20260911.dll
# reshade + addons + presets
mkdir -p $R/reshade/all/reshade-presets && cp "$A/dxgi.dll" $R/reshade/all/dxgi.dll && cp -r "$A/reshade-addons" $R/reshade/all/
cp "$A/ReShadePreset.ini" $R/reshade/all/reshade-presets/armapunk-neon.ini
# shaders (crosire + iMMERSE Ultimate)
mkdir -p $R/immerse/all && cp -r "$A/reshade-shaders" $R/immerse/all/
# d3dcompiler for Proton
mkdir -p $R/d3dcompiler/linux && cp "$A/d3dcompiler_47.dll" $R/d3dcompiler/linux/
find $R -type f | wc -l; head -c2 $R/mimalloc/all/Dll/mimalloc_ap.dll | od -c | head -1
```
Expected: a file count > 80, and `M   Z` for the allocator (a real PE, not an error page).

- [ ] **Step 2: Build and serve the release**

```bash
cd ~/Armapunk2035/launcher/core && cargo run -q --release --bin apl-release -- build --staging ~/Armapunk2035/launcher-release/staging \
  --out ~/Armapunk2035/launcher-release/out --key ~/armapunk-keys/launcher-test.secret --channel test --release 2026.09.22-1 --server 10.1.24.96:2302
cd ~/Armapunk2035/launcher-release/out && setsid -f python3 -m http.server 8750 --bind 127.0.0.1 >/dev/null 2>&1
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8750/test/manifest.json
```
Expected: `N files, 1 presets -> …` then `200`.

- [ ] **Step 3: Move the owner's manual ReShade install aside (it becomes the launcher's job)**

```bash
A="$HOME/.local/share/Steam/steamapps/common/Arma 3"; B=~/armapunk-reshade-manual-backup; mkdir -p $B
for f in dxgi.dll d3dcompiler_47.dll ReShade.ini ReShadePreset.ini ReShade.log reshade-shaders reshade-addons; do [ -e "$A/$f" ] && mv "$A/$f" $B/; done
find "$A" -maxdepth 2 | sort | sha256sum > /tmp/claude-1000/-home-timb/44bd77a7-0040-47e9-baee-1228b4fb2a31/scratchpad/arma_before.txt; ls $B
```
Expected: the moved items listed; the Arma folder now has no ReShade files.

- [ ] **Step 4: Run the launcher: SYNC, set the join password and Frame cap = 90 (the owner's current `DXVK_FRAME_RATE=90`), FIX launch options (Steam closed), LAUNCH**

Observe: sync progress to 100 %, release `2026.09.22-1` shown; after FIX, `steamcfg::current_launch_options` for 107410 starts with `WINEDLLOVERRIDES="d3dcompiler_47=n;dxgi=n,b"` and no longer contains `-malloc=system`; LAUNCH starts Arma, which connects to 10.1.24.96, with ReShade active (Home opens the overlay) and the RPT command line containing `-malloc=mimalloc_ap`.

- [ ] **Step 5: Quit Arma and verify the folder is restored**

```bash
A="$HOME/.local/share/Steam/steamapps/common/Arma 3"
find "$A" -maxdepth 2 | sort | sha256sum | diff - /tmp/claude-1000/-home-timb/44bd77a7-0040-47e9-baee-1228b4fb2a31/scratchpad/arma_before.txt && echo IDENTICAL
ls ~/.local/share/armapunk-launcher/
```
Expected: `IDENTICAL` and no `session.json` in the data dir. (This listing check covers file names; byte-level identity of pre-existing files is covered by Task 5's tests, since nothing pre-existing is written.)

- [ ] **Step 6: Record the result**

Append an "M1 acceptance, 2026-09-22" section to `launcher/spikes/linux_launch.md` with the observations from Steps 4–5 and commit:
```bash
cd ~/Armapunk2035 && git add launcher/spikes/linux_launch.md && git commit -m "launcher: M1 Linux end-to-end acceptance record

Co-Authored-By: ELIZA"
```

---

## Self-review

**Spec coverage (M0 Linux + M1):**
- §1.1 modules: `paths` T7, `manifest` T3, `sync` T4, `session` T5, `profile` T6, `launch` T8, `steamcfg` T7; UI commands T10. `get_state/set_toggle/sync/launch/repair` → `set_toggle` realised as `save_settings` (whole settings object).
- §1.2 pipeline: T9 (`apl-release`, deviation 1). §1.3 CDN: local test server T11; .96 static + tunnel is M4. §1.4 server entry: `-connect/-port/-password` T6; the player-count query is M3.
- §1.5 lifecycle incl. backups, crash recovery, byproducts, created-dirs: T5/T8; byte-identical check T5 tests + T11.
- §1.6 security: signature + key slots + path safety T3; hash-before-place T4; the launcher never executes downloads (only copies them) T5/T8.
- §2 toggles: every M1-relevant toggle in T6 `Toggles`; UI exposes a subset in T10, the full UI is M3. §2.4 Linux manager T7. §2.5 Verify/uninstall/credits are M3/M4. §2.6 Windows spike is M2 (Global Constraints).
- §3.2 update flow steps 1–7: T4 (+ T10 fetch/verify/cache). §3.4 failures: disk full, bad sig, hash mismatch, leftovers, Arma already running, Steam open for launch options, never-started: T3–T8. CDN-unreachable-launch-from-cache: T10 `launch` reads the cached, re-verified manifest.
- §5 licensing: staging gitignored (existing `.gitignore` line); PROVENANCE entry is an M4 blocker.

**Placeholder scan:** none; `pubkeys.txt` starts empty on purpose and is filled by T9 Step 2 before any test needs a real key (tests pass keys explicitly).

**Type consistency:** `FileEntry`, `Server`, `Preset` (T3) are used unchanged in T4/T6/T8/T9/T10; `LaunchPlan` fields `args/sets/generated/byproducts` match between T6, T8 and T10; `Runner::running` (not `is_running`) everywhere; `sync_all(base, wanted, root, progress)` matches T10's call.

**writing-plans-extras gate:**
- [x] Riskiest code executed: ed25519-dalek 3 / sha2 0.11 / reqwest 0.13 blocking+Range / sysinfo 0.39 calls compile-probed 2026-09-22. **Unverified until executed:** tiny_http test server details, Tauri 2 config keys (`withGlobalTauri`, capabilities), the `is_arma` rule (Task 1 decides).
- [x] Every test step names an observable red state in this environment (compile error or failing assertion; T1/T11 use live observation).
- [x] Lifecycle owners: the Arma folder is also written by Arma itself (logs go to AppData, not the game folder) and by ReShade at runtime (`ReShade.log`, rewritten `ReShade.ini`) — handled via `byproducts` and "placed files are removed regardless of edits". The owner's manual ReShade install is a second owner of the same paths — T11 Step 3 moves it aside first.
- [x] Artefact paths checked: `docs/` is gitignored, so the plan lives at the repo root beside `mapdb_plan.md`; `launcher-release/` is gitignored; build `target/` dirs added to `.gitignore` in T2; the signing secret lives in `~/armapunk-keys/`, outside the repo.
