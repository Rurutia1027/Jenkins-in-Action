import { test, expect } from "@playwright/test";
import { TITLE_PREFIX, editBugRecipe } from "../../tests/fixtures/recipes";
import { createBug, deleteByTitlePrefix } from "../../tests/fixtures/api";
import { settle, snapshot } from "../helpers/visual";

test.describe("Edit journey visuals", () => {
  test.afterEach(async () => {
    await deleteByTitlePrefix(TITLE_PREFIX).catch(() => undefined);
  });

  test("detail page", async ({ page }) => {
    const bug = await createBug(editBugRecipe);
    await page.goto(`/bugs/${bug.id}`);
    await settle(page);
    await expect(page.getByRole("heading", { name: editBugRecipe.title })).toBeVisible();
    await snapshot(page.getByTestId("bug-detail"), "edit-detail-page", [
      page.getByTestId("bug-id-value"),
    ]);
  });

  test("edit bug modal", async ({ page }) => {
    const bug = await createBug(editBugRecipe);
    await page.goto(`/bugs/${bug.id}`);
    await settle(page);
    await page.getByRole("button", { name: "Edit Bug" }).click();
    await expect(page.getByTestId("edit-bug-form")).toBeVisible();
    await snapshot(page.getByTestId("edit-bug-modal"), "edit-bug-modal");
  });
});
