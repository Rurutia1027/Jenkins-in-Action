import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: "lifecycle.spec.ts",
  use: {
    baseURL:
      process.env.PLAYWRIGHT_TEST_BASE_URL || "http://localhost:8080/api/",
  },
  reporter: [
    ["list"],
    ["junit", { outputFile: "test-results/results.xml" }],
    ["html", { outputFolder: "playwright-report", open: "never" }],
  ],
});
