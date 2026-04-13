module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    tsconfigRootDir: __dirname,
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
    "/generated/**/*",
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "linebreak-style": 0,
    "object-curly-spacing": "off",
    "no-trailing-spaces": "error",
    "require-jsdoc": "off",
    "max-len": "off",
    "no-useless-escape": "off",
    "valid-jsdoc": "off",
    "new-cap": ["error", {properties: false}],
    "camelcase": "off",
    "brace-style": "off",
  },

};
