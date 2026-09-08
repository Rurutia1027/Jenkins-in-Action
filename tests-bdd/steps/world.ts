import { World, setWorldConstructor, type IWorldOptions } from "@cucumber/cucumber";
import type { SeedBug, SeedComment } from "../../tests/fixtures/api.ts";

export class BugTrackerWorld extends World {
  bug?: SeedBug;
  comments: SeedComment[] = [];
  lastStatus?: number;
  lastError?: string;

  constructor(options: IWorldOptions) {
    super(options);
  }
}

setWorldConstructor(BugTrackerWorld);
