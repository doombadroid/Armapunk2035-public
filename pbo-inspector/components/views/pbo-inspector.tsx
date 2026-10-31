"use client";

import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import {
  Archive,
  Boxes,
  Database,
  FileCode2,
  FolderSearch,
  HardDrive,
  Loader2,
  Search,
  ShieldAlert
} from "lucide-react";

import type { PboSummary } from "@/lib/pbo-inspector";

type ScanResult = {
  sourcePath: string;
  defaultPaths: string[];
  pboFiles: PboSummary[];
  warnings: string[];
};

export function PboInspector() {
  const [source, setSource] = useState("");
  const [query, setQuery] = useState("");
  const [selectedPath, setSelectedPath] = useState<string | null>(null);
  const [result, setResult] = useState<ScanResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function scan() {
    setIsLoading(true);
    setError(null);

    try {
      const params = source.trim() ? `?source=${encodeURIComponent(source.trim())}` : "";
      const response = await fetch(`/api/pbos${params}`);
      const payload = await response.json();

      if (!response.ok) {
        throw new Error(payload.error ?? "Scan failed");
      }

      setResult(payload);
      setSelectedPath(payload.pboFiles[0]?.path ?? null);
    } catch (scanError) {
      setError(scanError instanceof Error ? scanError.message : "Scan failed");
    } finally {
      setIsLoading(false);
    }
  }

  const filtered = useMemo(() => {
    const files = result?.pboFiles ?? [];
    const needle = query.trim().toLowerCase();
    if (!needle) return files;

    return files.filter((pbo) => {
      const haystack = [
        pbo.name,
        pbo.addon,
        pbo.path,
        ...pbo.preview,
        ...pbo.classes.map((item) => `${item.className} ${item.displayName ?? ""}`)
      ].join(" ").toLowerCase();

      return haystack.includes(needle);
    });
  }, [query, result]);

  const selected = filtered.find((pbo) => pbo.path === selectedPath) ?? filtered[0] ?? null;

  return (
    <main className="min-h-screen bg-[#F5F2EA] text-[#18221E]">
      <section className="border-b border-[#D9D2C3] bg-[#ECE6DA]">
        <div className="mx-auto flex max-w-7xl flex-col gap-5 px-4 py-5 sm:px-6 lg:px-8">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <div className="mb-2 flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-[#5E6D64]">
                <Archive className="h-4 w-4" />
                Arma 3 PBO Inspector
              </div>
              <h1 className="font-display text-3xl font-bold text-[#18221E] sm:text-4xl">
                Find the item inside an addon
              </h1>
            </div>
            <div className="grid grid-cols-3 gap-3 text-sm">
              <Stat icon={<Database className="h-4 w-4" />} label="PBOs" value={result?.pboFiles.length ?? 0} />
              <Stat icon={<Boxes className="h-4 w-4" />} label="Items" value={result?.pboFiles.reduce((sum, pbo) => sum + pbo.itemCount, 0) ?? 0} />
              <Stat icon={<HardDrive className="h-4 w-4" />} label="Source" value={result ? "Ready" : "Local"} />
            </div>
          </div>

          <div className="grid gap-3 rounded-lg border border-[#CEC6B6] bg-white p-3 shadow-sm lg:grid-cols-[1fr_auto]">
            <label className="flex min-w-0 items-center gap-3 rounded-md border border-[#D9D2C3] bg-[#FBFAF7] px-3 py-2">
              <FolderSearch className="h-5 w-5 shrink-0 text-[#547166]" />
              <input
                value={source}
                onChange={(event) => setSource(event.target.value)}
                placeholder="Leave blank for default Arma 3 folders, or paste an Addons / workshop / single .pbo path"
                className="w-full bg-transparent text-sm font-medium outline-none placeholder:text-[#8B8172]"
              />
            </label>
            <button
              onClick={scan}
              disabled={isLoading}
              className="inline-flex h-11 items-center justify-center gap-2 rounded-md bg-[#1F6F50] px-5 text-sm font-semibold text-white transition hover:bg-[#185A41] disabled:cursor-not-allowed disabled:opacity-70"
            >
              {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <FolderSearch className="h-4 w-4" />}
              Scan PBOs
            </button>
          </div>

          {(error || result?.warnings.length) && (
            <div className="rounded-md border border-[#DCA764] bg-[#FFF8E8] px-3 py-2 text-sm text-[#684715]">
              {error ?? result?.warnings.join(" ")}
            </div>
          )}
        </div>
      </section>

      <section className="mx-auto grid max-w-7xl gap-4 px-4 py-4 sm:px-6 lg:grid-cols-[390px_1fr] lg:px-8">
        <aside className="min-h-[560px] rounded-lg border border-[#D9D2C3] bg-white">
          <div className="border-b border-[#E2DCCE] p-3">
            <label className="flex h-10 items-center gap-2 rounded-md border border-[#D9D2C3] bg-[#FBFAF7] px-3">
              <Search className="h-4 w-4 text-[#547166]" />
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search item, class, addon, path"
                className="w-full bg-transparent text-sm outline-none placeholder:text-[#8B8172]"
              />
            </label>
          </div>

          <div className="max-h-[70vh] overflow-auto">
            {!result && <EmptyState />}
            {result && filtered.length === 0 && (
              <div className="p-5 text-sm text-[#6F675C]">No PBOs match that search.</div>
            )}
            {filtered.map((pbo) => (
              <button
                key={pbo.path}
                onClick={() => setSelectedPath(pbo.path)}
                className={`block w-full border-b border-[#EEE8DA] px-4 py-3 text-left transition ${
                  selected?.path === pbo.path ? "bg-[#E8F1EC]" : "hover:bg-[#FBFAF7]"
                }`}
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="truncate text-sm font-semibold text-[#18221E]">{pbo.name}</span>
                  <span className="shrink-0 rounded bg-[#E8E1D3] px-2 py-1 text-xs font-semibold text-[#5E5549]">
                    {pbo.itemCount}
                  </span>
                </div>
                <div className="mt-1 truncate text-xs text-[#6F675C]">{pbo.addon}</div>
                <div className="mt-2 flex flex-wrap gap-1">
                  {pbo.preview.slice(0, 3).map((name) => (
                    <span key={name} className="max-w-full truncate rounded bg-[#F2EFE7] px-2 py-1 text-xs text-[#4D5B54]">
                      {name}
                    </span>
                  ))}
                </div>
              </button>
            ))}
          </div>
        </aside>

        <article className="min-h-[560px] rounded-lg border border-[#D9D2C3] bg-white">
          {selected ? <PboDetail pbo={selected} /> : <NoSelection result={result} />}
        </article>
      </section>
    </main>
  );
}

