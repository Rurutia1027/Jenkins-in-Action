import { expect, type Locator, type Page } from "@playwright/test";

export async function settle(page: Page): Promise<void> {
  await page.waitForLoadState("networkidle");
  await page.evaluate(() => document.fonts.ready);
}

/**
 * Isolate GET /api/bugs so seeded sample rows and leftover E2E bugs
 * do not poison list checkpoints. Other /api/bugs/:id calls continue.
 */
export async function stubBugList(
  page: Page,
  bugs: Array<Record<string, unknown>>
): Promise<void> {
  await page.route(
    (url) => {
      try {
        const path = new URL(url).pathname.replace(/\/$/, "");
        return path === "/api/bugs";
      } catch {
        return false;
      }
    },
    async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(bugs),
        });
        return;
      }
      await route.continue();
    }
  );
}

export async function snapshot(
  locator: Locator,
  name: string,
  mask: Locator[] = []
): Promise<void> {
  await expect(locator).toHaveScreenshot(`${name}.png`, {
    animations: "disabled",
    caret: "hide",
    mask,
  });
}

export function frozenBug(overrides: Record<string, unknown> = {}) {
  return {
    id: 1001,
    title: "Visual Create Bug",
    description: "Deterministic description for the create-journey checkpoint.",
    status: "Open",
    priority: "Medium",
    created_at: "2024-01-15T12:00:00Z",
    updated_at: "2024-01-15T12:00:00Z",
    ...overrides,
  };
}
