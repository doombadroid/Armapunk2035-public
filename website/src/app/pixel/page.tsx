import { notFound } from "next/navigation";
import { Geist, Geist_Mono } from "next/font/google";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import { getSession } from "@/lib/session";
import { pixelAllowed } from "@/lib/pixel/access";
import staticsJson from "@/lib/pixel/reference/statics.json";
import PixelGame from "@/components/pixel/PixelGame";
import type { Statics } from "@/components/pixel/types";

export const dynamic = "force-dynamic";
// The reference page's <title> (next/head there, page metadata here); `absolute` keeps the
// portal's "Armapunk 2035 · %s" template off it. Brand string per PIXEL_SPEC.md.
export const metadata = { title: { absolute: "Armapunk Pixel — Altis" } };

// The reference's fonts (its --font-geist-sans / --font-geist-mono), self-hosted by next/font and
// scoped to the page wrapper so the rest of the portal keeps Space Mono.
const geist = Geist({ subsets: ["latin"], variable: "--font-geist-sans", display: "swap" });
const geistMono = Geist_Mono({ subsets: ["latin"], variable: "--font-geist-mono", display: "swap" });

// The `statics` page prop: the reference's SSR data tables, verbatim (lane S serves the same file).
const statics = staticsJson as Statics;

export default async function PixelPage() {
  const session = await getSession();
  if (!pixelAllowed(session)) notFound();
  // `pixel-theme` carries the reference's semantic tokens; `dark` selects its dark set (the portal
  // is dark). Drop `dark` for the reference's light theme.
  return (
    <div className={`pixel-theme dark ${geist.variable} ${geistMono.variable}`}>
      <NuqsAdapter>
        <PixelGame statics={statics} canAccessCasino={true} />
      </NuqsAdapter>
    </div>
  );
}
