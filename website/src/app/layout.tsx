import type { Metadata } from "next";
import { Michroma, Space_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "sonner";
import NavShell from "@/components/NavShell";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { isAdminPlus, manageableFactions } from "@/lib/factions";
import { pixelAllowed } from "@/lib/pixel/access";

// Whole app is DB-backed and per-request — never statically cache.
export const dynamic = "force-dynamic";

const SITE = process.env.NEXT_PUBLIC_SITE_NAME ?? "Armapunk 2035";

// Self-hosted by next/font at build time (no runtime request to Google): the teaser page's pair.
const michroma = Michroma({ weight: "400", subsets: ["latin"], variable: "--font-michroma", display: "swap" });
const spaceMono = Space_Mono({ weight: ["400", "700"], subsets: ["latin"], variable: "--font-space-mono", display: "swap" });

export const metadata: Metadata = {
  title: { default: `${SITE} · Stats`, template: `${SITE} · %s` },
  description: `${SITE}: Malden 2035 roleplay. Player stats, gangs, leaderboards and the bounty board.`,
  icons: { icon: "/favicon.ico" },
};

// Apply the saved theme before paint to avoid a flash of the default palette.
const THEME_SCRIPT = `(function(){try{var t=localStorage.getItem('lb-theme')||'cyan';document.documentElement.setAttribute('data-theme',t);}catch(e){}})();`;

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getSession();
  // Menu visibility from LIVE rank (authoritative) so promotions take effect
  // immediately, without the user re-logging in. Pages also re-check on access.
  let staff: { whitelist: boolean; logs: boolean; bans: boolean; vpn: boolean; server: boolean; pixel: boolean } | undefined;
  if (session) {
    const powers = await getActorPowers(session.uid);
    staff = {
      whitelist: isAdminPlus(powers) || manageableFactions(powers).length > 0,
      logs: isAdminPlus(powers),
      bans: powers.isOwner || powers.adminlevel >= 1,
      vpn: isAdminPlus(powers),
      server: isAdminPlus(powers), // Senior Admin (>=4) or Owner — server lock/reboot
      pixel: pixelAllowed(session), // Armapunk Pixel closed test: owner only (PIXEL_SPEC.md)
    };
  }
  return (
    <html lang="en" data-theme="cyan" className={`${michroma.variable} ${spaceMono.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="min-h-screen bg-gray-950 text-gray-100">
        {session ? (
          <NavShell session={session} staff={staff}>{children}</NavShell>
        ) : (
          // logged-out: no shell — the gate (proxy) only lets /login render here
          children
        )}
        <Toaster theme="dark" position="bottom-right" richColors />
      </body>
    </html>
  );
}
