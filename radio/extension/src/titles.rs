//! Polls icecast's status-json.xsl for the mount's now-playing title.

use crate::state::Shared;
use std::sync::mpsc::{channel, Sender};
use std::time::Duration;

/// Neutralize characters that would corrupt the broadcast wire format or inject HUD markup:
/// `|` is the wire-format field separator (see radioCfg.hpp); `<`/`>` feed into parseText.
fn sanitize(t: &str) -> String {
    t.replace('|', "/").replace('<', "(").replace('>', ")")
}

pub fn parse_title(json: &str, mount: &str) -> Option<String> {
    let v: serde_json::Value = serde_json::from_str(json).ok()?;
    let sources = &v["icestats"]["source"];
    let list: Vec<&serde_json::Value> = if sources.is_array() {
        sources.as_array().unwrap().iter().collect()
    } else { vec![sources] };
    for s in list {
        let listenurl = s["listenurl"].as_str().unwrap_or("");
        if listenurl.ends_with(&format!("/{mount}")) {
            return s["title"].as_str().map(str::to_string);
        }
    }
    None
}

pub fn spawn_poller(shared: Shared, mount: String) -> Sender<()> {
    let (tx, rx) = channel::<()>();
    std::thread::spawn(move || {
        let hosts = crate::state::candidate_urls("status-json.xsl");
        let client = match reqwest::blocking::Client::builder()
            .connect_timeout(Duration::from_secs(8))
            .timeout(Duration::from_secs(10))
            .build()
        {
            Ok(c) => c,
            Err(_) => return,
        };
        loop {
            match rx.recv_timeout(Duration::from_secs(10)) {
                Ok(()) | Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => return, // stop signal or owner gone
                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
            }
            for url in &hosts {
                if let Ok(r) = client.get(url).send() {
                    if r.status().is_success() {
                        if let Ok(body) = r.text() {
                            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&body) {
                                if !v["icestats"].is_null() {
                                    if let Some(t) = parse_title(&body, &mount) { shared.set_now_playing(&sanitize(&t)); }
                                    break; // right host: icestats present, title absent just means no track yet
                                }
                            }
                        }
                    }
                }
            }
        }
    });
    tx
}

#[cfg(test)]
mod tests {
    #[test]
    fn parses_single_and_multi_source() {
        let multi = r#"{"icestats":{"source":[
            {"listenurl":"http://x:8000/origin","title":"Tone 440"},
            {"listenurl":"http://x:8000/khr","title":"Tone 880"}]}}"#;
        assert_eq!(super::parse_title(multi, "khr").as_deref(), Some("Tone 880"));
        let single = r#"{"icestats":{"source":{"listenurl":"http://x:8000/origin","title":"Solo"}}}"#;
        assert_eq!(super::parse_title(single, "origin").as_deref(), Some("Solo"));
        assert_eq!(super::parse_title(single, "khr"), None);
        assert_eq!(super::parse_title("not json", "origin"), None);
    }

    #[test]
    fn sanitize_neutralizes_markup() {
        assert_eq!(super::sanitize("A|B <i>"), "A/B (i)");
    }
}
