---
date: 2026-11-12
status: proposed
---

# Serve support pages from the app repository

## Context

App Store distribution needs public support and privacy pages.
Support pages use the same hosting approach as Gymemo.
The approved hostname is `assets-management.yasunobu.dev`.
The Cloudflare zone is active.

## Decision

Keep the static pages, browser tests, and deployment configuration in the app repository under `website/`.
Publish [Cloudflare Workers static assets](https://developers.cloudflare.com/workers/static-assets/) through GitHub Actions after verification.
Bind the approved hostname as a [Custom Domain](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/), which manages Domain Name System (DNS) records and the certificate.
Website publication remains independent of app distribution.

## Alternatives

The Sites service simplifies deployment but adds a separate source repository and hosting domain outside the requested Cloudflare delivery.
A separate Cloudflare website repository offers independent history but splits the app and policy sources.

## Consequences

The repository must check the website and pin its deployment tool.
Credentials remain outside the repository.
The app continues to store its records on the device.

## Confirmation

Require type checks, browser journeys, dependency scanning, and a deployment dry run before publication.
Verify the public pages over HTTPS at the approved hostname after publication.
Reconsider when the website needs server behavior or the owner changes hosting providers.
