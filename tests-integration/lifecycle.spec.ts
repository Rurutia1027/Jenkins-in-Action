import { test, expect } from "@playwright/test";

/**
 * Out-of-process integration: HTTP client → running API → bbolt.
 * One chain. Not per-endpoint contract checks (those live in tests-api).
 */
test("bug and comment persist through the live API", async ({ request }) => {
  const title = `INT wire ${Date.now()}`;

  const created = await request.post("bugs", {
    data: {
      title,
      description: "Must round-trip through bbolt",
      status: "Open",
      priority: "Medium",
    },
  });
  expect(created.status()).toBe(201);
  const bug = await created.json();
  expect(bug.id).toEqual(expect.any(Number));

  const listed = await request.get("bugs");
  expect(listed.ok()).toBeTruthy();
  const bugs = await listed.json();
  expect(bugs.some((row: { title: string }) => row.title === title)).toBeTruthy();

  const got = await request.get(`bugs/${bug.id}`);
  expect(got.ok()).toBeTruthy();
  expect((await got.json()).title).toBe(title);

  const updated = await request.put(`bugs/${bug.id}`, {
    data: {
      title,
      description: "Updated via integration chain",
      status: "In Progress",
      priority: "High",
    },
  });
  expect(updated.ok()).toBeTruthy();
  expect((await updated.json()).status).toBe("In Progress");

  const commented = await request.post(`bugs/${bug.id}/comments`, {
    data: { author: "Ada", content: "Seen in bbolt" },
  });
  expect(commented.status()).toBe(201);

  const comments = await request.get(`bugs/${bug.id}/comments`);
  expect(comments.ok()).toBeTruthy();
  const body = await comments.json();
  expect(body).toEqual(
    expect.arrayContaining([
      expect.objectContaining({ author: "Ada", content: "Seen in bbolt" }),
    ])
  );

  const deleted = await request.delete(`bugs/${bug.id}`);
  expect(deleted.ok()).toBeTruthy();
  expect((await request.get(`bugs/${bug.id}`)).status()).toBe(404);
});
