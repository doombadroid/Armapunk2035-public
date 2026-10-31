import { redirect } from "next/navigation";
import { getSession } from "@/lib/session";

export const dynamic = "force-dynamic";
import SteamSignIn from "@/components/SteamSignIn";

export const metadata = { title: "Sign in" };

const SITE = process.env.NEXT_PUBLIC_SITE_NAME ?? "Armapunk 2035";

export default async function LoginPage() {
  const session = await getSession();
  if (session) redirect("/");

  return (
    <div className="min-h-screen flex items-center justify-center px-4 bg-gradient-to-b from-gray-950 via-gray-900 to-gray-950">
      <div className="w-full max-w-md">
        <div className="bg-gray-900 border border-th-700/30 rounded-2xl p-8 sm:p-10 shadow-2xl text-center">
          <div className="mx-auto mb-6 w-16 h-16 rounded-2xl bg-th-600/20 border border-th-500/30 flex items-center justify-center">
            <span className="brand-font text-2xl text-th-400">LB</span>
          </div>
          <h1 className="brand-font text-4xl text-white tracking-wide">{SITE.toUpperCase()}</h1>
          <p className="text-gray-400 mt-2 text-sm">
            Malden 2035: player stats, gangs, leaderboards and more.
          </p>

          <SteamSignIn className="mt-8 w-full" />

          <p className="text-gray-600 text-xs mt-6">
            You must sign in with Steam to view stats, gangs, tickets and more.
          </p>
        </div>
        <p className="text-center text-gray-700 text-xs mt-4">
          We only read your public Steam ID. No password is shared with us.
        </p>
      </div>
    </div>
  );
}
