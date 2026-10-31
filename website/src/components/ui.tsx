import Link from "next/link";
import { initials } from "@/lib/format";

// Literal class strings (Tailwind v4 scans source — no dynamic interpolation).
const BADGE: Record<string, string> = {
  red: "bg-red-900/30 text-red-300 border-red-700/40",
  orange: "bg-orange-900/30 text-orange-300 border-orange-700/40",
  amber: "bg-amber-900/30 text-amber-300 border-amber-700/40",
  green: "bg-green-900/30 text-green-300 border-green-700/40",
  emerald: "bg-emerald-900/30 text-emerald-300 border-emerald-700/40",
  blue: "bg-blue-900/30 text-blue-300 border-blue-700/40",
  sky: "bg-sky-900/30 text-sky-300 border-sky-700/40",
  violet: "bg-violet-900/30 text-violet-300 border-violet-700/40",
  gray: "bg-gray-800 text-gray-300 border-gray-700/50",
  th: "bg-th-900/30 text-th-300 border-th-700/40",
};

export function Badge({
  children, color = "gray", className = "",
}: { children: React.ReactNode; color?: string; className?: string }) {
  return (
    <span
      className={`inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-bold border ${
        BADGE[color] ?? BADGE.gray
      } ${className}`}
    >
      {children}
    </span>
  );
}

export function Card({
  children, className = "",
}: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`bg-gray-900 border border-th-700/30 rounded-xl ${className}`}>
      {children}
    </div>
  );
}

export function SectionCard({
  title, icon, right, children,
}: {
  title: string; icon?: React.ReactNode; right?: React.ReactNode; children: React.ReactNode;
}) {
  return (
    <Card className="p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-bold text-th-400 uppercase tracking-widest flex items-center gap-2">
          {icon}
          {title}
        </h3>
        {right}
      </div>
      {children}
    </Card>
  );
}

export function StatRow({
  label, value,
}: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between items-center py-2 border-b border-gray-800 last:border-0">
      <span className="text-xs text-gray-500 uppercase tracking-wider">{label}</span>
      <span className="text-sm text-gray-200">{value}</span>
    </div>
  );
}

export function Avatar({
  name, size = 14, src,
}: { name: string; size?: number; src?: string | null }) {
  const px = size * 4;
  return (
    <div
      className="rounded-full bg-th-700/30 border border-th-600/40 flex items-center justify-center font-black text-th-400 shrink-0 overflow-hidden"
      style={{ width: px, height: px, fontSize: px / 2.6 }}
    >
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt={name} className="w-full h-full object-cover" />
      ) : (
        initials(name)
      )}
    </div>
  );
}

export function PlayerLink({
  uid, name, className = "",
}: { uid: string; name: string; className?: string }) {
  return (
    <Link
      href={`/player-detail?playerid=${uid}`}
      className={`text-th-400 hover:text-th-300 transition font-semibold ${className}`}
    >
      {name}
    </Link>
  );
}

export function Empty({ children }: { children: React.ReactNode }) {
  return (
    <div className="px-5 py-6 text-center text-gray-500 text-sm italic">{children}</div>
  );
}

export function PageHeader({
  title, back,
}: { title: string; back?: { href: string; label: string } }) {
  return (
    <div className="flex items-center justify-between mb-6">
      <h1 className="text-2xl font-black text-th-400">{title}</h1>
      {back && (
        <Link
          href={back.href}
          className="inline-flex items-center gap-1 text-th-500 hover:text-th-400 font-semibold transition text-sm"
        >
          ← {back.label}
        </Link>
      )}
    </div>
  );
}
