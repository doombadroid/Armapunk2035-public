//! recover -> place -> launch -> wait -> cleanup, always cleaning up (LAUNCHER_SPEC §1.5).

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
