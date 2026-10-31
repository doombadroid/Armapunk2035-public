//! Stream playback: HTTP (reqwest blocking) -> minimp3 frames -> cpal output.
//! One background thread per play(); volume is read live from Shared each callback.

use crate::state::{candidate_urls, validate_mount, Shared};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use minimp3::{Decoder, Frame};
use std::io::Read;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::time::Duration;

/// Test/diagnostic helper: fully decode a reader, return (frame_count, sample_count).
pub fn decode_all<R: Read>(r: R) -> (usize, usize) {
    let mut d = Decoder::new(r);
    let (mut frames, mut samples) = (0usize, 0usize);
    while let Ok(Frame { data, .. }) = d.next_frame() {
        frames += 1;
        samples += data.len();
    }
    (frames, samples)
}

pub struct Player {
    shared: Shared,
    stop_flag: Arc<AtomicBool>,
    handle: Option<std::thread::JoinHandle<()>>,
}

impl Player {
    pub fn new(shared: Shared) -> Self {
        Self { shared, stop_flag: Arc::new(AtomicBool::new(false)), handle: None }
    }

    pub fn stop(&mut self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            // Bounded join, not a blocking h.join(): the stream thread can be parked in a
            // network read for up to its own 15 s stall bound (see stream_loop's client
            // timeout), and joining unconditionally here would freeze the game thread for that
            // whole span. Poll is_finished() in 50 ms slices instead, for at most 500 ms total;
            // if it's still running past that, detach (drop the handle without joining) rather
            // than keep waiting -- stop_flag is already set, so the thread notices and exits on
            // its own within its 15 s bound regardless. A detached zombie thread alive for at
            // most ~15 s beats hanging the caller (the game thread) for that same span.
            let mut done = false;
            for _ in 0..10 {
                if h.is_finished() { done = true; break; }
                std::thread::sleep(Duration::from_millis(50));
            }
            if done { let _ = h.join(); } else { drop(h); } // drop without join = detach
        }
        self.shared.set_playing(None);
        self.shared.set_now_playing("");
    }

    pub fn play(&mut self, mount: &str) {
        let Some(mount) = validate_mount(mount) else { return };
        if self.shared.state_line().starts_with(&format!("playing|{mount}|")) { return; } // same mount: no-op
        self.stop();
        self.stop_flag = Arc::new(AtomicBool::new(false));
        let (shared, stop) = (self.shared.clone(), self.stop_flag.clone());
        shared.set_playing(Some(mount.clone()));
        shared.set_now_playing(&mount);
        self.handle = Some(std::thread::spawn(move || {
            if let Err(e) = stream_loop(&mount, &shared, &stop) {
                shared.set_now_playing(&format!("error: {e}"));
                shared.set_playing(None);
            }
        }));
    }
}

impl Drop for Player {
    fn drop(&mut self) { self.stop(); }
}

