import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["lib/**", "coverage/**", "node_modules/**"] },
  { files: ["*.js"], languageOptions: { globals: globals.node, sourceType: "commonjs" } },
  { files: ["scripts/**/*.mjs"], languageOptions: { globals: globals.node, sourceType: "module" } },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    languageOptions: { globals: globals.node },
    rules: {
      "quotes": ["error", "double", { avoidEscape: true }],
      "semi": ["error", "always"],
      "eqeqeq": ["error", "always"],
      "no-console": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
);
