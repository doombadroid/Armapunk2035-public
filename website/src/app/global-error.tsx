"use client";

// Root error boundary — replaces the blank white screen on any client/layout
// error with a readable message + digest so issues are diagnosable.
export default function GlobalError({
  error, reset,
}: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <html lang="en">
      <body style={{ background: "#030712", color: "#f3f4f6", fontFamily: "ui-sans-serif, system-ui, sans-serif", minHeight: "100vh", margin: 0, display: "flex", alignItems: "center", justifyContent: "center", padding: "2rem" }}>
        <div style={{ maxWidth: 480, textAlign: "center" }}>
          <h1 style={{ fontSize: 22, fontWeight: 800, margin: "0 0 8px" }}>Something went wrong</h1>
          <p style={{ color: "#9ca3af", fontSize: 14, margin: "0 0 6px" }}>{error?.message || "A client-side error occurred."}</p>
          {error?.digest && <p style={{ color: "#6b7280", fontSize: 12, fontFamily: "monospace", margin: "0 0 16px" }}>digest: {error.digest}</p>}
          <button onClick={() => reset()} style={{ background: "#4f46e5", color: "#fff", border: 0, borderRadius: 8, padding: "8px 16px", fontWeight: 700, cursor: "pointer" }}>Reload</button>
          <p style={{ color: "#4b5563", fontSize: 12, marginTop: 16 }}>If this persists, hard-refresh with Ctrl+Shift+R.</p>
        </div>
      </body>
    </html>
  );
}
