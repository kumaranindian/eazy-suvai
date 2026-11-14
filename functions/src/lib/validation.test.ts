import { HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";

import { appError, appErrorCodeOf, AppErrorCode } from "./errors";
import { parseInput } from "./validation";

const schema = z.object({ restaurantId: z.string().min(1), priceMinor: z.number().int().nonnegative() });

describe("parseInput", () => {
  it("returns typed data when valid", () => {
    expect(parseInput(schema, { restaurantId: "r1", priceMinor: 129900 })).toEqual({
      restaurantId: "r1",
      priceMinor: 129900,
    });
  });

  it("throws invalid-input with the failing paths", () => {
    try {
      parseInput(schema, { restaurantId: "", priceMinor: 12.5 });
      throw new Error("expected rejection");
    } catch (e) {
      expect(e).toBeInstanceOf(HttpsError);
      const err = e as HttpsError;
      expect(err.code).toBe("invalid-argument");
      expect(appErrorCodeOf(err)).toBe("invalid-input");
      const paths = (err.details as { issues: { path: string }[] }).issues.map((i) => i.path);
      expect(paths).toEqual(expect.arrayContaining(["restaurantId", "priceMinor"]));
    }
  });
});

describe("appError", () => {
  it("maps every app code to an HttpsError", () => {
    for (const code of Object.values(AppErrorCode)) {
      const err = appError(code, "x");
      expect(err).toBeInstanceOf(HttpsError);
      expect(appErrorCodeOf(err)).toBe(code);
    }
  });

  it("keeps the app code even if extra details try to override it", () => {
    expect(appErrorCodeOf(appError("not-found", "x", { code: "evil" }))).toBe("not-found");
  });

  it("returns undefined for non-app errors", () => {
    expect(appErrorCodeOf(new Error("x"))).toBeUndefined();
  });
});
