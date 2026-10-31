import { listWiki } from "@/lib/web";
import { getSession } from "@/lib/session";
import { dateShort } from "@/lib/format";
import { wikiCatMeta, catAnchor } from "@/lib/wikiCategories";
import WikiIndex, { type WikiGroup } from "@/components/WikiIndex";

export const metadata = { title: "Wiki" };

export default async function WikiIndexPage() {
  const [pages, session] = await Promise.all([listWiki(), getSession()]);
  const isEditor = !!session && (session.adminLevel >= 3 || session.isOwner);

  // group by category (query is ordered by category, title)
  const groups: WikiGroup[] = [];
  for (const p of pages) {
    let g = groups.find((x) => x.category === p.category);
    if (!g) {
      const meta = wikiCatMeta(p.category);
      g = { category: p.category, subtitle: meta.subtitle, icon: meta.icon, anchor: catAnchor(p.category), pages: [] };
      groups.push(g);
    }
    g.pages.push({ slug: p.slug, title: p.title, description: p.description, updated: dateShort(p.updated_at) });
  }

  return <WikiIndex groups={groups} isEditor={isEditor} />;
}
