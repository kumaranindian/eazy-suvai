// End to end on the emulators: Auth REST → completeRegistration callable
// (Functions emulator) → verification link → sign in with claims (AC-001).
import {
  AUTH_HOST,
  claimsOf,
  FUNCTIONS_HOST,
  identityToolkit,
  PROJECT_ID,
  resetEmulators,
  validInput,
} from "../testing/emulator";

interface CallableResponse {
  result?: Record<string, unknown>;
  error?: { status: string; details?: { code: string } };
}

async function call(name: string, idToken: string, data: unknown): Promise<CallableResponse> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (idToken) headers.authorization = `Bearer ${idToken}`;
  const res = await fetch(`http://${FUNCTIONS_HOST}/${PROJECT_ID}/asia-south1/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ data }),
  });
  return (await res.json()) as CallableResponse;
}

beforeEach(resetEmulators);

it("sign-up → completeRegistration → verify → sign in", async () => {
  const email = "e2e@example.com";
  const password = "Secret123!";
  const signUp = await identityToolkit("signUp", { email, password, returnSecureToken: true });
  expect(signUp.status).toBe(200);
  const firstToken = signUp.json.idToken as string;

  const reg = await call("completeRegistration", firstToken, validInput);
  expect(reg.error).toBeUndefined();
  expect(reg.result).toMatchObject({ slug: "spice-garden", created: true });

  // Same email again is refused by Auth (FR-004).
  const dup = await identityToolkit("signUp", { email, password, returnSecureToken: true });
  expect(dup.status).toBe(400);
  expect((dup.json.error as { message: string }).message).toBe("EMAIL_EXISTS");

  // Before verification the token has the claims but email_verified is false.
  const unverified = await identityToolkit("signInWithPassword", { email, password, returnSecureToken: true });
  expect(claimsOf(unverified.json.idToken as string)).toMatchObject({ email_verified: false, role: "owner" });

  // The client sends the verification email; follow the emulator link.
  await identityToolkit("sendOobCode", { requestType: "VERIFY_EMAIL", idToken: unverified.json.idToken });
  const codes = (await (
    await fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/oobCodes`)
  ).json()) as { oobCodes: { email: string; requestType: string; oobCode: string }[] };
  const code = codes.oobCodes.find((c) => c.email === email && c.requestType === "VERIFY_EMAIL")!;
  const applied = await identityToolkit("update", { oobCode: code.oobCode });
  expect(applied.status).toBe(200);

  const signIn = await identityToolkit("signInWithPassword", { email, password, returnSecureToken: true });
  expect(claimsOf(signIn.json.idToken as string)).toMatchObject({
    email_verified: true,
    role: "owner",
    restaurantId: reg.result!.restaurantId,
  });

  // A retry with the verified token resumes instead of creating a second tenant.
  const again = await call("completeRegistration", signIn.json.idToken as string, {});
  expect(again.result).toMatchObject({ restaurantId: reg.result!.restaurantId, created: false });

  // Password reset by link (FR-006): the link sets a new password and works once.
  await identityToolkit("sendOobCode", { requestType: "PASSWORD_RESET", email });
  const all = (await (
    await fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/oobCodes`)
  ).json()) as { oobCodes: { email: string; requestType: string; oobCode: string }[] };
  const reset = all.oobCodes.find((c) => c.email === email && c.requestType === "PASSWORD_RESET")!;
  const newPassword = "NewSecret456!";
  expect((await identityToolkit("resetPassword", { oobCode: reset.oobCode, newPassword })).status).toBe(200);
  expect((await identityToolkit("resetPassword", { oobCode: reset.oobCode, newPassword: "Again789!" })).status).toBe(
    400,
  );
  expect((await identityToolkit("signInWithPassword", { email, password, returnSecureToken: true })).status).toBe(400);
  const withNew = await identityToolkit("signInWithPassword", { email, password: newPassword, returnSecureToken: true });
  expect(withNew.status).toBe(200);
  expect(claimsOf(withNew.json.idToken as string)).toMatchObject({ role: "owner", email_verified: true });
});

it("rejects an unauthenticated call", async () => {
  const res = await call("completeRegistration", "", validInput);
  expect(res.error?.status).toBe("UNAUTHENTICATED");
  expect(res.error?.details?.code).toBe("unauthenticated");
});
