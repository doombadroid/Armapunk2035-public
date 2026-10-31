pub mod audio;
pub mod state;
pub mod titles; // Task 10

use arma_rs::{arma, Extension};
use audio::Player;
use state::{compute_volume, Shared};
use std::sync::mpsc::Sender;
use std::sync::Mutex;

static PLAYER: Mutex<Option<(Shared, Player, Option<Sender<()>>)>> = Mutex::new(None);

fn with_player<R>(f: impl FnOnce(&Shared, &mut Player, &mut Option<Sender<()>>) -> R) -> R {
    let mut g = PLAYER.lock().unwrap_or_else(|e| e.into_inner());
    let (shared, player, poller) = g.get_or_insert_with(|| {
        let s = Shared::default();
        let p = Player::new(s.clone());
        (s, p, None)
    });
    f(shared, player, poller)
}

fn cmd_play(mount: String) -> String {
    with_player(|s, p, poller| {
        s.set_target_volume(compute_volume(true, 0.0)); // sane start; tick refines
        s.clear_ticks(); // disarm the watchdog until this play's own first tick lands
        p.play(&mount);
        // Don't spawn (or churn) a title poller for a mount that will never actually play --
        // p.play() already no-ops on an invalid mount, so the poller should too.
        if state::validate_mount(&mount).is_some() {
            if let Some(old) = poller.take() { let _ = old.send(()); } // stop any previous poller
            *poller = Some(titles::spawn_poller(s.clone(), mount.clone()));
        }
    });
    "ok".into()
}

fn cmd_stop() -> String {
    with_player(|_, p, poller| {
        if let Some(old) = poller.take() { let _ = old.send(()); } // stop poller BEFORE p.stop()
        p.stop();
    });
    "ok".into()
}

fn cmd_tick(occupant: i32, distance: f64) -> String {
    with_player(|s, _, _| {
        s.touch_tick();
        s.set_target_volume(compute_volume(occupant == 1, distance as f32));
    });
    "ok".into()
}

fn cmd_status() -> String {
    with_player(|s, _, _| s.state_line())
}

#[arma]
fn init() -> Extension {
    Extension::build()
        .command("play", cmd_play)
        .command("stop", cmd_stop)
        .command("tick", cmd_tick)
        .command("status", cmd_status)
        .finish()
}
