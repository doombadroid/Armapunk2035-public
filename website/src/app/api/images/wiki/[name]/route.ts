import { readFile } from "fs/promises";
import path from "path";

// Serves wiki page image attachments from the persistent uploads dir.
export async function GET(_req: Request, ctx: { params: Promise<{ name: string }> }) {
  const { name } = await ctx.params;
  if (!/^[A-Za-z0-9._-]+$/.test(name) || name.includes("..")) {
    return new Response("Bad request", { status: 400 });
  }
  try {
    const buf = await readFile(path.join(process.cwd(), "uploads", "wiki", name));
    const ext = name.split(".").pop()?.toLowerCase();
    const type = ext === "png" ? "image/png" : ext === "gif" ? "image/gif" : ext === "webp" ? "image/webp" : "image/jpeg";
    return new Response(new Uint8Array(buf), {
      headers: { "Content-Type": type, "Cache-Control": "public, max-age=31536000, immutable" },
    });
  } catch {
    return new Response("Not found", { status: 404 });
  }
}
