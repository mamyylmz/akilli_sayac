import { createHmac, timingSafeEqual } from "node:crypto";
import type { AmiEnvelope } from "@akilli-sayac/contracts";
import { canonicalJson } from "./canonical-json.js";

export function hmacKeyFromHex(value: string | undefined): Buffer {
  if (!value) throw new Error("AMI HMAC key is required");
  if (!/^[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error("AMI HMAC key must be exactly 32 bytes encoded as 64 hexadecimal characters");
  }
  return Buffer.from(value, "hex");
}

export function signAmiEnvelope(envelope: AmiEnvelope, key: Buffer): string {
  if (key.byteLength < 32) throw new Error("AMI HMAC key must contain at least 32 bytes");
  return createHmac("sha256", key).update(canonicalJson(envelope), "utf8").digest("base64");
}

export function verifyAmiEnvelope(
  envelope: AmiEnvelope,
  signatureBase64: string,
  key: Buffer,
): boolean {
  const expected = Buffer.from(signAmiEnvelope(envelope, key), "base64");
  let supplied: Buffer;
  try {
    supplied = Buffer.from(signatureBase64, "base64");
  } catch {
    return false;
  }
  return supplied.byteLength === expected.byteLength && timingSafeEqual(supplied, expected);
}
