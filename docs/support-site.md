# Publish support pages

The app repository contains the public support and privacy pages under `website/`.
The public hostname is `assets-management.yasunobu.dev`.
The static build runs on Cloudflare Workers.
Cloudflare manages the hostname's certificate and Domain Name System (DNS) record.
The [hosting decision](adr/serve-support-pages-on-cloudflare-workers.md) keeps website publication independent of the app release.

From the repository root, run the fast website gate: `mise x -- just website-check`.
The gate installs dependencies, checks types, builds static assets, scans dependencies, and rehearses deployment.
Run the browser journeys and accessibility audit: `mise x -- just website-ui-test`.
The journeys check the palette, keyboard navigation, narrow layouts, and enlarged text.
The website runs no client scripts and receives no property records from the app.
Static response headers prevent automatic script injection with the documented [no-transform directive](https://developers.cloudflare.com/web-analytics/faq/).

The [website workflow](../.github/workflows/website.yml) verifies pull requests and changes on the default branch.
Only the default branch publishes the preserved candidate through a separate job.
The publication job uses the production environment, which accepts only the default branch.
Cloudflare credentials stay in the purpose-specific Doppler config.
GitHub stores a read-only Service Token for that config in its protected environment.
The initial provider token needs product-level administrative access to Workers and zone-specific route permissions.
After bootstrap, reduce its authority using the current [Workers permission model](https://developers.cloudflare.com/workers/authorization/workers/).
The configuration publishes only at the custom hostname.
After deployment, check the public pages: `SUPPORT_ORIGIN=https://assets-management.yasunobu.dev mise x -- just website-ui-test`.
The maintained HTML and styles live in `public/`.
The generated deployment assets live in `dist/`.
