const apiBase = () =>
  (process.env.BUGTRACKER_API_URL || "http://localhost:8080").replace(
    /\/$/,
    ""
  );

export type SeedBug = {
  id: number;
  title: string;
  description: string;
  status: string;
  priority: string;
};

export type SeedBugInput = {
  title: string;
  description: string;
  priority: string;
  status?: string;
};

export type SeedCommentInput = {
  author: string;
  content: string;
};

export type SeedComment = {
  id: number;
  bugId: number;
  author: string;
  content: string;
  createdAt?: string;
};

export type WriteResult<T> = {
  ok: boolean;
  status: number;
  body: T | { error?: string } | null;
};

async function readError(res: Response): Promise<string> {
  try {
    const body = await res.text();
    return body || res.statusText;
  } catch {
    return res.statusText;
  }
}

export async function getHealth(): Promise<{ status: string }> {
  const res = await fetch(`${apiBase()}/api/health`);
  if (!res.ok) {
    throw new Error(`getHealth failed (${res.status}): ${await readError(res)}`);
  }
  return res.json();
}

export async function createBug(input: SeedBugInput): Promise<SeedBug> {
  const result = await createBugResult(input);
  if (!result.ok || !result.body || !("id" in result.body)) {
    const err =
      result.body && "error" in result.body ? result.body.error : result.status;
    throw new Error(`createBug failed (${result.status}): ${err}`);
  }
  return result.body as SeedBug;
}

export async function createBugResult(
  input: SeedBugInput
): Promise<WriteResult<SeedBug>> {
  const res = await fetch(`${apiBase()}/api/bugs`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title: input.title,
      description: input.description,
      priority: input.priority,
      status: input.status ?? "Open",
    }),
  });
  const body = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, body };
}

export async function getBug(id: number): Promise<SeedBug | null> {
  const res = await fetch(`${apiBase()}/api/bugs/${id}`);
  if (res.status === 404) {
    return null;
  }
  if (!res.ok) {
    throw new Error(`getBug failed (${res.status}): ${await readError(res)}`);
  }
  return res.json();
}

export async function findBugByTitle(title: string): Promise<SeedBug | undefined> {
  const bugs = await listBugs();
  return bugs.find((bug) => bug.title === title);
}

export async function updateBug(
  id: number,
  input: SeedBugInput
): Promise<SeedBug> {
  const res = await fetch(`${apiBase()}/api/bugs/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title: input.title,
      description: input.description,
      priority: input.priority,
      status: input.status ?? "Open",
    }),
  });
  if (!res.ok) {
    throw new Error(`updateBug failed (${res.status}): ${await readError(res)}`);
  }
  return res.json();
}

export async function addComment(
  bugId: number,
  input: SeedCommentInput
): Promise<SeedComment> {
  const res = await fetch(`${apiBase()}/api/bugs/${bugId}/comments`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!res.ok) {
    throw new Error(
      `addComment failed (${res.status}): ${await readError(res)}`
    );
  }
  return res.json();
}

export async function listComments(bugId: number): Promise<SeedComment[]> {
  const res = await fetch(`${apiBase()}/api/bugs/${bugId}/comments`);
  if (!res.ok) {
    throw new Error(
      `listComments failed (${res.status}): ${await readError(res)}`
    );
  }
  const data = await res.json();
  return Array.isArray(data) ? data : [];
}

export async function deleteBug(id: number): Promise<void> {
  const res = await fetch(`${apiBase()}/api/bugs/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 404) {
    throw new Error(`deleteBug failed (${res.status}): ${await readError(res)}`);
  }
}

export async function listBugs(): Promise<SeedBug[]> {
  const res = await fetch(`${apiBase()}/api/bugs`);
  if (!res.ok) {
    throw new Error(`listBugs failed (${res.status}): ${await readError(res)}`);
  }
  const data = await res.json();
  return Array.isArray(data) ? data : [];
}

/** Visual / BDD titles are prefixed so leftover bbolt rows can be swept. */
export async function deleteByTitlePrefix(prefix: string): Promise<void> {
  const bugs = await listBugs();
  for (const bug of bugs) {
    if (bug.title.startsWith(prefix)) {
      await deleteBug(bug.id);
    }
  }
}
