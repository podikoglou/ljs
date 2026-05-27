/// <reference types="vitest/config" />
import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

const root = path.resolve(__dirname, "..");

export default defineConfig({
  plugins: [react(), tailwindcss()],
  base: "/",
  resolve: {
    alias: {
      "@ljs": root,
    },
  },
  server: {
    fs: {
      allow: [root],
    },
  },
  build: {
    outDir: "dist",
  },
  test: {},
});
