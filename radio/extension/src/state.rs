//! Shared state + the volume model. The mission never sends URLs — only mount names; the
//! full URL is built here against a hardcoded host allowlist (a hostile mission cannot
//! turn the extension into a generic fetcher).

use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

/// Monotonic milliseconds since first use — the tick-watchdog clock.
fn mono_ms() -> u64 {
    static EPOCH: OnceLock<Instant> = OnceLock::new();
    EPOCH.get_or_init(Instant::now).elapsed().as_millis() as u64
}

pub const MASTER_GAIN: f32 = 0.40;
pub const BYSTANDER_RANGE: f32 = 20.0; // mirrors AP_radioRange
pub const BYSTANDER_ATTEN: f32 = 0.25; // owner 2026-08-02 round 2: quarter volume outside the car
                                       // (half was still too loud), then the distance fade on top

const HOSTS: &[&str] = &[
    "http://127.0.0.1:8000",              // dev
    "https://radio.projectloonybin.com",  // live (cloudflared)
];

/// Mount = 1..=24 chars of [a-z0-9_]. Returns the first-host URL (dev) unless the
/// live host is reachable-preferred at play time (Task 3 tries hosts in order).
pub fn validate_mount(mount: &str) -> Option<String> {
    let ok = !mount.is_empty()
        && mount.len() <= 24
        && mount.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_');
    if ok { Some(mount.to_string()) } else { None }
}

pub fn candidate_urls(mount: &str) -> Vec<String> {
    HOSTS.iter().map(|h| format!("{h}/{mount}")).collect()
}

pub fn compute_volume(occupant: bool, distance: f32) -> f32 {
    let duck = if occupant {
        1.0
    } else {
        BYSTANDER_ATTEN * (1.0 - distance / BYSTANDER_RANGE).clamp(0.0, 1.0)
    };
    MASTER_GAIN * duck
}

#[derive(Clone, Default)]
pub struct Shared {
    vol_bits: Arc<AtomicU32>,
    title: Arc<Mutex<String>>,
    playing: Arc<Mutex<Option<String>>>, // Some(mount) while a stream thread runs
    tick_ms: Arc<AtomicU64>,             // mono_ms of the last SQF tick; 0 = never ticked
}

impl Shared {
    pub fn set_target_volume(&self, v: f32) { self.vol_bits.store(v.to_bits(), Ordering::Relaxed); }
    pub fn volume_bits(&self) -> f32 { f32::from_bits(self.vol_bits.load(Ordering::Relaxed)) }
    /// SQF calls `tick` ~3x/s while a stream should be audible. When the mission dies (abort,
    /// disconnect, crash-to-menu) nothing sends `stop` -- the ticks just cease. The audio thread
    /// polls tick_stale() so main-menu ghost playback shuts itself off. Never armed until the
    /// first tick (the smoke harness plays tickless and must not be killed).
    pub fn touch_tick(&self) { self.tick_ms.store(mono_ms().max(1), Ordering::Relaxed); }
    pub fn tick_stale(&self, max_ms: u64) -> bool {
        let t = self.tick_ms.load(Ordering::Relaxed);
        t != 0 && mono_ms().saturating_sub(t) > max_ms
    }
    pub fn clear_ticks(&self) { self.tick_ms.store(0, Ordering::Relaxed); }
    pub fn set_now_playing(&self, t: &str) { *self.title.lock().unwrap_or_else(|e| e.into_inner()) = t.to_string(); }
    pub fn now_playing(&self) -> String { self.title.lock().unwrap_or_else(|e| e.into_inner()).clone() }
    pub fn set_playing(&self, m: Option<String>) { *self.playing.lock().unwrap_or_else(|e| e.into_inner()) = m; }
    pub fn state_line(&self) -> String {
        match self.playing.lock().unwrap_or_else(|e| e.into_inner()).clone() {
            Some(m) => format!("playing|{m}|{}", self.now_playing()),
            None => "stopped".into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mount_validation() {
        assert!(validate_mount("origin").is_some());
        assert!(validate_mount("khr_2").is_some());
        assert!(validate_mount("").is_none());
        assert!(validate_mount("Origin").is_none());
        assert!(validate_mount("../etc").is_none());
        assert!(validate_mount("a").is_some());
        assert!(validate_mount(&"x".repeat(25)).is_none());
    }

    #[test]
    fn urls_only_from_allowlist() {
        let urls = candidate_urls("origin");
        assert_eq!(urls, vec![
            "http://127.0.0.1:8000/origin".to_string(),
            "https://radio.projectloonybin.com/origin".to_string(),
        ]);
    }

    #[test]
    fn volume_model() {
        assert_eq!(compute_volume(true, 999.0), MASTER_GAIN);       // occupant never ducks
        assert_eq!(compute_volume(false, 0.0), MASTER_GAIN * BYSTANDER_ATTEN); // stepping out = ATTEN factor, immediately
        assert_eq!(compute_volume(false, 20.0), 0.0);               // fade to zero at range
        assert_eq!(compute_volume(false, 50.0), 0.0);               // never negative
        let mid = compute_volume(false, 10.0);
        assert!((mid - MASTER_GAIN * BYSTANDER_ATTEN * 0.5).abs() < 1e-6);
    }

    #[test]
    fn state_line_roundtrip() {
        let s = Shared::default();
        assert_eq!(s.state_line(), "stopped");
        s.set_playing(Some("origin".into()));
        s.set_now_playing("Tone 440");
        assert_eq!(s.state_line(), "playing|origin|Tone 440");
    }
}
