"use client";

import { useEffect, useState } from "react";
import { FMT_DATE, FMT_DATETIME, FMT_TIME, type DateInput } from "./fmt";

// Reference portal DateValue (work/ui/DateValue.jsx), verbatim: formats on the client only,
// so the server never renders a locale-dependent string.

export default function DateValue({
  value,
  format = "date",
  opts,
  className,
  fallback = "-",
}: {
  value: DateInput;
  format?: "date" | "datetime" | "time";
  opts?: Intl.DateTimeFormatOptions;
  className?: string;
  fallback?: string;
}) {
  const [l, u] = useState<string | null>(null);
  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect -- reference portal component: formats on the client after mount so the server never renders a locale string */
    let t: string;
    if (!value) return void u(fallback);
    const r = new Date(value);
    switch (format) {
      case "datetime":
        t = r.toLocaleString(undefined, opts ?? FMT_DATETIME);
        break;
      case "time":
        t = r.toLocaleTimeString(undefined, opts ?? FMT_TIME);
        break;
      default:
        t = r.toLocaleDateString(undefined, opts ?? FMT_DATE);
    }
    u(t);
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [value, format, opts, fallback]);
  return null === l ? null : className ? <span className={className}>{l}</span> : <>{l}</>;
}
