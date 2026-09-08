import { After, Before } from "@cucumber/cucumber";
import { deleteByTitlePrefix } from "../../tests/fixtures/api.ts";
import { BDD_TITLE_PREFIX } from "../../tests/fixtures/recipes.ts";
import "./world.ts";

Before(async function () {
  await deleteByTitlePrefix(BDD_TITLE_PREFIX);
});

After(async function () {
  await deleteByTitlePrefix(BDD_TITLE_PREFIX);
});
