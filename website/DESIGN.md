# Armapunk 2035 — Design System

## Theme
**Dark, always.** Scene: a player slouched on the couch at 1am checking if they're still #1 on the wealth board, or a mod triaging a CLANKR flag mid-raid. Bright UI would be hostile in that context, and the server's crime-RP identity is nocturnal. Dark is forced by the scene, not by category reflex.

## Color
- **Surfaces:** Tailwind's `gray-700..950` are re-tinted in `globals.css` toward the brand's cool blue-black (OKLCH hue 230, chroma ~0.012): bg `gray-950` (oklch 12%), cards `gray-900`, borders `gray-800` / `th-700/30`. Never pure `#000`/`#fff`.
- **Accent (`th-*`):** runtime-switchable role, **default cyan** (oklch 79% 0.15 200 at 400 ≈ the teaser's `#05d9e8`); amber/blue/emerald/rose/violet still selectable. Used Restrained→Committed: section titles, links, primary actions, brand. Mapped per-theme to CSS vars in `globals.css` (`--th-50..950`).
- **Semantic (fixed, not themed):** red = ban/danger/CLANKR-high; orange = warning/demote; green = online/money/whitelist; emerald = medic; blue = cop/info; violet = beta; gold/silver/bronze = leaderboard top-3 trophies.
- Strategy: **Restrained** on dense data views (one accent ≤ ~15%), **Committed** on the hero/login.

## Typography
- **Body/UI:** system sans stack (`ui-sans-serif, system-ui, …`). The two webfonts are bundled at build time by next/font, so there is still no runtime font request.
- **Wordmark/hero:** `.brand-font` = **Michroma** (next/font, self-hosted), one weight, `letter-spacing 0.08em`, uppercase. Wide geometric display for identity moments only (wordmark, home hero, login); never labels, buttons or data.
- **Data:** `.tabular-nums` renders in **Space Mono** at 0.95em (ids, money, ranks, timestamps).
- Hierarchy by scale + weight: page titles `text-2xl/3xl font-black`, section labels `text-sm font-bold uppercase tracking-widest`, body `text-sm`, meta `text-xs text-gray-500/600`. Tabular-nums for all stats.

## Spacing & layout
- Container `max-w-6xl`/`7xl` `mx-auto px-4`. Section rhythm `space-y-6` / `pb-10`.
- Cards: `bg-gray-900 border border-th-700/30 rounded-xl`. No nested cards. No side-stripe borders.
- **Responsive:** single fixed left sidebar (desktop) that becomes an off-canvas drawer < `md`; main is `md:ml-56` (or `ml-16` collapsed), `ml-0` on mobile. Grids collapse to 1 col on phone. Tap targets ≥ 40px.

## Motion
Ease-out only (`ease-out` / quart-ish), 200–300ms. Drawer slides on `transform`. No bounce. Respect `prefers-reduced-motion`.

## Components (existing)
`Card`, `SectionCard` (icon + uppercase title + right slot), `StatRow` (label left / value right), `Badge` (semantic color map), `Avatar` (Steam img or initials), `PlayerLink`, `Collapsible`, `RankCard`/leaderboard rows (trophy top-3). Toasts via `sonner` (dark).
