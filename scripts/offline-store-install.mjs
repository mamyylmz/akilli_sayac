#!/usr/bin/env node

/**
 * Minimal, dependency-free installer for a pnpm v11 content-addressable store.
 *
 * This exists for offline development environments where pnpm itself is not
 * available but a trusted local pnpm store already contains the lockfile's
 * packages. It intentionally does not contact a registry or execute lifecycle
 * scripts. Prefer `pnpm install --frozen-lockfile` in normal environments.
 */

import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const semver = require("semver");

class MsgpackrDecoder {
  constructor(buffer) {
    this.buffer = buffer;
    this.offset = 0;
    this.records = new Map();
  }

  byte() {
    return this.buffer[this.offset++];
  }

  uint(bytes) {
    const readers = {
      1: () => this.buffer.readUInt8(this.offset),
      2: () => this.buffer.readUInt16BE(this.offset),
      4: () => this.buffer.readUInt32BE(this.offset),
      8: () => this.buffer.readBigUInt64BE(this.offset),
    };
    const value = readers[bytes]();
    this.offset += bytes;
    return typeof value === "bigint" && value <= BigInt(Number.MAX_SAFE_INTEGER)
      ? Number(value)
      : value;
  }

  int(bytes) {
    const readers = {
      1: () => this.buffer.readInt8(this.offset),
      2: () => this.buffer.readInt16BE(this.offset),
      4: () => this.buffer.readInt32BE(this.offset),
      8: () => this.buffer.readBigInt64BE(this.offset),
    };
    const value = readers[bytes]();
    this.offset += bytes;
    return typeof value === "bigint" &&
      value >= BigInt(Number.MIN_SAFE_INTEGER) &&
      value <= BigInt(Number.MAX_SAFE_INTEGER)
      ? Number(value)
      : value;
  }

  string(length) {
    const value = this.buffer.toString("utf8", this.offset, this.offset + length);
    this.offset += length;
    return value;
  }

  binary(length) {
    const value = this.buffer.subarray(this.offset, this.offset + length);
    this.offset += length;
    return value;
  }

  array(length) {
    return Array.from({ length }, () => this.decode());
  }

  map(length) {
    const value = {};
    for (let index = 0; index < length; index += 1) {
      value[this.decode()] = this.decode();
    }
    return value;
  }

  extension(length) {
    const type = this.byte();
    const data = this.binary(length);
    if (type !== 0x72 || length !== 1) {
      throw new Error(`Unsupported MessagePack extension type=${type} length=${length}`);
    }

    const recordId = data[0];
    let keys = this.records.get(recordId);
    if (!keys) {
      keys = this.decode();
      if (!Array.isArray(keys) || !keys.every((key) => typeof key === "string")) {
        throw new Error(`Invalid msgpackr record definition ${recordId}`);
      }
      this.records.set(recordId, keys);
    }

    return this.recordValue(keys);
  }

  recordValue(keys) {
    const value = {};
    for (const key of keys) value[key] = this.decode();
    return value;
  }

  decode() {
    const prefix = this.byte();
    if (prefix <= 0x7f) {
      const keys = this.records.get(prefix);
      return keys ? this.recordValue(keys) : prefix;
    }
    if (prefix >= 0xe0) return prefix - 0x100;
    if ((prefix & 0xe0) === 0xa0) return this.string(prefix & 0x1f);
    if ((prefix & 0xf0) === 0x90) return this.array(prefix & 0x0f);
    if ((prefix & 0xf0) === 0x80) return this.map(prefix & 0x0f);

    switch (prefix) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xc4:
        return this.binary(this.uint(1));
      case 0xc5:
        return this.binary(this.uint(2));
      case 0xc6:
        return this.binary(this.uint(4));
      case 0xca: {
        const value = this.buffer.readFloatBE(this.offset);
        this.offset += 4;
        return value;
      }
      case 0xcb: {
        const value = this.buffer.readDoubleBE(this.offset);
        this.offset += 8;
        return value;
      }
      case 0xcc:
        return this.uint(1);
      case 0xcd:
        return this.uint(2);
      case 0xce:
        return this.uint(4);
      case 0xcf:
        return this.uint(8);
      case 0xd0:
        return this.int(1);
      case 0xd1:
        return this.int(2);
      case 0xd2:
        return this.int(4);
      case 0xd3:
        return this.int(8);
      case 0xd4:
        return this.extension(1);
      case 0xd9:
        return this.string(this.uint(1));
      case 0xda:
        return this.string(this.uint(2));
      case 0xdb:
        return this.string(this.uint(4));
      case 0xdc:
        return this.array(this.uint(2));
      case 0xdd:
        return this.array(this.uint(4));
      case 0xde:
        return this.map(this.uint(2));
      case 0xdf:
        return this.map(this.uint(4));
      default:
        throw new Error(`Unsupported MessagePack prefix 0x${prefix.toString(16)}`);
    }
  }
}

