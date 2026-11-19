import { describe, expect, it } from "vitest";
import { calculateBill, type TariffConfig } from "./index.js";

const demoTariff: TariffConfig = {
  id: "99999999-9999-4999-8999-999999999999",
  name: "Demonstration tariff — not an EPDK tariff",
  currency: "TRY",
  validFrom: "2026-01-01T00:00:00.000Z",
  demonstration: true,
  pricesMicroliraPerKWh: {
    t1: 2_000_000,
    t2: 3_000_000,
    t3: 1_000_000,
    distribution: 500_000,
  },
  taxes: [{ code: "DEMO_TAX", rateBasisPoints: 1000 }],
};

describe("billing", () => {
  it("calculates in integer microlira with separate components", () => {
    const result = calculateBill(
      {
        t1Wh: 1000,
        t2Wh: 2000,
        t3Wh: 3000,
        periodStartedAt: "2026-11-01T00:00:00.000Z",
      },
      demoTariff,
    );
    expect(result.energyMicrolira).toEqual({ t1: 2_000_000, t2: 6_000_000, t3: 3_000_000 });
    expect(result.distributionMicrolira).toBe(3_000_000);
    expect(result.taxesMicrolira).toEqual([{ code: "DEMO_TAX", amount: 1_400_000 }]);
    expect(result.totalMicrolira).toBe(15_400_000);
    expect(result.demonstration).toBe(true);
  });

  it("rejects negative prices and invalid periods", () => {
    expect(() =>
      calculateBill(
        { t1Wh: 1, t2Wh: 0, t3Wh: 0, periodStartedAt: "2025-01-01T00:00:00.000Z" },
        {
          ...demoTariff,
          pricesMicroliraPerKWh: { ...demoTariff.pricesMicroliraPerKWh, t1: -1 },
        },
      ),
    ).toThrow();
  });
});