function Stat({ icon, label, value }: { icon: ReactNode; label: string; value: string | number }) {
  return (
    <div className="rounded-md border border-[#D9D2C3] bg-[#FBFAF7] px-3 py-2">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-[#6F675C]">
        {icon}
        {label}
      </div>
      <div className="mt-1 text-lg font-bold text-[#18221E]">{value}</div>
    </div>
  );
}

function PboDetail({ pbo }: { pbo: PboSummary }) {
  const visibleClasses = pbo.classes.slice(0, 80);
  const visibleFiles = pbo.files.slice(0, 100);

  return (
    <div>
      <header className="border-b border-[#E2DCCE] p-5">
        <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
          <div className="min-w-0">
            <div className="mb-2 flex flex-wrap gap-2">
              <Badge>{pbo.configType === "none" ? "No config" : `config.${pbo.configType}`}</Badge>
              <Badge>{formatBytes(pbo.size)}</Badge>
              <Badge>{pbo.fileCount} files</Badge>
            </div>
            <h2 className="truncate font-display text-2xl font-bold">{pbo.name}</h2>
            <p className="mt-1 break-all text-sm text-[#6F675C]">{pbo.path}</p>
          </div>
          {pbo.warnings.length > 0 && (
            <div className="max-w-xl rounded-md border border-[#E5B66E] bg-[#FFF8E8] p-3 text-sm text-[#684715]">
              <div className="mb-1 flex items-center gap-2 font-semibold">
                <ShieldAlert className="h-4 w-4" />
                Parser note
              </div>
              {pbo.warnings.join(" ")}
            </div>
          )}
        </div>
      </header>

      <div className="grid gap-4 p-5 xl:grid-cols-[1fr_320px]">
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-sm font-bold uppercase tracking-wide text-[#5E6D64]">Detected items and classes</h3>
            <span className="text-sm text-[#6F675C]">{pbo.itemCount} found</span>
          </div>
          <div className="overflow-hidden rounded-md border border-[#E2DCCE]">
            <table className="w-full table-fixed text-sm">
              <thead className="bg-[#F2EFE7] text-left text-xs uppercase tracking-wide text-[#5E6D64]">
                <tr>
                  <th className="w-[28%] px-3 py-2">Class</th>
                  <th className="w-[24%] px-3 py-2">Name</th>
                  <th className="w-[18%] px-3 py-2">Category</th>
                  <th className="px-3 py-2">Asset</th>
                </tr>
              </thead>
              <tbody>
                {visibleClasses.length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-3 py-6 text-center text-[#6F675C]">
                      No item classes were detected in this PBO.
                    </td>
                  </tr>
                )}
                {visibleClasses.map((item) => (
                  <tr key={`${item.category}-${item.className}`} className="border-t border-[#EEE8DA]">
                    <td className="truncate px-3 py-2 font-mono text-xs">{item.className}</td>
                    <td className="truncate px-3 py-2 font-semibold">{item.displayName ?? "-"}</td>
                    <td className="truncate px-3 py-2 text-[#6F675C]">{item.category}</td>
                    <td className="truncate px-3 py-2 text-xs text-[#6F675C]">
                      {item.model || item.picture || item.icon || "-"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <aside className="space-y-4">
          <Panel title="Likely identity" icon={<FileCode2 className="h-4 w-4" />}>
            <div className="space-y-2">
              {pbo.preview.length === 0 && <p className="text-sm text-[#6F675C]">Scan a config-bearing PBO to see item names here.</p>}
              {pbo.preview.map((name) => (
                <div key={name} className="rounded-md bg-[#F2EFE7] px-3 py-2 text-sm font-semibold">
                  {name}
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Files inside" icon={<Archive className="h-4 w-4" />}>
            <div className="max-h-64 space-y-1 overflow-auto font-mono text-xs text-[#4D5B54]">
              {visibleFiles.map((file) => (
                <div key={`${file.offset}-${file.name}`} className="truncate rounded bg-[#FBFAF7] px-2 py-1">
                  {file.name}
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Readable strings" icon={<Search className="h-4 w-4" />}>
            <div className="max-h-56 space-y-1 overflow-auto text-xs text-[#4D5B54]">
              {pbo.strings.slice(0, 80).map((value) => (
                <div key={value} className="truncate rounded bg-[#FBFAF7] px-2 py-1">
                  {value}
                </div>
              ))}
            </div>
          </Panel>
        </aside>
      </div>
    </div>
  );
}

function Panel({ title, icon, children }: { title: string; icon: ReactNode; children: ReactNode }) {
  return (
    <section className="rounded-lg border border-[#E2DCCE] p-3">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-[#5E6D64]">
        {icon}
        {title}
      </h3>
      {children}
    </section>
  );
}

function Badge({ children }: { children: ReactNode }) {
  return <span className="rounded bg-[#E8E1D3] px-2 py-1 text-xs font-semibold text-[#5E5549]">{children}</span>;
}

function EmptyState() {
  return (
    <div className="p-5 text-sm text-[#6F675C]">
      Start with a scan. The app checks common Arma 3 Steam folders, or you can paste a specific mod folder or `.pbo` file path.
    </div>
  );
}

function NoSelection({ result }: { result: ScanResult | null }) {
  return (
    <div className="flex min-h-[560px] items-center justify-center p-8 text-center text-[#6F675C]">
      {result ? "No PBO selected." : "Scan your Arma 3 files to inspect addons and identify their items."}
    </div>
  );
}

function formatBytes(bytes: number) {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** index).toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}
