import Link from "next/link";
import { Search } from "lucide-react";
import { Card, Avatar, PlayerLink, Badge, PageHeader, Empty } from "@/components/ui";
import { listPlayers, searchPlayers, type PlayerListItem } from "@/lib/queries";
import { fetchSteamProfiles } from "@/lib/steam";
import { copRank, medicRank } from "@/lib/ranks";
import { commas, relative } from "@/lib/format";

export const metadata = { title: "Players" };

const PER_PAGE = 50;

const SORTS: { key: string; label: string }[] = [
  { key: "recent", label: "Recent" },
  { key: "civ", label: "Civilian XP" },
  { key: "cop", label: "Police XP" },
  { key: "med", label: "Trauma Team XP" },
  { key: "wealth", label: "Wealth" },
];

function PlayerCard({ p, avatar }: { p: PlayerListItem; avatar?: string | null }) {
  const cop = p.copLevel > 0 ? copRank(p.copLevel) : null;
  const medic = p.medicLevel > 0 ? medicRank(p.medicLevel) : null;
  return (
    <Card className="p-4 flex items-center gap-3">
      <Avatar name={p.name} size={11} src={avatar} />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2 flex-wrap">
          <PlayerLink uid={p.uid} name={p.name} className="text-sm truncate" />
          {cop && <Badge color="blue">{cop}</Badge>}
          {medic && <Badge color="emerald">{medic}</Badge>}
        </div>
        {p.gangName && (
          <p className="text-xs text-gray-500 truncate mt-0.5">{p.gangName.trim()}</p>
        )}
        <div className="flex items-center gap-2 mt-1 text-xs text-gray-600">
          <span className="font-mono text-gray-400">{commas(p.civExp)} XP</span>
          <span className="text-gray-700">·</span>
          <span>{relative(p.lastSeen)}</span>
        </div>
      </div>
    </Card>
  );
}

export default async function PlayersPage({
  searchParams,
}: { searchParams: Promise<{ q?: string; sort?: string; page?: string }> }) {
  const sp = await searchParams;
  const q = (sp.q ?? "").trim();
  const sort = (sp.sort as "recent" | "civ" | "cop" | "med" | "wealth") || "recent";
  const page = Math.max(0, Number(sp.page || 0) || 0);

  let players: PlayerListItem[];
  let total = 0;
  let paginated = false;

  if (q) {
    players = await searchPlayers(q, 60);
  } else {
    const res = await listPlayers(page, PER_PAGE, sort);
    players = res.items;
    total = res.total;
    paginated = true;
  }

  const avatars = await fetchSteamProfiles(players.map((p) => p.uid));

  const hasPrev = paginated && page > 0;
  const hasNext = paginated && (page + 1) * PER_PAGE < total;

  return (
    <div>
      <PageHeader title="Players" />

      {/* search */}
      <form method="get" className="mb-4">
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              name="q"
              defaultValue={q}
              placeholder="Search players by name or Steam ID…"
              className="w-full bg-gray-900 border border-th-700/30 rounded-xl pl-9 pr-3 py-2 text-sm text-gray-200 placeholder-gray-600 outline-none focus:border-th-600"
            />
          </div>
          <button
            type="submit"
            className="px-4 py-2 rounded-xl bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold hover:bg-th-600/30 transition"
          >
            Search
          </button>
        </div>
      </form>

      {/* sort tabs (hidden while searching) */}
      {!q && (
        <div className="flex flex-wrap gap-1.5 mb-5">
          {SORTS.map((s) =>
            s.key === sort ? (
              <span
                key={s.key}
                className="px-3 py-1.5 rounded-lg text-xs font-bold bg-th-600/20 border border-th-700/40 text-th-300"
              >
                {s.label}
              </span>
            ) : (
              <Link
                key={s.key}
                href={`/players?sort=${s.key}`}
                className="px-3 py-1.5 rounded-lg text-xs font-bold bg-gray-900 border border-gray-800 text-gray-400 hover:text-gray-200 hover:border-gray-700 transition"
              >
                {s.label}
              </Link>
            )
          )}
        </div>
      )}

      {q && (
        <p className="text-xs text-gray-500 mb-3">
          {players.length} result{players.length === 1 ? "" : "s"} for &ldquo;{q}&rdquo;
        </p>
      )}

      {/* grid */}
      {players.length === 0 ? (
        <Card className="p-2">
          <Empty>{q ? "No players matched your search." : "No players found."}</Empty>
        </Card>
      ) : (
        <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))" }}>
          {players.map((p) => (
            <PlayerCard key={p.uid} p={p} avatar={avatars.get(p.uid)?.avatar} />
          ))}
        </div>
      )}

      {/* pagination */}
      {paginated && (hasPrev || hasNext) && (
        <div className="flex items-center justify-between mt-6">
          {hasPrev ? (
            <Link
              href={`/players?sort=${sort}&page=${page - 1}`}
              className="px-4 py-2 rounded-lg text-sm font-bold bg-gray-900 border border-gray-800 text-gray-300 hover:border-gray-700 transition"
            >
              ← Prev
            </Link>
          ) : (
            <span />
          )}
          <span className="text-xs text-gray-600">Page {page + 1}</span>
          {hasNext ? (
            <Link
              href={`/players?sort=${sort}&page=${page + 1}`}
              className="px-4 py-2 rounded-lg text-sm font-bold bg-gray-900 border border-gray-800 text-gray-300 hover:border-gray-700 transition"
            >
              Next →
            </Link>
          ) : (
            <span />
          )}
        </div>
      )}
    </div>
  );
}
