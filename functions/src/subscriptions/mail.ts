/**
 * Owner emails for subscriptions (M10, FR-100, §5.5).
 *
 * Emails are queued as `mail/{id}` documents in the format of the Firebase
 * "Trigger Email from Firestore" extension (`{to, message: {subject, text,
 * html}}`), which sends them once installed with an SMTP provider. Nothing
 * here depends on a mail provider; without the extension the documents just
 * wait (Open items). Text is English in the MVP (FRD §6.3).
 */
import { FieldValue, type Firestore, type Transaction, type WriteBatch } from "firebase-admin/firestore";

export type MailKind = "reminder" | "grace" | "downgraded" | "activated" | "limitsApplied" | "restored";

const fmt = (d: Date) => d.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

/** Subject and text of each email. */
export function mailContent(kind: MailKind, v: { name: string; days?: number; date?: Date; planName?: string; hiddenItems?: number; hiddenCategories?: number }): { subject: string; text: string } {
  const name = v.name || "your restaurant";
  switch (kind) {
  case "reminder":
    return {
      subject: `Your ${v.planName ?? "Pro"} plan ends in ${v.days} day${v.days === 1 ? "" : "s"}`,
      text: `Hello,\n\nThe ${v.planName ?? "Pro"} plan for ${name} ends on ${v.date ? fmt(v.date) : "its expiry date"}. Renew from the Plan page in the EazySuvai app to keep your Pro features.\n\nEazySuvai`,
    };
  case "grace":
    return {
      subject: "Your plan has expired – your menu keeps working for now",
      text: `Hello,\n\nThe paid plan for ${name} has expired. Everything keeps working until ${v.date ? fmt(v.date) : "the end of the grace period"}. After that the restaurant moves to the Free plan. Renew from the Plan page to avoid that.\n\nEazySuvai`,
    };
  case "downgraded":
    return {
      subject: "Your restaurant is now on the Free plan",
      text: `Hello,\n\n${name} is now on the Free plan. Your menu and QR code stay live. Content over the Free limits is hidden, not deleted, and comes back when you upgrade.\n\nEazySuvai`,
    };
  case "limitsApplied":
    return {
      subject: "Some menu content is hidden to fit your plan",
      text: `Hello,\n\nTo fit the ${v.planName ?? "Free"} plan, ${v.hiddenItems ?? 0} item(s) and ${v.hiddenCategories ?? 0} categor${v.hiddenCategories === 1 ? "y is" : "ies are"} hidden on the menu of ${name}. Nothing was deleted. You can choose which items are hidden on the Plan page, or upgrade to show everything again.\n\nEazySuvai`,
    };
  case "activated":
    return {
      subject: `${v.planName ?? "Pro"} is active`,
      text: `Hello,\n\nThank you. The ${v.planName ?? "Pro"} plan for ${name} is active until ${v.date ? fmt(v.date) : "the end of the period"}. The new limits apply now.\n\nEazySuvai`,
    };
  case "restored":
    return {
      subject: "Your hidden menu content is back in your draft",
      text: `Hello,\n\nContent that was hidden to fit your old plan is back in the draft of ${name}. Publish your menu to show it to customers.\n\nEazySuvai`,
    };
  }
}

/**
 * Queues an email to the restaurant owner.
 *
 * @param db Firestore.
 * @param to The owner's email (skipped when empty).
 * @param kind Which email.
 * @param v Values for the text.
 * @param write Write in this transaction or batch, else directly.
 */
export async function queueOwnerMail(
  db: Firestore,
  to: unknown,
  kind: MailKind,
  v: Parameters<typeof mailContent>[1] & { restaurantId: string },
  write?: Transaction | WriteBatch,
): Promise<void> {
  if (typeof to !== "string" || !to.includes("@")) return;
  const { subject, text } = mailContent(kind, v);
  const ref = db.collection("mail").doc();
  const data = {
    to,
    message: { subject, text },
    kind,
    restaurantId: v.restaurantId,
    createdAt: FieldValue.serverTimestamp(),
  };
  if (write) {
    (write as Transaction).set(ref, data);
  } else {
    await ref.set(data);
  }
}
