import { resolve } from "node:path";
import { z } from "zod";

const environmentSchema = z.object({
  AKILLI_SAYAC_HOST: z.literal("127.0.0.1").default("127.0.0.1"),
  AKILLI_SAYAC_PORT: z.coerce.number().int().min(1024).max(65_535).default(3000),
  AKILLI_SAYAC_WEB_ORIGINS: z.string().default("http://127.0.0.1:5173"),
  AKILLI_SAYAC_DB_PATH: z.string().default("./data/akilli-sayac.sqlite"),
  AKILLI_SAYAC_METER_ID: z.string().default("meter-demo-001"),
  AKILLI_SAYAC_AMI_HMAC_KEY_HEX: z.string().optional(),
  AKILLI_SAYAC_LOCAL_TOKENS_JSON: z.string().optional(),
});

export interface AppConfig {
  host: "127.0.0.1";
  port: number;
  allowedOrigins: string[];
  databasePath: string;
  meterId: string;
  hmacKeyHex: string | undefined;
  localTokensJson: string | undefined;
}

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): AppConfig {
  const value = environmentSchema.parse(environment);
  return {
    host: value.AKILLI_SAYAC_HOST,
    port: value.AKILLI_SAYAC_PORT,
    allowedOrigins: value.AKILLI_SAYAC_WEB_ORIGINS.split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    databasePath: resolve(value.AKILLI_SAYAC_DB_PATH),
    meterId: value.AKILLI_SAYAC_METER_ID,
    hmacKeyHex: value.AKILLI_SAYAC_AMI_HMAC_KEY_HEX,
    localTokensJson: value.AKILLI_SAYAC_LOCAL_TOKENS_JSON,
  };
}
