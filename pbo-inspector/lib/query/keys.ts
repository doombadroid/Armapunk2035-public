export const schedulerKeys = {
  root: ["scheduler"] as const,
  snapshot: (start: string) => [...schedulerKeys.root, "snapshot", start] as const,
  coverage: (departmentId: string, start: string, end: string) =>
    [...schedulerKeys.root, "coverage", departmentId, start, end] as const,
  pay: (departmentId: string, start: string, end: string) =>
    [...schedulerKeys.root, "pay", departmentId, start, end] as const
};
