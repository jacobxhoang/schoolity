import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { readFile, writeFile } from "node:fs/promises";
await build({
  absWorkingDir: fileURLToPath(new URL("../..", import.meta.url)),
  entryPoints: ["ios/Parser/district.ts"],
  outfile: "ios/Schoolity/Resources/DistrictParser.js",
  bundle: true,
  format: "iife",
  globalName: "DistrictParser",
  platform: "neutral",
  target: "es2020",
  minify: true,
  legalComments: "eof",
});
const notices = await Promise.all(
  ["parse5", "entities"].map(
    async (name) =>
      `${name}\n${await readFile(new URL(`../../node_modules/${name}/LICENSE`, import.meta.url), "utf8")}`,
  ),
);
await writeFile(
  new URL("../Schoolity/Resources/ThirdPartyNotices.txt", import.meta.url),
  notices.join("\n\n"),
);
