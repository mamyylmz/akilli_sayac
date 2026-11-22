import { mkdirSync } from "node:fs";
import { hmacKeyFromHex, localTokenAuthFromJson } from "@akilli-sayac/security";
import { buildApp } from "./app.js";
import { loadConfig } from "./config.js";
import { MeterDatabase } from "./database.js";

const config = loadConfig();
mkdirSync(config.importDirectory, { recursive: true });
const database = new MeterDatabase(config.databasePath);
const auth = localTokenAuthFromJson(config.localTokensJson);
const hmacKey = config.hmacKeyHex ? hmacKeyFromHex(config.hmacKeyHex) : undefined;
const app = buildApp({
  database,
  auth,
  allowedOrigins: config.allowedOrigins,
  expectedMeterId: config.meterId,
  importDirectory: config.importDirectory,
  ...(hmacKey ? { hmacKey } : {}),
  logger: true,
});

const shutdown = async () => {
  await app.close();
  database.close();
};

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());

try {
  await app.listen({ host: config.host, port: config.port });
} catch (error) {
  app.log.error(
    { error: error instanceof Error ? error.message : "unknown" },
    "API startup failed",
  );
  await shutdown();
  process.exitCode = 1;
}
