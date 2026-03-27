# Feature Specification: Migrate Hosting from Netlify to Bunny.net

**Feature Branch**: `001-bunny-hosting-migration`
**Created**: 2026-03-20
**Status**: Draft
**Input**: Migrate the alkemio.foundation Hugo website from Netlify hosting to bunny.net CDN with GitHub Actions CI/CD

## Context

The site is currently hosted on Netlify, which provides build, CDN, redirects, security headers, and preview deploys. The migration moves to Bunny.net (Storage Zone + Pull Zone) with GitHub Actions replacing Netlify's build pipeline. An AWS Amplify config (`amplify.yml`) also exists as a legacy alternative and should be removed.

### Current Netlify Touchpoints

| File | Purpose | Migration action |
|---|---|---|
| `netlify.toml` | Build commands, env, contexts, redirects, headers (incl. CSP) | Replace with GH Actions + Bunny Edge Rules |
| `static/_redirects` | `/post/* → /blog/:splat` (301) | Bunny Edge Rule or Bunny `_redirects` |
| `amplify.yml` | Legacy AWS Amplify build config | Remove |
| `go.mod` | Module path `hugoplate.netlify.app` | Rename module path |
| CSP in `netlify.toml` | References `*.netlify.com`, `*.netlify.app`, `netlifystatus.com` | Remove Netlify domains |

## User Scenarios & Testing

### User Story 1 — Automated Two-Environment Deploy (Priority: P1)

The site has two deployment targets driven by branch:
- **`develop` → `draft.alkemio.org`** — staging/preview for content review
- **`main` → `alkemio.org`** — production site for public visitors

When a commit is pushed to either branch, the site is automatically built with Hugo and deployed to the corresponding Bunny.net CDN pull zone.

**Why this priority**: Without automated deploys to both environments nothing else matters — this is the core hosting function.

**Independent Test**: Push a content change to `develop`, verify it appears on `draft.alkemio.org`. Merge to `main`, verify it appears on `alkemio.org`.

**Acceptance Scenarios**:

1. **Given** a commit is pushed to `develop`, **When** the GitHub Actions workflow triggers, **Then** Hugo builds the site with `--gc --minify` and base URL `https://draft.alkemio.org`, uploads `public/` to the draft Bunny Storage Zone, and purges the draft Pull Zone cache.
2. **Given** a commit is pushed to `main`, **When** the GitHub Actions workflow triggers, **Then** Hugo builds with base URL `https://alkemio.org`, uploads `public/` to the production Bunny Storage Zone, and purges the production Pull Zone cache.
3. **Given** the Hugo build fails (e.g., template error), **When** the workflow runs, **Then** no files are uploaded to Bunny Storage and the workflow reports failure.
4. **Given** the site is deployed, **When** a visitor requests the corresponding domain, **Then** the page loads with correct content, styles, and assets served from Bunny CDN.

---

### User Story 2 — Security Headers & Redirects (Priority: P1)

The migrated site serves the same security headers (CSP, X-Frame-Options, etc.) and redirects (`/post/* → /blog/*`) that were previously configured in `netlify.toml`, so there is no security regression.

**Why this priority**: Security headers and redirects are critical for the live site. Without them, CSP violations go unreported and legacy URLs break.

**Independent Test**: After deploy, check response headers with `curl -I` and verify redirect behaviour for `/post/` URLs.

**Acceptance Scenarios**:

1. **Given** the site is deployed to Bunny, **When** any page is requested, **Then** the response includes `X-Frame-Options: SAMEORIGIN`, `X-XSS-Protection: 1; mode=block`, `X-Content-Type-Options: nosniff`, and a `Content-Security-Policy` header.
2. **Given** the CSP header is configured, **When** inspecting its value, **Then** it does NOT reference any `netlify.com`, `netlify.app`, or `netlifystatus.com` domains.
3. **Given** a visitor requests `/post/some-article`, **When** the request hits Bunny, **Then** they receive a 301 redirect to `/blog/some-article`.

---

### User Story 3 — Contact Form Migration (Priority: P1)

The footer contact form currently uses Netlify Forms (`data-netlify="true"`), which will stop working once Netlify is removed. The form must be migrated to formspark.io (`https://formspark.io/2DIOCxGJ5`). The contact page hero form (currently non-functional, action `#`) should also be pointed at the same endpoint.

**Why this priority**: Without this, the contact form silently breaks on day one of the migration. Users cannot reach the team.

**Independent Test**: Submit the footer contact form on `draft.alkemio.org`, verify the submission arrives in the formspark.io dashboard.

**Acceptance Scenarios**:

1. **Given** the footer form is rendered, **When** inspecting the HTML, **Then** the form action is `https://formspark.io/2DIOCxGJ5`, the method is POST, and all Netlify-specific attributes (`data-netlify`, `netlify-honeypot`, hidden `form-name` input) are removed.
2. **Given** a user fills in name, email, and message and clicks send, **When** the form submits, **Then** the submission is received by formspark.io and the user sees a confirmation.
3. **Given** the contact page hero form exists, **When** inspecting its HTML, **Then** its action is also `https://formspark.io/2DIOCxGJ5` (via the `contact_form_action` param in `params.toml`).
4. **Given** the CSP is configured, **When** inspecting the `form-action` directive, **Then** it includes `https://formspark.io` alongside `'self'`.

---

### User Story 4 — Remove Legacy Deployment Configs (Priority: P2)

All Netlify and Amplify configuration is removed from the repository so there is a single, clear deployment path.

**Why this priority**: Avoids confusion about which config is active. Should happen alongside or after the new pipeline is proven.

