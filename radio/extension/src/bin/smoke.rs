//! Wine/Windows audio smoke test: plays the dev stream for 12 s at full volume.
//! Usage: smoke.exe <mount>   (default: origin)

use maldenradio::{audio::Player, state::Shared};

fn main() {
    let mount = std::env::args().nth(1).unwrap_or_else(|| "origin".into());
    let shared = Shared::default();
    shared.set_target_volume(0.4);
    let mut p = Player::new(shared.clone());
    p.play(&mount);
    for _ in 0..24 {
        std::thread::sleep(std::time::Duration::from_millis(500));
        println!("state: {}", shared.state_line());
    }
    p.stop();
    println!("done");
}