function parsePackageKey(key) {
  const separator = key.indexOf("\t");
  const packageRef = key.slice(separator + 1);
  const versionSeparator = packageRef.lastIndexOf("@");
  return {
    integrity: key.slice(0, separator),
    name: packageRef.slice(0, versionSeparator),
    version: packageRef.slice(versionSeparator + 1),
  };
}

function filePathFromIntegrity(filesDirectory, integrity, mode = 0o644) {
  if (/^[0-9a-f]{128}$/.test(integrity)) {
    return join(
      filesDirectory,
      integrity.slice(0, 2),
      `${integrity.slice(2)}${mode & 0o111 ? "-exec" : ""}`,
    );
  }
  const [, encoded] = integrity.split("-");
  const hash = Buffer.from(encoded, "base64").toString("hex");
  return join(filesDirectory, hash.slice(0, 2), `${hash.slice(2)}${mode & 0o111 ? "-exec" : ""}`);
}

function usage() {
  console.error(
    "Usage: offline-store-install.mjs <store-v11> <target-node_modules> <package@version> [...]",
  );
  process.exit(2);
}

const [storeArgument, targetArgument, ...rootSpecs] = process.argv.slice(2);
if (!storeArgument || !targetArgument || rootSpecs.length === 0) usage();

const store = resolve(storeArgument);
const target = resolve(targetArgument);
const temporaryDatabase = join(process.env.TMPDIR || "/tmp", `pnpm-index-${process.pid}.db`);
writeFileSync(temporaryDatabase, readFileSync(join(store, "index.db")));

const database = new DatabaseSync(temporaryDatabase, { readOnly: true });
const rows = database.prepare("SELECT key, data FROM package_index").all();
const packages = new Map();

for (const row of rows) {
  const parsed = parsePackageKey(row.key);
  if (!semver.valid(parsed.version)) continue;
  const metadata = new MsgpackrDecoder(Buffer.from(row.data)).decode();
  const versions = packages.get(parsed.name) ?? [];
  versions.push({ ...parsed, metadata });
  packages.set(parsed.name, versions);
}

for (const versions of packages.values()) {
  versions.sort((left, right) => semver.rcompare(left.version, right.version));
}

function splitSpec(spec) {
  const separator = spec.lastIndexOf("@");
  if (separator <= 0) throw new Error(`Package version is required: ${spec}`);
  return [spec.slice(0, separator), spec.slice(separator + 1)];
}

function resolvePackage(name, range) {
  const versions = packages.get(name) ?? [];
  const selected = versions.find((candidate) => {
    if (range.startsWith("npm:")) {
      const [, aliasRange] = splitSpec(range.slice(4));
      return semver.satisfies(candidate.version, aliasRange, { includePrerelease: true });
    }
    return semver.satisfies(candidate.version, range, { includePrerelease: true });
  });
  if (!selected) throw new Error(`Offline store has no ${name}@${range}`);
  return selected;
}

const selected = new Map();

function packageId(pkg) {
  return `${pkg.name}@${pkg.version}`;
}

function resolveDependency(name, range) {
  if (range.startsWith("npm:")) {
    const [actualName, actualRange] = splitSpec(range.slice(4));
    return [actualName, actualRange];
  }
  return [name, range];
}

