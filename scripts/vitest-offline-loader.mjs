import { pathToFileURL } from "node:url";
import { resolve as resolvePath } from "node:path";

const shimUrl = pathToFileURL(resolvePath("scripts/vitest-offline-shim.mjs")).href;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === "vitest") return { url: shimUrl, shortCircuit: true };
  return nextResolve(specifier, context);
}
