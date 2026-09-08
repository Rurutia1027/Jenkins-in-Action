import { Given, type DataTable } from "@cucumber/cucumber";
import { createBug, getHealth } from "../../tests/fixtures/api.ts";
import type { BugTrackerWorld } from "./world.ts";
import { bugFromTable } from "./tables.ts";

Given("the API is healthy", async function () {
  const health = await getHealth();
  if (health.status !== "ok") {
    throw new Error(`API health was ${JSON.stringify(health)}`);
  }
});

Given("a bug exists:", async function (this: BugTrackerWorld, table: DataTable) {
  this.bug = await createBug(bugFromTable(table));
});
