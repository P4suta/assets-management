import { resolve } from "node:path";
import { defineConfig } from "vite";

export default defineConfig({
	root: "public",
	publicDir: "../static",
	build: {
		outDir: "../dist",
		emptyOutDir: true,
		cssMinify: false,
		rolldownOptions: {
			input: {
				home: resolve(import.meta.dirname, "public/index.html"),
				privacy: resolve(import.meta.dirname, "public/privacy/index.html"),
				support: resolve(import.meta.dirname, "public/support/index.html"),
			},
		},
	},
});
