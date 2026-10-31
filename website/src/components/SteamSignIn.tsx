import Link from "next/link";

const STEAM_BLUE = "bg-[#1b2838] hover:bg-[#2a3f5a] border border-[#66c0f4]/30";

/** The one Steam sign-in control: login page, public home header and hero CTA all use it. */
export default function SteamSignIn({ className = "", compact = false }: { className?: string; compact?: boolean }) {
  const size = compact ? "gap-2 px-3 py-1.5 rounded-lg text-sm" : "gap-3 px-5 py-3 rounded-xl";
  return (
    <Link
      href="/api/auth/login"
      className={`inline-flex items-center justify-center ${size} ${STEAM_BLUE} text-white font-semibold transition ${className}`}
    >
      <svg viewBox="0 0 24 24" className={compact ? "w-4 h-4" : "w-5 h-5"} fill="currentColor" aria-hidden="true"> <path d="M11.98 0C5.66 0 .48 4.88.02 11.06l6.44 2.66a3.4 3.4 0 0 1 1.9-.59l2.87-4.16v-.06a4.54 4.54 0 0 1 4.54-4.54 4.54 4.54 0 0 1 4.53 4.54 4.54 4.54 0 0 1-4.53 4.54h-.11l-4.1 2.93a3.4 3.4 0 0 1-6.76.55L.46 14.5A12 12 0 0 0 11.98 24c6.62 0 11.99-5.37 11.99-12S18.6 0 11.98 0zM7.54 18.21l-1.47-.61a2.55 2.55 0 0 0 1.32 1.26 2.56 2.56 0 0 0 3.34-1.38 2.56 2.56 0 0 0 0-1.96 2.56 2.56 0 0 0-1.38-1.39 2.56 2.56 0 0 0-1.95-.02l1.52.63a1.88 1.88 0 0 1-1.44 3.47zm10.49-7.62a3.03 3.03 0 0 0 3.02-3.02 3.03 3.03 0 0 0-3.02-3.03 3.03 3.03 0 0 0-3.02 3.03 3.03 3.03 0 0 0 3.02 3.02zm0-4.54a1.52 1.52 0 0 1 0 3.03 1.52 1.52 0 0 1 0-3.03z" /> </svg>
      Sign in with Steam
    </Link>
  );
}
