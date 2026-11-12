import { writeFile } from "node:fs/promises";
import AxeBuilder from "@axe-core/playwright";
import { expect, type Page, type TestInfo, test } from "@playwright/test";

const pages = [
	{ path: "/", heading: "物件管理くん" },
	{ path: "/privacy/", heading: "プライバシーポリシー" },
	{ path: "/support/", heading: "使い方とお問い合わせ" },
] as const;

async function paletteIssues(page: Page): Promise<string[]> {
	return page.evaluate((): string[] => {
		const allowed = new Set([
			"black",
			"white",
			"#000",
			"#fff",
			"#000000",
			"#ffffff",
			"rgb(0, 0, 0)",
			"rgb(255, 255, 255)",
			"currentcolor",
			"inherit",
		]);
		const issues: string[] = [];
		const inspect = (rules: CSSRuleList): void => {
			for (const rule of rules) {
				if (rule instanceof CSSStyleRule) {
					const style = rule.style;
					for (const property of [
						"color",
						"background-color",
						"outline-color",
						"text-decoration-color",
						"fill",
						"stroke",
						"border-top-color",
						"border-right-color",
						"border-bottom-color",
						"border-left-color",
						"border-block-end-color",
						"border-block-start-color",
					]) {
						const value = style.getPropertyValue(property).trim().toLowerCase();
						if (
							value &&
							!allowed.has(value) &&
							!(property === "fill" && value === "none") &&
							!(property === "text-decoration-color" && value === "initial")
						)
							issues.push(`${property}:${value}`);
					}
					for (const property of [
						"background-image",
						"box-shadow",
						"text-shadow",
						"filter",
						"backdrop-filter",
					]) {
						const value = style.getPropertyValue(property).trim();
						if (value && value !== "none" && value !== "initial")
							issues.push(`${property}:${value}`);
					}
					const opacity = style.getPropertyValue("opacity");
					if (opacity && Number(opacity) !== 1)
						issues.push(`opacity:${opacity}`);
					const blend = style.getPropertyValue("mix-blend-mode");
					if (blend && blend !== "normal")
						issues.push(`mix-blend-mode:${blend}`);
				}
				if (rule instanceof CSSGroupingRule) inspect(rule.cssRules);
			}
		};
		for (const sheet of document.styleSheets) inspect(sheet.cssRules);
		for (const element of document.querySelectorAll<HTMLElement>(
			"body, h1, h2, p, a",
		)) {
			const style = getComputedStyle(element);
			if (!allowed.has(style.color.toLowerCase()))
				issues.push(`computed-color:${style.color}`);
			if (style.opacity !== "1")
				issues.push(`computed-opacity:${style.opacity}`);
		}
		return issues;
	});
}

async function checkLayout(page: Page): Promise<void> {
	expect(
		await page.evaluate(
			(): boolean => document.documentElement.scrollWidth <= innerWidth,
		),
	).toBe(true);
	for (const paragraph of await page.locator("main p").all()) {
		await paragraph.scrollIntoViewIfNeeded();
		await expect(paragraph).toBeVisible();
		expect(
			await paragraph.evaluate((element: HTMLElement): number =>
				Number.parseFloat(getComputedStyle(element).fontSize),
			),
		).toBeGreaterThanOrEqual(18);
	}
	for (const target of await page
		.locator(".nav-link:not(.skip-link), .action-link")
		.all()) {
		const box = await target.boundingBox();
		expect(box).not.toBeNull();
		expect(box?.width).toBeGreaterThanOrEqual(48);
		expect(box?.height).toBeGreaterThanOrEqual(48);
	}
}

