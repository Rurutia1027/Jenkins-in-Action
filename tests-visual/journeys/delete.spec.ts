import { test, expect } from "@playwright/test";
import { TITLE_PREFIX, deleteBugRecipe } from "../../tests/fixtures/recipes";
import { createBug, deleteByTitlePrefix } from "../../tests/fixtures/api";
import { frozenBug, settle, snapshot, stubBugList } from "../helpers/visual";

test.describe("Delete journey visuals", () => {
  test.afterEach(async () => {
    await deleteByTitlePrefix(TITLE_PREFIX).catch(() => undefined);
  });

  test("delete confirmation and list after delete", async ({ page }) => {
    const bug = await createBug(deleteBugRecipe);
    const row = frozenBug({
      id: bug.id,
      title: deleteBugRecipe.title,
      description: deleteBugRecipe.description,
      priority: deleteBugRecipe.priority,
    });

    await stubBugList(page, [row]);
    await page.goto("/");
    await settle(page);
    await page.getByRole("button", { name: "Delete" }).click();
    await expect(page.getByTestId("delete-confirm-modal")).toBeVisible();
    await snapshot(
      page.getByTestId("delete-confirm-modal"),
      "delete-confirmation"
    );

    await stubBugList(page, []);
    await page
      .getByTestId("delete-confirm-modal")
      .getByRole("button", { name: "Delete" })
      .click();
    await expect(
      page.getByRole("link", { name: deleteBugRecipe.title })
    ).toHaveCount(0);
    await snapshot(page.getByTestId("bug-list"), "delete-list-after-delete");
  });
});
