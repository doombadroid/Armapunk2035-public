//! Armapunk launcher core. See LAUNCHER_SPEC.md; every module is usable without Tauri.
pub mod launch;
pub mod manifest;
pub mod orchestrate;
pub mod paths;
pub mod profile;
pub mod session;
pub mod steamcfg;
pub mod sync;
pub mod vdf;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Os { Windows, Linux }

impl Os {
    pub fn current() -> Os { if cfg!(windows) { Os::Windows } else { Os::Linux } }
    pub fn tag(&self) -> &'static str { match self { Os::Windows => "windows", Os::Linux => "linux" } }
}