for (const item of pages) {
	test(`readable and accessible page ${item.path}`, async ({
		page,
	}: {
		page: Page;
	}, testInfo: TestInfo): Promise<void> => {
		const response = await page.goto(item.path);
		expect(response?.ok()).toBe(true);
		if (process.env.SUPPORT_ORIGIN) {
			const headers = response?.headers() ?? {};
			const networkPolicy: unknown = JSON.parse(headers.nel ?? "null");
			const reportPolicy: unknown = JSON.parse(headers["report-to"] ?? "null");
			expect(networkPolicy).toMatchObject({ max_age: 0 });
			expect(reportPolicy).toMatchObject({ max_age: 0, endpoints: [] });
			expect(headers["reporting-endpoints"]).toBeUndefined();
		}
		await expect(page.getByRole("heading", { level: 1 })).toHaveText(
			item.heading,
		);
		await expect(page.locator("html")).toHaveAttribute("lang", "ja");
		await expect(page.locator("script")).toHaveCount(0);
		expect(await paletteIssues(page)).toEqual([]);
		await checkLayout(page);
		const audit = await new AxeBuilder({ page })
			.withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
			.analyze();
		expect(audit.violations).toEqual([]);
		await writeFile(
			testInfo.outputPath("visible-copy.md"),
			`${await page
				.locator("main h1, main h2, main p, nav a, .skip-link, footer p")
				.evaluateAll((elements: Element[]): string =>
					elements
						.map((element: Element): string => {
							const text = element.textContent?.trim() ?? "";
							return element.matches("main p") &&
								!element.querySelector(".action-link")
								? text
								: `## ${text}`;
						})
						.join("\n\n"),
				)}\n\n## ${await page.title()}\n\n${await page.locator('meta[name="description"]').getAttribute("content")}\n`,
		);
		await page.screenshot({
			path: testInfo.outputPath("page.png"),
			fullPage: true,
		});
	});

	test(`enlarged text and spacing on ${item.path}`, async ({
		page,
	}: {
		page: Page;
	}): Promise<void> => {
		await page.goto(item.path);
		await page.addStyleTag({
			content:
				"html { font-size: 225%; } p, a { line-height: 1.5; letter-spacing: 0.12em; word-spacing: 0.16em; } p { margin-bottom: 2em; }",
		});
		await checkLayout(page);
	});
}

test("navigation and browser history preserve the destination", async ({
	page,
}: {
	page: Page;
}): Promise<void> => {
	await page.goto("/");
	await page
		.getByRole("link", { name: "使い方とお問い合わせ", exact: true })
		.click();
	await expect(page).toHaveURL(/\/support\/$/);
	await page
		.getByRole("link", { name: "プライバシーポリシー", exact: true })
		.click();
	await expect(page).toHaveURL(/\/privacy\/$/);
	await expect(
		page.getByRole("link", { name: "hi@sakashita.email" }),
	).toHaveAttribute("href", "mailto:hi@sakashita.email");
	await page.goBack();
	await expect(page).toHaveURL(/\/support\/$/);
	await page
		.getByRole("navigation")
		.getByRole("link", { name: "物件管理くん" })
		.click();
	await expect(page.getByRole("heading", { level: 1 })).toHaveText(
		"物件管理くん",
	);
});

test("keyboard access reaches the content and links", async ({
	page,
}: {
	page: Page;
}): Promise<void> => {
	await page.goto("/privacy/");
	await page.keyboard.press("Tab");
	await expect(page.getByRole("link", { name: "本文へ移動" })).toBeFocused();
	await page.keyboard.press("Enter");
	await expect(page.locator("main")).toBeFocused();
	await page.keyboard.press("Tab");
	await expect(
		page.getByRole("link", { name: "hi@sakashita.email" }),
	).toBeFocused();
	expect(
		await page
			.getByRole("link", { name: "hi@sakashita.email" })
			.evaluate(
				(element: HTMLElement): string =>
					getComputedStyle(element).outlineStyle,
			),
	).toBe("solid");
});

const rejectedStyles = [
	{ property: "color", css: "p { color: #777; }" },
	{
		property: "background-color",
		css: "p { background-color: rgba(0, 0, 0, 0.5); }",
	},
	{
		property: "background-image",
		css: "p { background-image: linear-gradient(black, white); }",
	},
	{ property: "box-shadow", css: "p { box-shadow: 0 1px 2px black; }" },
	{ property: "opacity", css: "p { opacity: 0.5; }" },
	{ property: "filter", css: "p { filter: blur(1px); }" },
	{ property: "mix-blend-mode", css: "p { mix-blend-mode: multiply; }" },
] as const;

for (const fixture of rejectedStyles) {
	test(`the palette gate rejects ${fixture.property}`, async ({
		page,
	}: {
		page: Page;
	}): Promise<void> => {
		await page.setContent(
			"<!doctype html><html><body><p>Fixture</p></body></html>",
		);
		await page.addStyleTag({
			content: "body { color: black; background: white; }",
		});
		expect(await paletteIssues(page)).toEqual([]);
		await page.addStyleTag({ content: fixture.css });
		expect(
			(await paletteIssues(page)).some((issue: string): boolean =>
				issue.startsWith(`${fixture.property}:`),
			),
		).toBe(true);
	});
}
