import { test, expect } from "@playwright/test";
import {
  TITLE_PREFIX,
  commentBugRecipe,
  commentRecipe,
} from "../../tests/fixtures/recipes";
import {
  addComment,
  createBug,
  deleteByTitlePrefix,
} from "../../tests/fixtures/api";
import { settle, snapshot } from "../helpers/visual";

test.describe("Comment journey visuals", () => {
  test.afterEach(async () => {
    await deleteByTitlePrefix(TITLE_PREFIX).catch(() => undefined);
  });

  test("detail comment section", async ({ page }) => {
    const bug = await createBug(commentBugRecipe);
    for (const comment of commentRecipe) {
      await addComment(bug.id, comment);
    }

    await page.goto(`/bugs/${bug.id}`);
    await settle(page);
    await expect(page.getByText(commentRecipe[0].content)).toBeVisible();
    await expect(page.getByText(commentRecipe[1].content)).toBeVisible();
    await snapshot(page.getByTestId("comment-section"), "comment-section", [
      page.getByTestId("comment-timestamp"),
    ]);
  });
});
