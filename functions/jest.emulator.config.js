/** Emulator tests: `npm run test:emulators` (Auth, Firestore, Functions). */
// eslint-disable-next-line @typescript-eslint/no-require-imports
const base = require("./jest.config");

/** @type {import('jest').Config} */
module.exports = {
  ...base,
  testMatch: ["**/*.emu.test.ts"],
  testPathIgnorePatterns: ["/node_modules/"],
  testTimeout: 30000,
  maxWorkers: 1,
};
