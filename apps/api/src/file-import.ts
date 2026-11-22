import { readFileSync, statSync } from "node:fs";
import { extname, resolve, sep } from "node:path";

export interface ImportLimits {
  maxBytes: number;
  maxRecords: number;
}

export function resolveImportFile(baseDirectory: string, fileName: string): string {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*\.(json|csv)$/.test(fileName)) {
    throw new Error("Import filename or extension is not allowed");
  }
  const base = resolve(baseDirectory);
  const candidate = resolve(base, fileName);
  if (!candidate.startsWith(`${base}${sep}`))
    throw new Error("Import path escapes the allowed directory");
  return candidate;
}

export function readLimitedImportFile(
  baseDirectory: string,
  fileName: string,
  limits: ImportLimits,
): { extension: ".json" | ".csv"; contents: string } {
  const filePath = resolveImportFile(baseDirectory, fileName);
  const size = statSync(filePath).size;
  if (size > limits.maxBytes) throw new Error("Import file exceeds the configured byte limit");
  const extension = extname(filePath).toLowerCase();
  if (extension !== ".json" && extension !== ".csv") throw new Error("Unsupported import type");
  const contents = readFileSync(filePath, "utf8");
  const records =
    extension === ".json" ? 1 : Math.max(0, contents.trim().split(/\r?\n/).length - 1);
  if (records > limits.maxRecords) throw new Error("Import file exceeds the record limit");
  return { extension, contents };
}
