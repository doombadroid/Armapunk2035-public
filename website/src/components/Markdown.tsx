// Minimal, dependency-free markdown renderer for trusted (staff-authored) wiki content.
// HTML is escaped first, then a safe subset is applied: headings (1-6), ordered/unordered
// lists, task lists, bold/italic/strikethrough, inline + fenced code, links, IMAGES,
// blockquotes, tables, horizontal rules, and paragraphs. URLs are restricted to https(s)
// or same-origin (/…) so no javascript:/data: can slip through.

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const URL_OK = "(?:https?:\\/\\/[^\\s)]+|\\/[^\\s)]+)"; // absolute http(s) OR same-origin path

function inline(s: string): string {
  let t = esc(s);
  // images first (![alt](src)) — before links, since the syntaxes overlap
  t = t.replace(new RegExp(`!\\[([^\\]]*)\\]\\((${URL_OK})\\)`, "g"),
    (_m, alt, src) => `<img src="${src}" alt="${alt}" loading="lazy" class="max-w-full h-auto rounded-lg border border-gray-700 my-2" />`);
  t = t.replace(/`([^`]+)`/g, '<code class="bg-gray-800 text-th-300 px-1 py-0.5 rounded text-[0.85em]">$1</code>');
  t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  t = t.replace(/~~([^~]+)~~/g, "<del>$1</del>");
  t = t.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  t = t.replace(new RegExp(`\\[([^\\]]+)\\]\\((${URL_OK})\\)`, "g"),
    '<a href="$2" target="_blank" rel="noopener noreferrer" class="text-th-400 hover:text-th-300 underline">$1</a>');
  return t;
}

const isSep = (l: string) => /^\s*\|?[\s:|-]*-[-\s:|]*\|?\s*$/.test(l) && l.includes("-");
const cells = (r: string) => r.replace(/^\s*\|/, "").replace(/\|\s*$/, "").split("|").map((c) => c.trim());

export function render(md: string): string {
  const lines = (md ?? "").replace(/\r\n/g, "\n").split("\n");
  const out: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (/^\s*$/.test(line)) { i++; continue; }

    // fenced code block
    if (/^\s*```/.test(line)) {
      const buf: string[] = [];
      i++;
      while (i < lines.length && !/^\s*```/.test(lines[i])) { buf.push(lines[i]); i++; }
      i++; // consume closing fence
      out.push(`<pre class="bg-gray-900 border border-gray-800 rounded-lg p-3 my-3 overflow-x-auto"><code class="text-[0.85em] text-gray-300 whitespace-pre">${esc(buf.join("\n"))}</code></pre>`);
      continue;
    }

    // table: header row with | and a separator line below
    if (line.includes("|") && i + 1 < lines.length && isSep(lines[i + 1])) {
      const head = cells(line);
      i += 2;
      const rows: string[][] = [];
      while (i < lines.length && lines[i].includes("|") && lines[i].trim() !== "") { rows.push(cells(lines[i])); i++; }
      const th = head.map((c) => `<th class="border border-gray-700 px-3 py-1.5 text-left font-bold text-th-300">${inline(c)}</th>`).join("");
      const trs = rows.map((r) => `<tr>${r.map((c) => `<td class="border border-gray-800 px-3 py-1.5 text-gray-300">${inline(c)}</td>`).join("")}</tr>`).join("");
      out.push(`<div class="overflow-x-auto my-3"><table class="border-collapse text-sm w-full"><thead><tr>${th}</tr></thead><tbody>${trs}</tbody></table></div>`);
      continue;
    }

    // horizontal rule
    if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) { out.push('<hr class="border-gray-700 my-4"/>'); i++; continue; }

    // headings 1-6
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      const lvl = h[1].length;
      const sizes = ["text-2xl", "text-xl", "text-lg", "text-base", "text-sm", "text-xs"];
      out.push(`<h${lvl} class="${sizes[lvl - 1]} font-bold text-th-400 mt-5 mb-2">${inline(h[2])}</h${lvl}>`);
      i++; continue;
    }

    // unordered / task list
    if (/^\s*[-*]\s+/.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        const txt = lines[i].replace(/^\s*[-*]\s+/, "");
        const task = txt.match(/^\[([ xX])\]\s+(.*)$/);
        if (task) {
          items.push(`<li class="list-none flex items-start gap-2"><input type="checkbox" disabled ${task[1].toLowerCase() === "x" ? "checked" : ""} class="mt-1 accent-th-500"/> <span>${inline(task[2])}</span></li>`);
        } else {
          items.push(`<li>${inline(txt)}</li>`);
        }
        i++;
      }
      out.push(`<ul class="list-disc list-inside space-y-1 my-2 text-gray-300">${items.join("")}</ul>`);
      continue;
    }

    // ordered list
    if (/^\s*\d+\.\s+/.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push(`<li>${inline(lines[i].replace(/^\s*\d+\.\s+/, ""))}</li>`);
        i++;
      }
      out.push(`<ol class="list-decimal list-inside space-y-1 my-2 text-gray-300">${items.join("")}</ol>`);
      continue;
    }

    // blockquote
    if (/^\s*>\s?/.test(line)) {
      out.push(`<blockquote class="border-l-2 border-th-600 pl-3 my-2 text-gray-400 italic">${inline(line.replace(/^\s*>\s?/, ""))}</blockquote>`);
      i++; continue;
    }

    // paragraph (gather until blank or a block starter)
    const para: string[] = [];
    while (i < lines.length && !/^\s*$/.test(lines[i]) &&
           !/^(#{1,6}\s|>\s?|\s*[-*]\s|\s*\d+\.\s|\s*```)/.test(lines[i]) &&
           !/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(lines[i])) {
      para.push(inline(lines[i]));
      i++;
    }
    if (para.length) out.push(`<p class="my-2 text-gray-300 leading-relaxed">${para.join("<br/>")}</p>`);
  }
  return out.join("");
}

export default function Markdown({ children }: { children: string }) {
  return <div dangerouslySetInnerHTML={{ __html: render(children) }} />;
}
