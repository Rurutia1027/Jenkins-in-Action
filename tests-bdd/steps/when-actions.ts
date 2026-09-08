import { When, type DataTable } from "@cucumber/cucumber";
import {
  addComment,
  createBugResult,
  deleteBug,
  updateBug,
} from "../../tests/fixtures/api.ts";
import type { BugTrackerWorld } from "./world.ts";
import { bugFromTable } from "./tables.ts";

When(
  "a bug is recorded with:",
  async function (this: BugTrackerWorld, table: DataTable) {
    const input = bugFromTable(table);
    const result = await createBugResult(input);
    this.lastStatus = result.status;
    if (result.ok && result.body && "id" in result.body) {
      this.bug = result.body;
      this.lastError = undefined;
    } else {
      this.bug = undefined;
      this.lastError =
        result.body && "error" in result.body
          ? result.body.error
          : `HTTP ${result.status}`;
    }
  }
);

When(
  "the bug is updated to:",
  async function (this: BugTrackerWorld, table: DataTable) {
    if (!this.bug) {
      throw new Error("No bug in world; Given a bug exists first");
    }
    this.bug = await updateBug(this.bug.id, bugFromTable(table));
  }
);

When("comments are added:", async function (this: BugTrackerWorld, table: DataTable) {
  if (!this.bug) {
    throw new Error("No bug in world; Given a bug exists first");
  }
  this.comments = [];
  for (const row of table.hashes()) {
    this.comments.push(
      await addComment(this.bug.id, {
        author: row.author,
        content: row.content,
      })
    );
  }
});

When("the bug is deleted", async function (this: BugTrackerWorld) {
  if (!this.bug) {
    throw new Error("No bug in world; Given a bug exists first");
  }
  await deleteBug(this.bug.id);
});
