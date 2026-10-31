"use client";

import { useRef, useState } from "react";
import { ImagePlus, Eye, Pencil, Trash2, Save } from "lucide-react";
import { saveWiki, deleteWiki, uploadWikiImage } from "@/lib/actions";
import { render } from "@/components/Markdown";

const INPUT =
  "bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm w-full text-gray-200 placeholder:text-gray-600 focus:outline-none focus:border-th-600 transition";

type Props = {
  mode: "new" | "edit";
  page?: { slug: string; title: string; category: string; description: string; body: string };
};

export default function WikiEditor({ mode, page }: Props) {
  const [body, setBody] = useState(page?.body ?? "");
  const [preview, setPreview] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [err, setErr] = useState("");
  const taRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  function insertAtCursor(text: string) {
    const ta = taRef.current;
    if (!ta) { setBody((b) => b + text); return; }
    const start = ta.selectionStart, end = ta.selectionEnd;
    setBody(body.slice(0, start) + text + body.slice(end));
    requestAnimationFrame(() => { ta.focus(); ta.selectionStart = ta.selectionEnd = start + text.length; });
  }

  async function onFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    setUploading(true); setErr("");
    for (const f of Array.from(files).slice(0, 8)) {
      const fd = new FormData(); fd.append("image", f);
      const res = await uploadWikiImage(fd);
      if (res.url) insertAtCursor(`\n![${f.name.replace(/\.[^.]+$/, "")}](${res.url})\n`);
      else { setErr(res.error || "Upload failed"); break; }
    }
    setUploading(false);
    if (fileRef.current) fileRef.current.value = "";
  }

  return (
    <div className="space-y-3">
      <form action={saveWiki} className="space-y-3">
        <div className="grid gap-3 sm:grid-cols-2">
          <input name="title" required maxLength={160} defaultValue={page?.title} placeholder="Title" className={INPUT} />
          <input name="category" maxLength={48} defaultValue={page?.category} placeholder="Category (e.g. General)" className={INPUT} />
        </div>
        <input name="slug" maxLength={96} defaultValue={page?.slug}
          readOnly={mode === "edit"} placeholder="url-slug (e.g. getting-started)"
          className={`${INPUT} ${mode === "edit" ? "text-gray-500" : ""}`} />
        <input name="description" maxLength={300} defaultValue={page?.description}
          placeholder="Short description (shown on the wiki index cards)" className={INPUT} />

        {/* toolbar */}
        <div className="flex items-center gap-2 flex-wrap">
          <button type="button" onClick={() => fileRef.current?.click()} disabled={uploading}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gray-800 border border-gray-700 text-xs font-bold text-gray-300 hover:border-th-600 hover:text-white transition disabled:opacity-50">
            <ImagePlus className="w-4 h-4" /> {uploading ? "Uploading…" : "Attach image"}
          </button>
          <button type="button" onClick={() => setPreview((p) => !p)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gray-800 border border-gray-700 text-xs font-bold text-gray-300 hover:border-th-600 hover:text-white transition">
            {preview ? <><Pencil className="w-4 h-4" /> Write</> : <><Eye className="w-4 h-4" /> Preview</>}
          </button>
          <span className="text-xs text-gray-600">Markdown: # headings · **bold** · *italic* · ~~strike~~ · `code` · ```blocks``` · - lists · - [ ] tasks · | tables | · &gt; quotes · [links](url) · ![img](url) · ---</span>
          <input ref={fileRef} type="file" accept="image/png,image/jpeg,image/gif,image/webp" multiple className="hidden"
            onChange={(e) => onFiles(e.target.files)} />
        </div>
        {err && <p className="text-xs text-red-400">{err}</p>}

        {preview ? (
          <div className="min-h-[16rem] rounded border border-gray-700 bg-gray-900/50 p-4 text-sm">
            {body.trim()
              ? <div dangerouslySetInnerHTML={{ __html: render(body) }} />
              : <span className="text-gray-600 italic">Nothing to preview yet.</span>}
          </div>
        ) : (
          <textarea ref={taRef} name="body" rows={18} maxLength={50000} value={body}
            onChange={(e) => setBody(e.target.value)} placeholder="Page body (markdown supported)…"
            className={`${INPUT} font-mono`} />
        )}

        <button type="submit"
          className="inline-flex items-center gap-2 px-5 py-2 rounded-lg bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition">
          <Save className="w-4 h-4" /> {mode === "new" ? "Create page" : "Save changes"}
        </button>
      </form>

      {mode === "edit" && page && (
        <form action={deleteWiki} className="pt-2 border-t border-gray-800">
          <input type="hidden" name="slug" value={page.slug} />
          <button type="submit"
            onClick={(e) => { if (!confirm(`Delete the wiki page “${page.title}”? This cannot be undone.`)) e.preventDefault(); }}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-900/30 border border-red-800/50 text-xs font-bold text-red-300 hover:bg-red-900/50 transition">
            <Trash2 className="w-4 h-4" /> Delete this page
          </button>
        </form>
      )}
    </div>
  );
}
