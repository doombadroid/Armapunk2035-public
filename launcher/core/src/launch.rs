//! Starting Arma and watching its process (LAUNCHER_SPEC §1.1 `launch`).

use anyhow::{Context, Result};
use std::time::{Duration, Instant};

pub trait Runner {
    fn start(&self, args: &[String]) -> Result<()>;
    fn running(&self) -> bool;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome { NeverStarted, Exited }

/// Arma's client process: argv[0] is the executable, `…\Arma3_x64.exe` under Proton
/// (launcher/spikes/linux_launch.md). Matching on argv[0] only, because any shell, editor
/// or grep whose arguments mention the exe would otherwise count as "Arma is running".
pub fn is_arma(argv: &[String]) -> bool {
    argv.first()
        .and_then(|a| a.rsplit(['\\', '/']).next())
        .is_some_and(|name| name.eq_ignore_ascii_case("arma3_x64.exe"))
}

/// Every process's argv.
pub fn command_lines() -> Vec<Vec<String>> {
    let mut s = sysinfo::System::new();
    // cmd must be requested explicitly: the default refresh leaves it empty (sysinfo 0.39).
    s.refresh_processes_specifics(sysinfo::ProcessesToUpdate::All, true,
        sysinfo::ProcessRefreshKind::nothing().with_cmd(sysinfo::UpdateKind::Always));
    s.processes().values()
        .map(|p| p.cmd().iter().map(|c| c.to_string_lossy().into_owned()).collect::<Vec<_>>())
        .collect()
}

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
    fn running(&self) -> bool { command_lines().iter().any(|c| is_arma(c)) }
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

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn process_scan_sees_command_lines() {
        // Regression: sysinfo's default refresh leaves cmd() empty, so Arma was never seen.
        let me = std::env::args().next().unwrap();
        assert!(command_lines().iter().any(|c| c.first() == Some(&me)), "own command line not found");
    }

    fn argv(v: &[&str]) -> Vec<String> { v.iter().map(|s| s.to_string()).collect() }

    #[test]
    fn arma_matcher_uses_the_executable_not_any_mention() {
        assert!(is_arma(&argv(&["Z:\\home\\timb\\.local\\share\\Steam\\steamapps\\common\\Arma 3\\Arma3_x64.exe", "-mod=x"])));
        assert!(!is_arma(&argv(&["/usr/bin/steam", "-applaunch", "107410", "-noLauncher"])));
        assert!(!is_arma(&argv(&["./arma3server_x64", "-config=server.cfg"])));
        // a shell or grep that merely mentions the exe must not block the launcher
        assert!(!is_arma(&argv(&["/bin/bash", "-c", "ps -eo args | grep -i arma3_x64.exe"])));
        assert!(!is_arma(&argv(&[])));
    }
}
