import { Then } from "@cucumber/cucumber";
import { findBugByTitle, getBug, listComments } from "../../tests/fixtures/api.ts";
import type { BugTrackerWorld } from "./world.ts";

Then(
  "the bug {string} exists",
  async function (this: BugTrackerWorld, title: string) {
    const found = await findBugByTitle(title);
    if (!found) {
      throw new Error(`Expected bug titled "${title}" to exist`);
    }
    this.bug = found;
  }
);

Then(
  "the bug {string} does not exist",
  async function (this: BugTrackerWorld, title: string) {
    const found = await findBugByTitle(title);
    if (found) {
      throw new Error(`Expected bug titled "${title}" to be gone`);
    }
    if (this.bug) {
      const byId = await getBug(this.bug.id);
      if (byId) {
        throw new Error(`Expected bug id ${this.bug.id} to return 404`);
      }
    }
  }
);

Then("its status is {string}", async function (this: BugTrackerWorld, status: string) {
  if (!this.bug) {
    throw new Error("No bug in world");
  }
  const fresh = await getBug(this.bug.id);
  if (!fresh || fresh.status !== status) {
    throw new Error(
      `Expected status "${status}", got "${fresh?.status ?? "missing"}"`
    );
  }
  this.bug = fresh;
});

Then(
  "its priority is {string}",
  async function (this: BugTrackerWorld, priority: string) {
    if (!this.bug) {
      throw new Error("No bug in world");
    }
    const fresh = await getBug(this.bug.id);
    if (!fresh || fresh.priority !== priority) {
      throw new Error(
        `Expected priority "${priority}", got "${fresh?.priority ?? "missing"}"`
      );
    }
    this.bug = fresh;
  }
);

Then(
  "its description is {string}",
  async function (this: BugTrackerWorld, description: string) {
    if (!this.bug) {
      throw new Error("No bug in world");
    }
    const fresh = await getBug(this.bug.id);
    if (!fresh || fresh.description !== description) {
      throw new Error(
        `Expected description "${description}", got "${fresh?.description ?? "missing"}"`
      );
    }
    this.bug = fresh;
  }
);

Then("the recording is rejected", async function (this: BugTrackerWorld) {
  if (this.lastStatus === undefined || this.lastStatus < 400) {
    throw new Error(
      `Expected a 4xx recording failure, got HTTP ${this.lastStatus ?? "none"}`
    );
  }
});

Then(
  "the bug has {int} comments",
  async function (this: BugTrackerWorld, count: number) {
    if (!this.bug) {
      throw new Error("No bug in world");
    }
    const comments = await listComments(this.bug.id);
    if (comments.length !== count) {
      throw new Error(`Expected ${count} comments, got ${comments.length}`);
    }
    this.comments = comments;
  }
);

Then(
  "a comment by {string} says {string}",
  async function (this: BugTrackerWorld, author: string, content: string) {
    if (!this.bug) {
      throw new Error("No bug in world");
    }
    const comments = await listComments(this.bug.id);
    const match = comments.find(
      (comment) => comment.author === author && comment.content === content
    );
    if (!match) {
      throw new Error(`No comment by "${author}" saying "${content}"`);
    }
  }
);
