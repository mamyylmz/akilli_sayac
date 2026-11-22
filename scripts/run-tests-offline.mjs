import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { runRegisteredTests } from "./vitest-offline-shim.mjs";

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("Provide compiled test files to run");
  process.exit(2);
}

let total = 0;
let failed = 0;
for (const file of files) {
  await import(pathToFileURL(resolve(file)).href);
  const result = await runRegisteredTests();
  total += result.total;
  failed += result.failed;
}
console.log(`\nOffline compatibility run: ${total - failed}/${total} passed`);
if (failed > 0) process.exitCode = 1;
