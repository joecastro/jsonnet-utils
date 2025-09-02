import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";
import path from "node:path";
import { fileURLToPath } from "node:url";
import js from "@eslint/js";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
    baseDirectory: __dirname,
    recommendedConfig: js.configs.recommended,
    allConfig: js.configs.all
});

export default defineConfig([globalIgnores(["**/out/", "**/dist/", "**/node_modules/"]), {
    extends: compat.extends("eslint:recommended"),

    languageOptions: {
        globals: {
            ...globals.node,
        },

        ecmaVersion: 2022,
        sourceType: "module",
    },
}, {
    files: ["test/**/*.js"],

    languageOptions: {
        globals: {
            ...globals.mocha,
            ...globals.node,
        },

        ecmaVersion: 2022,
        sourceType: "commonjs",
    },

    rules: {
        "no-unused-vars": ["warn", {
            argsIgnorePattern: "^_",
        }],

        "no-undef": "off",
    },
}, {
    files: ["**/*.mjs", "**/*.js"],

    rules: {
        "no-unused-vars": ["warn", {
            argsIgnorePattern: "^_",
        }],
        // Enforce arrow-first style across the codebase
        "prefer-arrow-callback": ["error", { "allowNamedFunctions": false, "allowUnboundThis": true }],
        "func-style": ["error", "expression", { "allowArrowFunctions": true }],
    },
}]);
