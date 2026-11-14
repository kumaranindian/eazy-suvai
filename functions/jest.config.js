/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/*.test.ts"],
  // Emulator tests (*.emu.test.ts) run with `npm run test:emulators`.
  testPathIgnorePatterns: ["/node_modules/", "[.]emu[.]test[.]ts$"],
  clearMocks: true,
  transform: {
    "^.+\\.ts$": "ts-jest",
    // jose (used by firebase-admin) ships ESM only; transpile it for Jest.
    "^.+[\\\\/]node_modules[\\\\/]jose[\\\\/].+\\.js$": [
      "ts-jest",
      { tsconfig: { allowJs: true, module: "commonjs" }, diagnostics: false },
    ],
  },
  transformIgnorePatterns: ["[\\\\/]node_modules[\\\\/](?!jose[\\\\/])"],
};
