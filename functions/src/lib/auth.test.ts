import { HttpsError } from "firebase-functions/v2/https";

import { assertAdmin, assertOwner, assertSignedIn, type CallerAuth, type DocReader } from "./auth";
import { appErrorCodeOf } from "./errors";

const RID = "rest_1";

function fakeDb(docs: Record<string, Record<string, unknown>>): DocReader & { reads: string[] } {
  const reads: string[] = [];
  return {
    reads,
    doc: (path: string) => ({
      get: async () => {
        reads.push(path);
        const data = docs[path];
        return { exists: data !== undefined, data: () => data };
      },
    }),
  };
}

function owner(overrides: Partial<CallerAuth["token"]> = {}, uid = "u1"): CallerAuth {
  return {
    uid,
    token: { email_verified: true, role: "owner", restaurantId: RID, ...overrides },
  };
}

const activeRestaurant = { [`restaurants/${RID}`]: { ownerUid: "u1", status: "active", name: "Saravana" } };

async function codeOf(promise: Promise<unknown>): Promise<string | undefined> {
  try {
    await promise;
  } catch (e) {
    expect(e).toBeInstanceOf(HttpsError);
    return appErrorCodeOf(e);
  }
  throw new Error("expected rejection");
}

describe("assertOwner", () => {
  it("accepts a verified owner of an active restaurant", async () => {
    const db = fakeDb(activeRestaurant);
    const ctx = await assertOwner(owner(), RID, { db });
    expect(ctx.uid).toBe("u1");
    expect(ctx.restaurantId).toBe(RID);
    expect(ctx.restaurant.name).toBe("Saravana");
    expect(db.reads).toEqual([`restaurants/${RID}`]);
  });

  it("rejects a signed-out caller", async () => {
    expect(await codeOf(assertOwner(undefined, RID, { db: fakeDb(activeRestaurant) }))).toBe("unauthenticated");
    expect(await codeOf(assertOwner(null, RID, { db: fakeDb(activeRestaurant) }))).toBe("unauthenticated");
  });

  it("rejects an unverified email (FR-091)", async () => {
    const db = fakeDb(activeRestaurant);
    expect(await codeOf(assertOwner(owner({ email_verified: false }), RID, { db }))).toBe("email-not-verified");
    expect(await codeOf(assertOwner(owner({ email_verified: undefined }), RID, { db }))).toBe("email-not-verified");
    expect(db.reads).toEqual([]);
  });

  it("rejects another restaurant's owner without reading it (AC-017)", async () => {
    const db = fakeDb(activeRestaurant);
    expect(await codeOf(assertOwner(owner({ restaurantId: "other" }), RID, { db }))).toBe("permission-denied");
    expect(db.reads).toEqual([]);
  });

  it("rejects an admin or a caller with no role", async () => {
    const db = fakeDb(activeRestaurant);
    expect(await codeOf(assertOwner(owner({ role: "platformAdmin" }), RID, { db }))).toBe("permission-denied");
    expect(await codeOf(assertOwner(owner({ role: undefined }), RID, { db }))).toBe("permission-denied");
  });

  it("rejects when the claim matches but ownerUid does not", async () => {
    const db = fakeDb({ [`restaurants/${RID}`]: { ownerUid: "someone-else", status: "active" } });
    expect(await codeOf(assertOwner(owner(), RID, { db }))).toBe("permission-denied");
  });

  it("rejects a missing restaurant", async () => {
    expect(await codeOf(assertOwner(owner(), RID, { db: fakeDb({}) }))).toBe("not-found");
  });

  it("rejects an empty restaurantId", async () => {
    expect(await codeOf(assertOwner(owner(), "", { db: fakeDb({}) }))).toBe("invalid-input");
  });

  it.each(["suspended", "deactivated", "deleted"])("rejects a %s restaurant by default", async (status) => {
    const db = fakeDb({ [`restaurants/${RID}`]: { ownerUid: "u1", status } });
    expect(await codeOf(assertOwner(owner(), RID, { db }))).toBe("account-inactive");
  });

  it("allows extra statuses when asked (account lifecycle)", async () => {
    const db = fakeDb({ [`restaurants/${RID}`]: { ownerUid: "u1", status: "deactivated" } });
    const ctx = await assertOwner(owner(), RID, { db, allowedStatuses: ["active", "deactivated"] });
    expect(ctx.restaurant.status).toBe("deactivated");
  });

  it("sends the wire code in details and a gRPC code", async () => {
    try {
      await assertOwner(owner({ email_verified: false }), RID, { db: fakeDb({}) });
      throw new Error("expected rejection");
    } catch (e) {
      const err = e as HttpsError;
      expect(err.code).toBe("failed-precondition");
      expect(err.details).toEqual({ code: "email-not-verified" });
    }
  });
});

describe("assertAdmin", () => {
  it("accepts a platform admin", () => {
    expect(assertAdmin({ uid: "a1", token: { role: "platformAdmin" } })).toEqual({ uid: "a1" });
  });

  it("rejects owners and signed-out callers", () => {
    expect(() => assertAdmin(owner())).toThrow(HttpsError);
    try {
      assertAdmin(owner());
    } catch (e) {
      expect(appErrorCodeOf(e)).toBe("permission-denied");
    }
    try {
      assertAdmin(undefined);
    } catch (e) {
      expect(appErrorCodeOf(e)).toBe("unauthenticated");
    }
  });
});

describe("assertSignedIn", () => {
  it("returns the auth when present", () => {
    const auth = owner();
    expect(assertSignedIn(auth)).toBe(auth);
  });
});
