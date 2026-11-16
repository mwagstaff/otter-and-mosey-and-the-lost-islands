import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./playtests", timeout: 180_000, retries: 0, workers: 1,
  reporter: [["list"], ["html", { outputFolder: "playtest-report", open: "never" }]],
  use: { baseURL: "http://127.0.0.1:4179/play/lost-islands/", trace: "retain-on-failure", screenshot: "only-on-failure" },
  webServer: { command: "npx vite preview --host 127.0.0.1 --port 4179 --strictPort --outDir dist-playtest --base=/play/lost-islands/", url: "http://127.0.0.1:4179/play/lost-islands/", reuseExistingServer: false },
  projects: [
    { name: "chromium-desktop", use: { browserName: "chromium", viewport: { width: 1280, height: 800 } } },
    { name: "webkit-phone", use: { browserName: "webkit", viewport: { width: 852, height: 393 }, hasTouch: true } },
    ...(process.env.PLAYTEST_FULL ? [{ name: "webkit-tablet", use: { browserName: "webkit" as const, viewport: { width: 1180, height: 820 }, hasTouch: true } }] : []),
  ],
});
