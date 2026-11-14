import { registrationSchema } from "./register";

const valid = {
  restaurantName: "  Spice   Garden ",
  ownerName: "Priya",
  mobile: "98765 43210",
  country: "IN",
  businessType: "restaurant",
};

describe("registrationSchema (FR-002, FR-003)", () => {
  it("normalises names and returns the mobile in E.164", () => {
    const r = registrationSchema.parse(valid);
    expect(r.restaurantName).toBe("Spice Garden");
    expect(r.mobile).toBe("+919876543210");
  });

  it.each([
    ["AE", "050 123 4567", "+971501234567"],
    ["KW", "+965 5123 4567", "+96551234567"],
  ])("validates %s numbers", (country, mobile, e164) => {
    expect(registrationSchema.parse({ ...valid, country, mobile }).mobile).toBe(e164);
  });

  it.each([
    ["too short", { mobile: "12345" }],
    ["wrong country", { mobile: "+971501234567" }],
    ["unsupported country", { country: "XX" }],
    ["unknown business type", { businessType: "casino" }],
    ["blank name", { restaurantName: "   " }],
    ["extra field", { planId: "pro" }],
  ])("rejects %s", (_, override) => {
    expect(registrationSchema.safeParse({ ...valid, ...override }).success).toBe(false);
  });
});
