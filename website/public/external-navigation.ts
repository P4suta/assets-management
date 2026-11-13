function confirmExternalNavigation(event: MouseEvent): void {
	if (!(event.target instanceof Element) || event.defaultPrevented) return;
	if (event.type === "auxclick" && event.button !== 1) return;
	const link: Element | null = event.target.closest("a[href]");
	if (!(link instanceof HTMLAnchorElement)) return;
	let destination: URL;
	try {
		destination = new URL(link.href, window.location.href);
	} catch {
		event.preventDefault();
		return;
	}
	const web: boolean = ["https:", "http:"].includes(destination.protocol);
	if (web && destination.origin === window.location.origin) return;
	if (destination.protocol === "tel:") return;
	if (!web && destination.protocol !== "mailto:") {
		event.preventDefault();
		return;
	}
	if (!window.confirm(`外部リンクを開きます。\n${destination.href}`)) {
		event.preventDefault();
	}
}

document.addEventListener("click", confirmExternalNavigation);
document.addEventListener("auxclick", confirmExternalNavigation);
