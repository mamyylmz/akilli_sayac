import { z } from "zod";

const moneyInteger = z.number().int().min(0).safe();
const energyInteger = z.number().int().min(0).safe();

export const tariffConfigSchema = z
  .object({
    id: z.string().uuid(),
    name: z.string().min(1).max(128),
    currency: z.literal("TRY"),
    validFrom: z.string().datetime({ offset: true }),
    validUntil: z.string().datetime({ offset: true }).optional(),
    demonstration: z.boolean(),
    pricesMicroliraPerKWh: z
      .object({
        t1: moneyInteger,
        t2: moneyInteger,
        t3: moneyInteger,
        distribution: moneyInteger,
      })
      .strict(),
    taxes: z
      .array(
        z
          .object({
            code: z.string().regex(/^[A-Z0-9_]{2,32}$/),
            rateBasisPoints: z.number().int().min(0).max(10_000),
          })
          .strict(),
      )
      .max(10),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.validUntil && Date.parse(value.validUntil) <= Date.parse(value.validFrom)) {
      context.addIssue({
        code: "custom",
        message: "validUntil must be after validFrom",
        path: ["validUntil"],
      });
    }
  });

export const billInputSchema = z
  .object({
    t1Wh: energyInteger,
    t2Wh: energyInteger,
    t3Wh: energyInteger,
    periodStartedAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type TariffConfig = z.infer<typeof tariffConfigSchema>;
export type BillInput = z.infer<typeof billInputSchema>;

export interface BillResult {
  currency: "TRY";
  tariffId: string;
  demonstration: boolean;
  energyMicrolira: { t1: number; t2: number; t3: number };
  distributionMicrolira: number;
  taxesMicrolira: Array<{ code: string; amount: number }>;
  totalMicrolira: number;
}

function roundedDivide(numerator: bigint, denominator: bigint): bigint {
  return (numerator + denominator / 2n) / denominator;
}

function safeNumber(value: bigint): number {
  const converted = Number(value);
  if (!Number.isSafeInteger(converted)) throw new RangeError("Bill exceeds safe integer range");
  return converted;
}

function costForEnergy(energyWh: bigint, priceMicroliraPerKWh: number): bigint {
  return roundedDivide(energyWh * BigInt(priceMicroliraPerKWh), 1000n);
}

export function calculateBill(inputValue: BillInput, tariffValue: TariffConfig): BillResult {
  const input = billInputSchema.parse(inputValue);
  const tariff = tariffConfigSchema.parse(tariffValue);
  const period = Date.parse(input.periodStartedAt);
  if (
    period < Date.parse(tariff.validFrom) ||
    (tariff.validUntil && period >= Date.parse(tariff.validUntil))
  ) {
    throw new RangeError("Tariff is not valid for the billing period");
  }

  const t1Wh = BigInt(input.t1Wh);
  const t2Wh = BigInt(input.t2Wh);
  const t3Wh = BigInt(input.t3Wh);
  const t1 = costForEnergy(t1Wh, tariff.pricesMicroliraPerKWh.t1);
  const t2 = costForEnergy(t2Wh, tariff.pricesMicroliraPerKWh.t2);
  const t3 = costForEnergy(t3Wh, tariff.pricesMicroliraPerKWh.t3);
  const totalWh = t1Wh + t2Wh + t3Wh;
  const distribution = costForEnergy(totalWh, tariff.pricesMicroliraPerKWh.distribution);
  const subtotal = t1 + t2 + t3 + distribution;
  const taxes = tariff.taxes.map((tax) => ({
    code: tax.code,
    amount: roundedDivide(subtotal * BigInt(tax.rateBasisPoints), 10_000n),
  }));
  const total = subtotal + taxes.reduce((sum, tax) => sum + tax.amount, 0n);

  return {
    currency: "TRY",
    tariffId: tariff.id,
    demonstration: tariff.demonstration,
    energyMicrolira: { t1: safeNumber(t1), t2: safeNumber(t2), t3: safeNumber(t3) },
    distributionMicrolira: safeNumber(distribution),
    taxesMicrolira: taxes.map((tax) => ({ code: tax.code, amount: safeNumber(tax.amount) })),
    totalMicrolira: safeNumber(total),
  };
}