fn stream_loop(mount: &str, shared: &Shared, stop: &Arc<AtomicBool>) -> Result<(), String> {
    // Connect-phase bound + per-read stall bound -- deliberately NO whole-request timeout.
    // reqwest::blocking has no read_timeout() (that knob only exists on the async builder;
    // blocking never wires it up). Its own ClientBuilder::timeout() is the closest available
    // substitute: blocking::Response::read() re-derives the deadline (Instant::now() + d)
    // fresh on every call (see blocking::wait::timeout), so as long as it's only ever set here
    // -- never overridden per-request via RequestBuilder::timeout() -- it behaves as a
    // resetting per-read stall bound rather than one fixed cumulative deadline. That's what
    // previously killed every stream ~8s in: the per-request .timeout(8s) fed the exact same
    // mechanism but its short window meant any single read gap over 8s tripped it.
    let client = reqwest::blocking::Client::builder()
        .connect_timeout(Duration::from_secs(8))
        .timeout(Duration::from_secs(15))
        .build()
        .map_err(|e| e.to_string())?;

    // try hosts in order (dev first, then live)
    let mut resp = None;
    for url in candidate_urls(mount) {
        if stop.load(Ordering::Relaxed) { return Ok(()); } // stop() during the probe phase
        match client.get(&url).send() {
            // Content-Type gate: a dev-box catch-all (SPA server, redirect, etc.) can answer
            // 200 text/html on localhost:8000 and would otherwise win as the "reachable" host
            // with no fallback to the real stream. Require it to actually look like audio.
            Ok(r) if r.status().is_success()
                && r.headers()
                    .get(reqwest::header::CONTENT_TYPE)
                    .and_then(|v| v.to_str().ok())
                    .map_or(false, |ct| ct.starts_with("audio/")) =>
            {
                resp = Some(r);
                break;
            }
            _ => continue,
        }
    }
    let resp = resp.ok_or("no reachable stream host")?;

    // audio device
    let host = cpal::default_host();
    let device = host.default_output_device().ok_or("no output device")?;
    let config = device.default_output_config().map_err(|e| e.to_string())?;
    let out_rate = (config.sample_rate().0 as usize).max(1);
    let out_ch = config.channels() as usize;

    // decoded-sample ring buffer (mpsc as SPSC queue of f32 interleaved at out_ch)
    let (tx, rx) = mpsc::sync_channel::<f32>(out_rate * out_ch); // ~1 s of buffer
    let vol_shared = shared.clone();
    let stream = device
        .build_output_stream(
            &config.into(),
            move |buf: &mut [f32], _| {
                let v = vol_shared.volume_bits();
                for s in buf.iter_mut() {
                    *s = rx.try_recv().unwrap_or(0.0) * v;
                }
            },
            |e| eprintln!("maldenradio cpal error: {e}"),
            None,
        )
        .map_err(|e| e.to_string())?;
    stream.play().map_err(|e| e.to_string())?;

    // decode loop: naive nearest-sample rate conversion + channel mapping to the device layout
    let mut dec = Decoder::new(resp);
    while !stop.load(Ordering::Relaxed) {
        // tick watchdog: SQF ticks ~3x/s while this stream should be audible. Mission death
        // (abort/disconnect) kills the SQF loop without a `stop` -- ticks cease, we shut off
        // instead of serenading the main menu. Unarmed until the first tick (smoke harness).
        if shared.tick_stale(5_000) {
            shared.set_playing(None);
            shared.set_now_playing("");
            return Ok(());
        }
        let Frame { data, sample_rate, channels, .. } = dec.next_frame().map_err(|e| e.to_string())?;
        let (in_rate, in_ch) = (sample_rate as usize, channels.max(1));
        let in_frames = data.len() / in_ch;
        let out_frames = in_frames * out_rate / in_rate.max(1);
        for of in 0..out_frames {
            let inf = of * in_rate / out_rate;
            for c in 0..out_ch {
                let s = data[inf * in_ch + (c % in_ch)] as f32 / 32768.0;
                // Interruptible send: a blocking send() would hang here if the device stalls
                // and the callback stops draining, which would in turn hang stop()'s join()
                // on the game thread. Loop on try_send so stop_flag / a disconnected receiver
                // can always break out.
                let mut sample = s;
                loop {
                    match tx.try_send(sample) {
                        Ok(()) => break,
                        Err(mpsc::TrySendError::Full(v)) => {
                            if stop.load(Ordering::Relaxed) { return Ok(()); }
                            sample = v;
                            std::thread::sleep(Duration::from_millis(5));
                        }
                        Err(mpsc::TrySendError::Disconnected(_)) => return Ok(()), // output stream gone
                    }
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn fixture_decodes_to_samples() {
        let data: &[u8] = include_bytes!("../tests/fixtures/tone.mp3");
        let (frames, samples) = super::decode_all(std::io::Cursor::new(data));
        assert!(frames > 10, "expected >10 mp3 frames, got {frames}");
        assert!(samples > 20_000, "expected >20k samples, got {samples}");
    }
}
