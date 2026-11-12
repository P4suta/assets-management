import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: "./tests",
	workers: 2,
	retries: 0,
	timeout: 30_000,
	use: {
		baseURL: process.env.SUPPORT_ORIGIN ?? "http://127.0.0.1:4318",
		headless: true,
		trace: "retain-on-failure",
		screenshot: "only-on-failure",
	},
	...(process.env.SUPPORT_ORIGIN
		? {}
		: {
				webServer: {
					command: "pnpm dev",
					url: "http://127.0.0.1:4318",
					reuseExistingServer: false,
				},
			}),
	projects: [
		{
			name: "desktop-light",
			use: { viewport: { width: 1440, height: 900 }, colorScheme: "light" },
		},
		{
			name: "narrow-light",
			use: { viewport: { width: 320, height: 800 }, colorScheme: "light" },
		},
		{
			name: "narrow-dark",
			use: { viewport: { width: 375, height: 812 }, colorScheme: "dark" },
		},
	],
});
