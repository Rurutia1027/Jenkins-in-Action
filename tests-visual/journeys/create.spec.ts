import { test, expect } from "@playwright/test";
import { TITLE_PREFIX, createBugRecipe } from "../../tests/fixtures/recipes";
import { deleteByTitlePrefix } from "../../tests/fixtures/api";
import {
  frozenBug,
  settle,
  snapshot,
  stubBugList,
} from "../helpers/visual";

test.describe("Create journey visuals", () => {
  test.afterEach(async () => {
    await deleteByTitlePrefix(TITLE_PREFIX).catch(() => undefined);
  });

  test("empty list", async ({ page }) => {
    await stubBugList(page, []);
    await page.goto("/");
    await settle(page);
    await expect(page.getByRole("button", { name: "Add New Bug" })).toBeVisible();
    await snapshot(page.getByTestId("bug-list"), "create-empty-list");
  });

  test("add bug modal", async ({ page }) => {
    await stubBugList(page, []);
    await page.goto("/");
    await settle(page);
    await page.getByRole("button", { name: "Add New Bug" }).click();
    await expect(page.getByTestId("add-bug-modal")).toBeVisible();
    await snapshot(page.getByTestId("add-bug-modal"), "create-add-bug-modal");
  });

  test("list after create", async ({ page }) => {
    const list: Array<Record<string, unknown>> = [];
    await stubBugList(page, list);
    await page.goto("/");
    await settle(page);
    await page.getByRole("button", { name: "Add New Bug" }).click();
    await page.fill('input[name="title"]', createBugRecipe.title);
    await page.fill('textarea[name="description"]', createBugRecipe.description);
    await page.selectOption('select[name="priority"]', createBugRecipe.priority);

    list.push(
      frozenBug({
        title: createBugRecipe.title,
        description: createBugRecipe.description,
        priority: createBugRecipe.priority,
      })
    );
    await page.getByRole("button", { name: "Add Bug" }).click();
    await expect(
      page.getByRole("link", { name: createBugRecipe.title })
    ).toBeVisible();
    await snapshot(page.getByTestId("bug-list"), "create-list-after-create", [
      page.getByTestId("bug-id"),
    ]);
  });
});
