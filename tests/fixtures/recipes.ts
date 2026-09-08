/** Deterministic visual / BDD data. No Date.now(). */

export const TITLE_PREFIX = "Visual ";
export const BDD_TITLE_PREFIX = "BDD ";

export const createBugRecipe = {
  title: "Visual Create Bug",
  description: "Deterministic description for the create-journey checkpoint.",
  priority: "Medium",
  status: "Open",
};

export const editBugRecipe = {
  title: "Visual Edit Bug",
  description: "Open Medium bug used to open the Edit Bug modal.",
  priority: "Medium",
  status: "Open",
};

export const commentBugRecipe = {
  title: "Visual Comment Bug",
  description: "Bug that already has two comments for the comment checkpoint.",
  priority: "Low",
  status: "Open",
};

export const commentRecipe = [
  { author: "Ada Lovelace", content: "First visual comment" },
  { author: "Grace Hopper", content: "Second visual comment" },
];

export const deleteBugRecipe = {
  title: "Visual Delete Bug",
  description: "Bug used for the delete-confirmation checkpoint.",
  priority: "High",
  status: "Open",
};
