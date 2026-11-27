import {
  constants,
  closeSync,
  fstatSync,
  lstatSync,
  openSync,
  readFileSync,
  realpathSync,
} from "node:fs";
import { extname, resolve, sep } from "node:path";

export interface ImportLimits {
  maxBytes: number;
  maxRecords?: number;
}

export interface ImportedFile {
  extension: ".json" | ".csv";
  contents: string;
  bytes: Buffer;
  path: string;
}

export function resolveImportFile(baseDirectory: string, fileName: string): string {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*\.(json|csv)$/.test(fileName)) {
    throw new Error("Import filename or extension is not allowed");
  }
  const base = realpathSync(resolve(baseDirectory));
  const candidate = resolve(base, fileName);
  if (!candidate.startsWith(`${base}${sep}`)) {
    throw new Error("Import path escapes the allowed directory");
  }
  const entry = lstatSync(candidate);
  if (entry.isSymbolicLink() || !entry.isFile()) {
    throw new Error("Import path must be a regular file and cannot be a symlink");
  }
  const realCandidate = realpathSync(candidate);
  if (!realCandidate.startsWith(`${base}${sep}`)) {
    throw new Error("Import path resolves outside the allowed directory");
  }
  return realCandidate;
}

export function readLimitedImportFile(
  baseDirectory: string,
  fileName: string,
  limits: ImportLimits,
): ImportedFile {
  const filePath = resolveImportFile(baseDirectory, fileName);
  const extension = extname(filePath).toLowerCase();
  if (extension !== ".json" && extension !== ".csv") throw new Error("Unsupported import type");

  const noFollow = "O_NOFOLLOW" in constants ? constants.O_NOFOLLOW : 0;
  const descriptor = openSync(filePath, constants.O_RDONLY | noFollow);
  try {
    const before = fstatSync(descriptor);
    if (!before.isFile()) throw new Error("Import path is not a regular file");
    if (before.size > limits.maxBytes) {
      throw new Error("Import file exceeds the configured byte limit");
    }
    const bytes = readFileSync(descriptor);
    const after = fstatSync(descriptor);
    if (
      before.size !== after.size ||
      before.mtimeMs !== after.mtimeMs ||
      before.ino !== after.ino ||
      bytes.byteLength !== before.size
    ) {
      throw new Error("Import file changed while it was being read");
    }
    const contents = bytes.toString("utf8");
    if (Buffer.from(contents, "utf8").byteLength !== bytes.byteLength) {
      throw new Error("Import file is not valid UTF-8");
    }
    if (limits.maxRecords !== undefined && extension === ".csv") {
      const records = Math.max(0, contents.trimEnd().split("\n").length - 1);
      if (records > limits.maxRecords) {
        throw new Error("Import file exceeds the record limit");
      }
    }
    return { extension, contents, bytes, path: filePath };
  } finally {
    closeSync(descriptor);
  }
}
