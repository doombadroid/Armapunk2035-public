# Armapunk 2035 — Product Context

**Register:** product (app UI that serves the community; design supports the data, it is not the product)

## What it is
A Steam-login-gated stats & community portal for the **Armapunk 2035** Arma 3 **Malden 2035** cyberpunk roleplay server. Players look up their own and others' stats, leaderboards, gangs, territories, the governor election and bounty board. Server staff moderate from the same site: faction whitelisting (Police/Medic ranks), bans (mirrored to BattleMetrics), raw player logs, and a live CLANKR anti-cheat feed.

## Users
- **Players** — Arma 3 Malden 2035 regulars. Mixed desktop + **a lot of phone** (checking stats/leaderboards between sessions, on the couch, often at night). Game-literate, impatient, competitive about rankings.
- **Staff** — mods/admins/owner. Need fast moderation surfaces (ban, whitelist, logs) that never leak to players.

## Tone & brand
Gritty, confident, gaming-community. Dark, terminal-adjacent, a little lawless (it's a crime-RP server). The wordmark uses a heavy condensed display face (Impact/Bebas). Accent is **runtime-themeable** (amber default; blue/emerald/rose/violet) — the design must look right in any of them, so accent is a role (`th-*`), never a hardcoded hue.

## Anti-references (do NOT look like these)
Corporate SaaS dashboards, cream-and-navy fintech, healthcare white+teal, generic bootstrap/admin templates, the hero-metric template, identical icon-card grids.

## Strategic principles
1. **Mobile is first-class**, not an afterthought — most casual lookups are on a phone. Nav must be a real drawer, content must reflow to one column cleanly, tap targets ≥40px.
2. **Data density with scan-ability** — leaderboards and stat grids pack a lot in; rank, name, value must be instantly legible.
3. **Anti-meta-game** — activity/log feeds are staff-only; never surface a rival's live movements to players.
4. **Themeable accent** — commit to one accent role used deliberately (Restrained-to-Committed); semantic colors stay fixed (red=ban/danger, green=online/money, blue=cop, emerald=medic).
