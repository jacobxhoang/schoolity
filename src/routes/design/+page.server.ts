import { dev } from "$app/environment";
import { error } from "@sveltejs/kit";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import type { PageServerLoad } from "./$types";

/**
 * The design records kept in `.impeccable` are not app content. They are read
 * from disk only while Schoolity runs on this machine, so nothing from them is
 * bundled into a build and students never see them.
 */
const ROOT = ".impeccable";
const EVALUATION = "evaluation.md";

type Kind = "evaluation" | "critique";

type Record = {
  slug: string;
  kind: Kind;
  title: string;
  meta: string;
  run: number;
  body: string;
};

function split(raw: string) {
  const parts = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  const head = parts?.[1] ?? "";
  const body = (parts?.[2] ?? raw).trim();
  const field = (key: string) =>
    head.match(new RegExp(`^${key}:\\s*(.+)$`, "m"))?.[1]?.trim() ?? "";
  return { field, body };
}

function record(name: string, raw: string, kind: Kind): Record {
  const { field, body } = split(raw);
  const run = Number(field("run") || 0);
  const score = field("total_score");
  const max = field("max_score") || "40";
  const date = field("date");
  return {
    slug: name.replace(/\.md$/, ""),
    kind,
    title: kind === "evaluation" ? "Evaluation" : run ? `Run ${run}` : name,
    meta:
      kind === "evaluation"
        ? "Heuristics, states, accessibility and code review"
        : [score ? `${score}/${max}` : "Not scored", date]
            .filter(Boolean)
            .join(" · "),
    run,
    body,
  };
}

export const load: PageServerLoad = async ({ url }) => {
  if (!dev) error(404, "Not found");
  const directory = join(process.cwd(), ROOT);
  const names = (
    await readdir(join(directory, "critique")).catch(() => [] as string[])
  )
    .filter((name) => name.endsWith(".md"))
    .toSorted((a, b) => a.localeCompare(b));
  const [evaluation, runs] = await Promise.all([
    readFile(join(directory, EVALUATION), "utf8")
      .then((raw) => record(EVALUATION, raw, "evaluation"))
      .catch(() => null),
    Promise.all(
      names.map(async (name) =>
        record(
          name,
          await readFile(join(directory, "critique", name), "utf8"),
          "critique",
        ),
      ),
    ),
  ]);
  runs.sort((a, b) => b.run - a.run || a.slug.localeCompare(b.slug));
  const records = [...(evaluation ? [evaluation] : []), ...runs];
  const selected =
    records.find((entry) => entry.slug === url.searchParams.get("doc")) ??
    records[0];
  return {
    records: records.map((entry) => ({
      slug: entry.slug,
      kind: entry.kind,
      title: entry.title,
      meta: entry.meta,
    })),
    selected: selected?.slug ?? "",
    body: selected?.body ?? "",
  };
};
