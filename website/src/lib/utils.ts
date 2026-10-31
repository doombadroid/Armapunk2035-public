import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

// shadcn's `cn`: clsx for conditionals, tailwind-merge to resolve conflicting utilities.
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
