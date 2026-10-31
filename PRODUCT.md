# Product

## Register

product

## Users

The server owner plus a small closed beta of Arma 3 Altis Life players. They meet this UI **in-game, mid-session, usually under pressure**: buying rifles while a cop cruiser rolls up, managing a stuffed inventory mid-heist, glancing at a notification while driving. Interaction is mouse-driven dialogs drawn over a live 3D world. Displays span 1080p to ultrawide 21:9. They are experienced gamers fluent in dense game UIs, currently served an inconsistent, dated interface.

Job to be done: **buy/sell gear and vehicles fast, manage inventory without friction, and read urgent state (cop near, money in, wanted level) at a glance** without breaking immersion.

## Product Purpose

LooneyBin is a self-hosted crime-and-economy roleplay sandbox on Arma 3. The UI layer, shops, inventory, and HUD notifications, is the connective tissue between the player and every system: economy, crime, gang, and cop. It must feel like one premium, cohesive product layered over a gritty world, legible at a glance, fast to operate, and unmistakably LooneyBin rather than default-Arma or a generic dark dashboard.

## Brand Personality

Confident, illicit, precise. The voice is a black-market concierge: dry, street-smart, economical. Never cute, never a meme, never a bank teller.

## Anti-references

- Garish gold-on-black (the current look). Reads cheap and loud.
- Murky, heavy, low-contrast dark panels. Oppressive and hard to read.
- Generic dark-dashboard AI slop: the safe sans, rounded cards everywhere, a colored accent rail on every list item, no identity.
- Cluttered HUDs with many colors and bars competing for attention.
- The retired "radio station colors" metaphor.
- Category reflexes to avoid: navy-and-gold fintech, neon-on-black, cream + serif + terracotta.

## Design Principles

1. **Glanceable under fire.** A player mid-chase reads the essential number or state in under a second. Hierarchy is ruthless; one thing dominates each surface.
2. **Premium, not heavy.** Dark but elevated and airy. Contrast and negative space carry the design, never murk.
3. **One system, many contexts.** Every shop, inventory, and HUD is visibly the same product. Consistency beats per-screen novelty.
4. **Restraint with a single signature.** One confident accent. Semantic color is reserved strictly for meaning (money, danger, faction), never decoration.
5. **Illicit, not cartoonish.** The crime fantasy shows through tone, materials, and detail, never through gimmick textures or jokey copy.

## Accessibility & Inclusion

The engine constrains us (bitmap fonts, fixed dialog coordinates), but target WCAG-AA contrast for all text on panels. Never encode critical state in color alone; pair it with an icon, label, or position (buy/sell must read without color). Support ultrawide via overscan and 1080p as the floor. Assume some players are colorblind; do not lean on red/green alone.
