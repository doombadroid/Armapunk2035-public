"use client";

import { useRouter } from "next/navigation";
import { LB_CATEGORIES } from "@/lib/leaderboards";

/** Mobile leaderboard metric picker — native <select> that routes on change. */
export default function LbMetricSelect({ value }: { value: string }) {
  const router = useRouter();
  return (
    <select
      value={value}
      onChange={(e) => router.push(`/leaderboard?metric=${e.target.value}`)}
      className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:border-th-500 focus:outline-none"
    >
      {LB_CATEGORIES.map((c) => (
        <optgroup key={c.key} label={c.label}>
          {c.metrics.map((m) => (
            <option key={m.key} value={m.key}>{m.label}</option>
          ))}
        </optgroup>
      ))}
    </select>
  );
}