function visit(name, range) {
  const [actualName, actualRange] = resolveDependency(name, range);
  const pkg = resolvePackage(actualName, actualRange);
  const id = packageId(pkg);
  if (selected.has(id)) return id;

  const entry = { pkg, dependencies: new Map() };
  selected.set(id, entry);
  const manifest = pkg.metadata.manifest ?? {};
  for (const [dependencyName, dependencyRange] of Object.entries(manifest.dependencies ?? {})) {
    if (
      dependencyRange.startsWith("workspace:") ||
      dependencyRange.startsWith("file:") ||
      dependencyRange.startsWith("link:")
    )
      continue;
    entry.dependencies.set(dependencyName, visit(dependencyName, dependencyRange));
  }
  for (const [dependencyName, dependencyRange] of Object.entries(
    manifest.optionalDependencies ?? {},
  )) {
    try {
      entry.dependencies.set(dependencyName, visit(dependencyName, dependencyRange));
    } catch {
      // Optional platform packages are commonly absent from cross-platform offline stores.
    }
  }
  return id;
}

const rootLinks = new Map(
  rootSpecs.map((spec) => {
    const [name, range] = splitSpec(spec);
    return [name, visit(name, range)];
  }),
);

rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
const filesDirectory = join(store, "files");

const packageDirectories = new Map();
for (const [id, { pkg }] of selected) {
  const safeId = id.replaceAll("/", "+");
  const packageDirectory = join(
    target,
    ".offline-store",
    safeId,
    "node_modules",
    ...pkg.name.split("/"),
  );
  packageDirectories.set(id, packageDirectory);
  mkdirSync(packageDirectory, { recursive: true });
  if (process.env.OFFLINE_STORE_DEBUG === pkg.name) {
    console.dir(pkg.metadata, { depth: 5, maxArrayLength: 20 });
  }
  for (const [relativePath, descriptor] of Object.entries(pkg.metadata.files ?? {})) {
    const integrity =
      typeof descriptor === "string" ? descriptor : (descriptor.integrity ?? descriptor.digest);
    if (!integrity) {
      throw new Error(
        `Missing integrity for ${pkg.name}/${relativePath}: ${JSON.stringify(descriptor).slice(0, 500)}`,
      );
    }
    const source = filePathFromIntegrity(filesDirectory, integrity, descriptor.mode);
    const destination = join(packageDirectory, relativePath);
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, readFileSync(source), { mode: descriptor.mode ?? 0o644 });
  }
}

function linkPackage(link, packageDirectory) {
  mkdirSync(dirname(link), { recursive: true });
  rmSync(link, { recursive: true, force: true });
  symlinkSync(packageDirectory, link, "dir");
}

function linkBinaries(binaryDirectory, manifest, packageDirectory) {
  const binaries =
    typeof manifest.bin === "string"
      ? [[manifest.name.split("/").at(-1), manifest.bin]]
      : Object.entries(manifest.bin ?? {});
  for (const [binaryName, relativePath] of binaries) {
    mkdirSync(binaryDirectory, { recursive: true });
    const link = join(binaryDirectory, binaryName);
    rmSync(link, { force: true });
    symlinkSync(join(packageDirectory, relativePath), link);
  }
}

for (const [id, { dependencies }] of selected) {
  const packageDirectory = packageDirectories.get(id);
  const dependencyDirectory = join(packageDirectory, "node_modules");
  for (const [dependencyName, dependencyId] of dependencies) {
    const dependencyPackage = selected.get(dependencyId).pkg;
    const dependencyPackageDirectory = packageDirectories.get(dependencyId);
    linkPackage(
      join(dependencyDirectory, ...dependencyName.split("/")),
      dependencyPackageDirectory,
    );
    linkBinaries(
      join(dependencyDirectory, ".bin"),
      dependencyPackage.metadata.manifest ?? {},
      dependencyPackageDirectory,
    );
  }
}

for (const [name, id] of rootLinks) {
  const { pkg } = selected.get(id);
  const packageDirectory = packageDirectories.get(id);
  linkPackage(join(target, ...name.split("/")), packageDirectory);
  linkBinaries(join(target, ".bin"), pkg.metadata.manifest ?? {}, packageDirectory);
}

database.close();
rmSync(temporaryDatabase, { force: true });

const digest = createHash("sha256")
  .update(
    [...selected.values()]
      .map(({ pkg }) => `${pkg.name}@${pkg.version}`)
      .sort()
      .join("\n"),
  )
  .digest("hex");
console.log(
  `Installed ${selected.size} packages without network or lifecycle scripts (manifest sha256 ${digest}).`,
);
