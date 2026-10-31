import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center py-24 text-center">
      <h1 className="text-6xl font-black text-th-500 brand-font">404</h1>
      <p className="text-gray-400 mt-2">That page or record doesn&apos;t exist.</p>
      <Link href="/" className="mt-6 px-4 py-2 rounded-lg bg-th-600/20 border border-th-500/30 text-th-300 hover:bg-th-600/30 transition text-sm font-semibold">
        Back home
      </Link>
    </div>
  );
}
