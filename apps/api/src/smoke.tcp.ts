import assert from "node:assert/strict";
import { test } from "node:test";
import { LocalTokenAuth } from "@akilli-sayac/security";
import { buildApp } from "./app.js";
import { MeterDatabase } from "./database.js";

void test("GET /health responds over TCP", { timeout: 10_000 }, async () => {
  const database = new MeterDatabase(":memory:");
  try {
    const app = buildApp({
      database,
      auth: new LocalTokenAuth([]),
      expectedMeterId: "meter-demo-001",
      allowedOrigins: [],
    });
    try {
      const address = await app.listen({ host: "127.0.0.1", port: 0 });
      const response = await fetch(new URL("/health", address), {
        signal: AbortSignal.timeout(5_000),
      });
      assert.equal(response.status, 200);
      assert.partialDeepStrictEqual(await response.json(), { status: "ok" });
    } finally {
      await app.close();
    }
  } finally {
    database.close();
  }
});
