"use client";

import Link from "next/link";
import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./button";

// Reference portal Pagination: work/ui/PaginationBase.jsx (shadcn primitives), pageWindow.jsx
// and Pagination.jsx (the {page,totalPages,onPage,label,className} component), verbatim.

export function pageWindow(page: number, totalPages: number): number[] {
  if (totalPages <= 1) return [];
  const r = Math.min(5, totalPages),
    n = Math.max(1, Math.min(Math.max(page, 3), totalPages - 2) - 2);
  return Array.from({ length: r }, (e, t) => n + t).filter((e) => e <= totalPages);
}

function PaginationRoot({ className, ...props }: React.ComponentProps<"nav">) {
  return <nav role="navigation" aria-label="pagination" data-slot="pagination" className={cn("mx-auto flex w-full justify-center", className)} {...props} />;
}

function PaginationContent({ className, ...props }: React.ComponentProps<"ul">) {
  return <ul data-slot="pagination-content" className={cn("flex items-center gap-0.5", className)} {...props} />;
}

function PaginationItem({ ...props }: React.ComponentProps<"li">) {
  return <li data-slot="pagination-item" {...props} />;
}

type PaginationLinkProps = {
  className?: string;
  isActive?: boolean;
  size?: React.ComponentProps<typeof Button>["size"];
  href?: string;
  disabled?: boolean;
  children?: React.ReactNode;
} & Omit<React.HTMLAttributes<HTMLElement>, "className" | "children">;

function PaginationLink({ className, isActive, size = "icon", href, disabled, ...props }: PaginationLinkProps) {
  const c = {
    "aria-current": isActive ? ("page" as const) : undefined,
    "data-slot": "pagination-link",
    "data-active": isActive,
  };
  return (
    <Button
      variant={isActive ? "outline" : "ghost"}
      size={size}
      className={cn(className)}
      disabled={disabled}
      nativeButton={undefined === href && undefined}
      render={undefined !== href ? <Link href={href} {...c} {...props} /> : <button type="button" {...c} {...props} />}
    />
  );
}

function PaginationPrevious({ className, text = "Previous", ...props }: PaginationLinkProps & { text?: string }) {
  return (
    <PaginationLink aria-label="Go to previous page" size="default" className={cn("pl-1.5!", className)} {...props}>
      <ChevronLeftIcon data-icon="inline-start" />
      <span className="hidden sm:block">{text}</span>
    </PaginationLink>
  );
}

function PaginationNext({ className, text = "Next", ...props }: PaginationLinkProps & { text?: string }) {
  return (
    <PaginationLink aria-label="Go to next page" size="default" className={cn("pr-1.5!", className)} {...props}>
      <span className="hidden sm:block">{text}</span>
      <ChevronRightIcon data-icon="inline-end" />
    </PaginationLink>
  );
}

export default function Pagination({
  page,
  totalPages,
  onPage,
  loading = false,
  label,
  hasNext = false,
  className = "",
}: {
  page: number;
  totalPages: number;
  onPage: (page: number) => void;
  loading?: boolean;
  label?: React.ReactNode;
  hasNext?: boolean;
  className?: string;
}) {
  const d = totalPages > 0,
    c = page > 1,
    f = d ? page < totalPages : !!hasNext,
    h = pageWindow(page, totalPages);
  return (
    <div className={`flex items-center justify-between gap-2 flex-wrap ${className}`}>
      <span className="text-xs text-foreground-subtle">
        {d ? `Page ${page} of ${totalPages}` : `Page ${page}`}
        {label && (
          <span className="ml-1">
            {"· "}
            {label}
          </span>
        )}
      </span>
      <PaginationRoot className="mx-0 w-auto justify-end">
        <PaginationContent>
          <PaginationItem>
            <PaginationPrevious text="Prev" disabled={!c || loading} onClick={() => onPage(page - 1)} />
          </PaginationItem>
          {h.map((r) => (
            <PaginationItem key={r}>
              <PaginationLink isActive={r === page} disabled={loading} onClick={() => onPage(r)}>
                {r}
              </PaginationLink>
            </PaginationItem>
          ))}
          <PaginationItem>
            <PaginationNext disabled={!f || loading} onClick={() => onPage(page + 1)} />
          </PaginationItem>
        </PaginationContent>
      </PaginationRoot>
    </div>
  );
}
