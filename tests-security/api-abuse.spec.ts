import { test, expect } from "@playwright/test";

test.describe("API abuse — invalid and missing input", () => {
  test("create without a title is rejected", async ({ request }) => {
    const res = await request.post("bugs", {
      data: { description: "no title", priority: "Low", status: "Open" },
    });
    expect(res.status()).toBe(400);
    const body = await res.json();
    expect(body.error).toMatch(/title/i);
  });

  test("create with invalid JSON is rejected", async ({ request }) => {
    const res = await request.post("bugs", {
      headers: { "Content-Type": "application/json" },
      data: "{not-json",
    });
    expect(res.status()).toBe(400);
  });

  test("get with a non-numeric id is rejected", async ({ request }) => {
    const res = await request.get("bugs/not-a-number");
    expect(res.status()).toBe(400);
  });

  test("get of a missing bug is not found", async ({ request }) => {
    const res = await request.get("bugs/999999");
    expect(res.status()).toBe(404);
  });

  test("update of a missing bug is not found", async ({ request }) => {
    const res = await request.put("bugs/999999", {
      data: {
        title: "gone",
        description: "nope",
        status: "Open",
        priority: "Low",
      },
    });
    expect(res.status()).toBe(404);
  });

  test("comment without author is rejected", async ({ request }) => {
    const created = await request.post("bugs", {
      data: {
        title: "SEC abuse fixture",
        description: "for comment validation",
        priority: "Low",
        status: "Open",
      },
    });
    expect(created.ok()).toBeTruthy();
    const bug = await created.json();

    const res = await request.post(`bugs/${bug.id}/comments`, {
      data: { content: "no author" },
    });
    expect(res.status()).toBe(400);

    await request.delete(`bugs/${bug.id}`);
  });

  test("comment on a missing bug is not found", async ({ request }) => {
    const res = await request.post("bugs/999999/comments", {
      data: { author: "Ada", content: "orphan" },
    });
    expect([400, 404]).toContain(res.status());
  });
});