**Independent Test**: Grep the repo for `netlify` and `amplify` — zero results outside of git history.

**Acceptance Scenarios**:

1. **Given** the migration is complete, **When** inspecting the repo, **Then** `netlify.toml`, `static/_redirects`, and `amplify.yml` have been deleted.
2. **Given** `go.mod` previously used `hugoplate.netlify.app` as the module path, **When** the migration is complete, **Then** the module path no longer references Netlify.
3. **Given** the CSP was previously defined in `netlify.toml`, **When** the migration is complete, **Then** the CSP definition lives in a documented, version-controlled location (e.g., a Bunny API config script or `.github/` config file).

---

### Edge Cases

- **Large asset uploads**: What happens if a Hugo build produces files exceeding Bunny Storage Zone limits? (Unlikely for a content site, but should error clearly.)
- **Concurrent deploys**: If two commits push in quick succession, the second workflow run should either queue or supersede the first — not produce a partial deploy.
- **Cache purge failure**: If the Bunny cache purge API call fails after a successful upload, the old content remains cached. The workflow should retry the purge or flag the failure prominently.
- **DNS propagation**: During the cutover window, some visitors may still hit Netlify while others hit Bunny. Content should be deployed to Bunny before the DNS change.
- **Branch name mismatch**: The current Netlify config builds from any branch. The GitHub Actions workflow must be scoped to the correct branches (`develop` for draft, `main` for production).

## Requirements

### Functional Requirements

- **FR-001**: A GitHub Actions workflow MUST build the Hugo site and deploy to Bunny Storage Zone on pushes to `develop` (→ `draft.alkemio.org`) and `main` (→ `alkemio.org`).
- **FR-002**: The workflow MUST use Hugo version 0.148.2 (matching current `netlify.toml`) and Go 1.21+.
- **FR-003**: The workflow MUST set the Hugo base URL to match the target environment (`https://draft.alkemio.org` or `https://alkemio.org`).
- **FR-004**: The workflow MUST purge the corresponding Bunny Pull Zone cache after a successful upload.
- **FR-005**: The workflow MUST fail and NOT upload if the Hugo build fails.
- **FR-006**: Security headers (X-Frame-Options, X-XSS-Protection, X-Content-Type-Options, Content-Security-Policy, Report-To) MUST be served on all responses from both environments.
- **FR-007**: The redirect `/post/* → /blog/*` MUST return HTTP 301.
- **FR-008**: The CSP MUST NOT reference Netlify domains (`netlify.com`, `netlify.app`, `netlifystatus.com`).
- **FR-009**: The CSP `form-action` directive MUST allow `https://formspark.io` in addition to `'self'`.
- **FR-010**: `netlify.toml`, `static/_redirects`, and `amplify.yml` MUST be removed from the repository.
- **FR-011**: The `go.mod` module path MUST be updated to remove the `netlify.app` reference.
- **FR-012**: The footer contact form MUST submit to `https://formspark.io/2DIOCxGJ5` via standard POST. All Netlify Forms attributes (`data-netlify`, `netlify-honeypot`, hidden `form-name` input) MUST be removed.
- **FR-013**: The `contact_form_action` parameter in `params.toml` MUST be set per environment: `https://formspark.io/2DIOCxGJ5` in `config/_default/params.toml` and `config/production/params.toml`, and `https://formspark.io/XxoAI8RE2` in `config/draft/params.toml`.
- **FR-014**: GitHub repository secrets MUST be used for all Bunny API keys — no secrets in committed files.
- **FR-015**: The workflow MUST use `concurrency` groups to prevent overlapping deploys to the same target.

### Key Entities

- **Bunny Storage Zones**: Two storage zones — one for draft (`draft.alkemio.org`), one for production (`alkemio.org`). Each holds the built `public/` output for its environment.
- **Bunny Pull Zones**: Two CDN distributions, each serving one storage zone. Custom domains pointed via DNS CNAME.
- **Bunny Edge Rules**: Configuration on each pull zone to handle redirects and inject security headers.
- **GitHub Actions Secrets**: Per-environment secrets: `BUNNY_API_KEY` (account-level, for cache purge), `BUNNY_STORAGE_API_KEY_DRAFT` / `BUNNY_STORAGE_API_KEY_PROD`, `BUNNY_STORAGE_ZONE_DRAFT` / `BUNNY_STORAGE_ZONE_PROD`, `BUNNY_PULL_ZONE_ID_DRAFT` / `BUNNY_PULL_ZONE_ID_PROD`.
- **formspark.io**: Third-party form backend receiving contact form submissions at endpoint `2DIOCxGJ5`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A push to `develop` results in the updated site being live on `draft.alkemio.org` within 5 minutes.
- **SC-002**: A push to `main` results in the updated site being live on `alkemio.org` within 5 minutes.
- **SC-003**: All six security headers currently served by Netlify are present in responses from both Bunny CDN environments (verified via `curl -I`).
- **SC-004**: The redirect `/post/anything` → `/blog/anything` returns HTTP 301 on both environments.
- **SC-005**: Zero references to `netlify.com`, `netlify.app`, or `amplify` remain in the repository (excluding git history and specs).
- **SC-006**: The contact form in the footer submits successfully to formspark.io and the submission is received.
- **SC-007**: The Bunny CDN serves both environments with a time-to-first-byte under 200ms from EU locations.
- **SC-008**: Hugo build failures prevent deployment — no partial or broken content reaches CDN.
- **SC-009**: All GitHub Actions workflows in the `alkem-io/website-foundation` repository are green (passing) on both `develop` and `main` branches.
