import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";
export default defineConfig({
    plugins: [react(), tailwindcss()],
    server: {
        port: 5173,
        strictPort: true,
    },
    test: {
        environment: "jsdom",
        setupFiles: ["./src/test/setup.ts"],
        css: true,
        restoreMocks: true,
        // The default `forks` pool fails to hand off worker argv when the repository
        // path contains a space (e.g. "HACKATHON PROJECTS"); threads are unaffected.
        pool: "threads",
    },
});
