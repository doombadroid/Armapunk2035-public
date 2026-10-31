import { Home, Tag } from "lucide-react";
import { Card, PageHeader } from "@/components/ui";
import HouseMap from "@/components/HouseMap";
import { getHousesForSale } from "@/lib/queries";
import { money } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "Homes for Sale" };

export default async function HomesForSalePage() {
  const houses = await getHousesForSale();
  const cheapest = houses.length ? houses[houses.length - 1].price : 0;
  const dearest = houses.length ? houses[0].price : 0;

  return (
    <div>
      <PageHeader title="Homes for Sale" />

      <Card className="p-4 mb-5">
        <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-gray-400">
          <span className="flex items-center gap-2"><Home className="w-4 h-4 text-th-400" /> {houses.length} listed</span>
          {houses.length > 0 && (
            <span className="flex items-center gap-2"><Tag className="w-4 h-4 text-th-400" /> {money(cheapest)} – {money(dearest)}</span>
          )}
          <span className="flex items-center gap-3 text-xs ml-auto">
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-emerald-500" /> &lt; $2M</span>
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-amber-500" /> $2–4M</span>
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-rose-500" /> $4M+</span>
          </span>
        </div>
        <p className="text-xs text-gray-600 mt-2">
          Tap a marker or list row for price, seller &amp; grid reference, then head there in-game to buy.
        </p>
      </Card>

      <HouseMap houses={houses} />
    </div>
  );
}
