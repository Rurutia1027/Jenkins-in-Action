import { test, expect } from "@playwright/test";

test("homepage shows Add New Bug", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("button", { name: "Add New Bug" })).toBeVisible();
});
