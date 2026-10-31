import type { ButtonHTMLAttributes, ReactNode } from "react";

import { cn } from "@/lib/utils";

export function Button({
  children,
  className,
  variant = "primary",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost";
  children: ReactNode;
}) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-semibold transition",
        variant === "primary" && "bg-ink text-white hover:bg-moss",
        variant === "secondary" && "bg-sand text-ink hover:bg-[#e1d7c2]",
        variant === "ghost" && "bg-transparent text-ink hover:bg-black/5",
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
}
