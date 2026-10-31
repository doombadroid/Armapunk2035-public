import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// The `@/` alias tsconfig.json declares, so tests can import modules that reach `@/lib/db`.
export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
});
