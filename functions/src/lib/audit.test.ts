import { FieldValue, type Timestamp, type Transaction } from "firebase-admin/firestore";

import { buildAuditDoc, writeAudit, type AuditDb, type AuditEntry } from "./audit";

const NOW = new Date("2026-11-14T10:00:00Z");

const entry: AuditEntry = {
  actorUid: "admin1",
  actorRole: "platformAdmin",
  action: "restaurant.suspend",
  restaurantId: "rest_1",
  target: "restaurants/rest_1",
  reason: "Unpaid invoice",
  details: { from: "active", to: "suspended" },
};

function fakeDb() {
  const writes: { collection: string; id: string; data: Record<string, unknown> }[] = [];
  let n = 0;
  const db: AuditDb = {
    collection: (collection: string) => ({
      doc: () => {
        const id = `log${++n}`;
        return {
          id,
          set: async (data: Record<string, unknown>) => {
            writes.push({ collection, id, data });
          },
        };
      },
    }),
  };
  return { db, writes };
}

describe("buildAuditDoc", () => {
  it("adds a server timestamp and a 2-year expireAt", () => {
    const doc = buildAuditDoc(entry, NOW);
    expect(doc.at).toEqual(FieldValue.serverTimestamp());
    expect((doc.expireAt as Timestamp).toDate().toISOString()).toBe("2028-11-14T10:00:00.000Z");
    expect(doc).toMatchObject({
      actorUid: "admin1",
      actorRole: "platformAdmin",
      action: "restaurant.suspend",
      restaurantId: "rest_1",
      target: "restaurants/rest_1",
      reason: "Unpaid invoice",
      details: { from: "active", to: "suspended" },
    });
  });

  it("omits optional fields instead of writing undefined", () => {
    const doc = buildAuditDoc(
      { actorUid: "sys", actorRole: "system", action: "plan.expire", target: "plans/pro" },
      NOW,
    );
    expect(doc).not.toHaveProperty("restaurantId");
    expect(doc).not.toHaveProperty("reason");
    expect(doc.details).toEqual({});
  });

  it("rejects malformed entries", () => {
    expect(() => buildAuditDoc({ ...entry, action: "Suspend" }, NOW)).toThrow();
    expect(() => buildAuditDoc({ ...entry, actorUid: "" }, NOW)).toThrow();
    expect(() =>
      buildAuditDoc({ ...entry, actorRole: "hacker" as AuditEntry["actorRole"] }, NOW),
    ).toThrow();
  });
});

describe("writeAudit", () => {
  it("writes to auditLogs and returns the id", async () => {
    const { db, writes } = fakeDb();
    const id = await writeAudit(entry, { db, now: NOW });
    expect(id).toBe("log1");
    expect(writes).toHaveLength(1);
    expect(writes[0].collection).toBe("auditLogs");
    expect(writes[0].data.action).toBe("restaurant.suspend");
  });

  it("writes inside a transaction when given one", async () => {
    const { db, writes } = fakeDb();
    const create = jest.fn();
    const tx = { create } as unknown as Transaction;
    const id = await writeAudit(entry, { db, transaction: tx, now: NOW });
    expect(writes).toHaveLength(0);
    expect(create).toHaveBeenCalledTimes(1);
    expect(create.mock.calls[0][0].id).toBe(id);
    expect(create.mock.calls[0][1].target).toBe("restaurants/rest_1");
  });
});
