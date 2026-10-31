"use client";

import { toast } from "sonner";

// Reference portal useToast (recovered from the site's shared chunk): `{ success(text, timeout?),
// error(text, timeout? = 8000), info(text, timeout?) }` over a Base UI toast manager. Same
// signature over sonner, the portal's toaster (sanctioned difference, PIXEL_SPEC.md § UI).
const toasts = {
  success: (e: string, t?: number) => {
    toast.success(e, { duration: t });
  },
  error: (e: string, t?: number) => {
    toast.error(e, { duration: t ?? 8e3 });
  },
  info: (e: string, t?: number) => {
    toast.info(e, { duration: t });
  },
};

export function useToast(): typeof toasts {
  return toasts;
}
