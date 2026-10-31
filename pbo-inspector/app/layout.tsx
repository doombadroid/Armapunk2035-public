import type { Metadata } from "next";
import type { ReactNode } from "react";

import "@/app/globals.css";
import { AppQueryProvider } from "@/lib/query/provider";

export const metadata: Metadata = {
  title: "Arma 3 PBO Inspector",
  description: "A local addon browser for inspecting Arma 3 PBO files and item configs."
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AppQueryProvider>{children}</AppQueryProvider>
      </body>
    </html>
  );
}
