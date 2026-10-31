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
