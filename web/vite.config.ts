import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// The level catalogue, word bank and scripts are read straight from the Swift package,
// so the iOS and web games always share one copy of the content.
const content = fileURLToPath(new URL("../Packages/LostIslandsCore/Sources/LostIslandsCore/Resources", import.meta.url));

export default defineConfig({
  base: "./",
  resolve: { alias: { "@content": content } },
  server: { fs: { allow: [".."] } },
  test: { include: ["tests/**/*.test.ts"] },
});
