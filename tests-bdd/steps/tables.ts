import type { DataTable } from "@cucumber/cucumber";
import type { SeedBugInput } from "../../tests/fixtures/api.ts";

export function bugFromTable(table: DataTable): SeedBugInput {
  const row = table.rowsHash();
  return {
    title: row.title ?? "",
    description: row.description ?? "",
    priority: row.priority || "Medium",
    status: row.status || "Open",
  };
}
