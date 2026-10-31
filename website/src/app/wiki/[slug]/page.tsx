import { notFound } from "next/navigation";
import { Pencil } from "lucide-react";
import { Card, Badge, PageHeader } from "@/components/ui";
import Markdown from "@/components/Markdown";
import WikiEditor from "@/components/WikiEditor";
import { getWikiPage } from "@/lib/web";
import { getSession } from "@/lib/session";
import { relative } from "@/lib/format";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  if (slug === "new") return { title: "New Wiki Page" };
  const page = await getWikiPage(slug);
  return { title: page ? `${page.title} · Wiki` : "Wiki" };
}

export default async function WikiPageView({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const session = await getSession();
  const isEditor = !!session && (session.adminLevel >= 3 || session.isOwner);

  // ---- create form ----
  if (slug === "new") {
    if (!isEditor) notFound();
    return (
      <div>
        <PageHeader title="New Wiki Page" back={{ href: "/wiki", label: "Back to Wiki" }} />
        <Card className="p-5">
          <WikiEditor mode="new" />
        </Card>
      </div>
    );
  }

  // ---- view page ----
  const page = await getWikiPage(slug);
  if (!page) notFound();

  return (
    <div>
      <PageHeader title={page.title} back={{ href: "/wiki", label: "Back to Wiki" }} />

      <div className="flex items-center gap-2 mb-4 text-xs text-gray-500">
        <Badge color="th">{page.category}</Badge>
        <span>
          updated by {page.updated_by || "staff"}
          <span className="text-gray-600"> · {relative(page.updated_at)}</span>
        </span>
      </div>

      <Card className="p-6">
        <div className="max-w-3xl text-sm">
          <Markdown>{page.body}</Markdown>
        </div>
      </Card>

      {isEditor && (
        <Card className="p-5 mt-6">
          <h2 className="text-sm font-bold text-th-400 uppercase tracking-widest mb-3 flex items-center gap-2">
            <Pencil className="w-4 h-4" /> Edit page
          </h2>
          <WikiEditor mode="edit" page={{ slug: page.slug, title: page.title, category: page.category, description: page.description ?? "", body: page.body ?? "" }} />
        </Card>
      )}
    </div>
  );
}
