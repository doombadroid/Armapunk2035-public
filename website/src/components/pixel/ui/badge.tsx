"use client";

import { mergeProps } from "@base-ui/react/merge-props";
import { useRender } from "@base-ui/react/use-render";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

// Reference portal Badge (recovered from the site's shared chunk: shadcn Base UI Badge plus the
// portal's colour variants), verbatim.

const badgeVariants = cva(
  "group/badge inline-flex h-5 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-all focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3!",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
        secondary: "bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80",
        destructive:
          "bg-destructive/10 text-destructive focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-destructive/20",
        outline: "border-border text-foreground [a]:hover:bg-muted [a]:hover:text-muted-foreground",
        ghost: "hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50",
        link: "text-primary-emphasis underline-offset-4 hover:underline",
        red: "border-red-500/20 bg-red-500/10 text-red-700 dark:border-red-700/40 dark:bg-red-900/30 dark:text-red-300",
        green: "border-green-500/20 bg-green-500/10 text-green-700 dark:border-green-700/40 dark:bg-green-900/30 dark:text-green-300",
        blue: "border-blue-500/20 bg-blue-500/10 text-blue-700 dark:border-blue-700/40 dark:bg-blue-900/30 dark:text-blue-300",
        amber: "border-amber-500/20 bg-amber-500/10 text-amber-700 dark:border-amber-700/40 dark:bg-amber-900/30 dark:text-amber-300",
        yellow: "border-yellow-500/20 bg-yellow-500/10 text-yellow-700 dark:border-yellow-700/40 dark:bg-yellow-900/30 dark:text-yellow-300",
        purple: "border-purple-500/20 bg-purple-500/10 text-purple-700 dark:border-purple-700/40 dark:bg-purple-900/30 dark:text-purple-300",
        orange: "border-orange-500/20 bg-orange-500/10 text-orange-700 dark:border-orange-700/40 dark:bg-orange-900/30 dark:text-orange-300",
        indigo: "border-indigo-500/20 bg-indigo-500/10 text-indigo-700 dark:border-indigo-700/40 dark:bg-indigo-900/30 dark:text-indigo-300",
        teal: "border-teal-500/20 bg-teal-500/10 text-teal-700 dark:border-teal-700/40 dark:bg-teal-900/30 dark:text-teal-300",
        violet: "border-violet-500/20 bg-violet-500/10 text-violet-700 dark:border-violet-700/40 dark:bg-violet-900/30 dark:text-violet-300",
        accent: "border-primary/40 bg-primary/15 text-primary-emphasis",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

function Badge({ className, variant = "default", render, ...props }: useRender.ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return useRender({
    defaultTagName: "span",
    props: mergeProps<"span">(
      {
        className: cn(badgeVariants({ variant }), className),
      },
      props,
    ),
    render,
    state: {
      slot: "badge",
      variant,
    },
  });
}

export { Badge, badgeVariants };
