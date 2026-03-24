# Implementation Plan: Migrate Hosting from Netlify to Bunny.net

**Feature Branch**: `001-bunny-hosting-migration`
**Created**: 2026-03-20
**Status**: Draft

## Summary

Migrate the Alkemio Foundation Hugo website from Netlify to Bunny.net CDN with a two-environment deployment model (`develop` → `draft.alkemio.org`, `main` → `alkemio.org`). Replace Netlify's build/deploy/CDN/headers/forms with GitHub Actions CI/CD, Bunny Storage + Pull Zones, Bunny Edge Rules, and formspark.io for the contact form.

## Technical Context

| Aspect | Value |
|---|---|
| **Language** | Go templates (Hugo), HTML, CSS, JavaScript |
| **Framework** | Hugo 0.148.2 (static site generator) |
| **CSS** | TailwindCSS 4.x with custom plugin |
| **Theme** | fortify-hugo (in `themes/`) |
| **Current hosting** | Netlify (build + CDN + forms + headers + redirects) |
| **Target hosting** | Bunny.net (Storage Zone + Pull Zone + Edge Rules) |
| **CI/CD** | GitHub Actions (new) |
| **Form backend** | formspark.io (replacing Netlify Forms) |
| **Environments** | Draft (`develop` → `draft.alkemio.org`), Production (`main` → `alkemio.org`) |
| **Package manager** | npm |
| **Node version** | 20 |

## Architecture

```text
┌─────────────┐     push develop     ┌──────────────────┐     upload      ┌─────────────────────┐
│   GitHub     │ ──────────────────── │  GitHub Actions   │ ─────────────► │ Bunny Storage Zone  │
│   Repository │     push main        │  (Hugo build)     │                │ (draft / prod)      │
└─────────────┘                       └──────────────────┘                └─────────────────────┘
                                              │                                     │
                                              │ purge cache                         │ origin
                                              ▼                                     ▼
                                      ┌──────────────────┐                ┌─────────────────────┐
                                      │ Bunny API        │                │ Bunny Pull Zone     │
                                      │ (cache purge)    │                │ + Edge Rules        │
                                      └──────────────────┘                │ (headers, redirects)│
                                                                          └─────────────────────┘
                                                                                    │
                                                                          DNS CNAME │
                                                                                    ▼
                                                                          draft.alkemio.org
                                                                          alkemio.org
```

### Contact form flow

```text
Browser POST ──► https://formspark.io/2DIOCxGJ5 ──► formspark.io dashboard / email
```

## Constitution Check

| Principle | Impact | Notes |
|---|---|---|
| I. Hugo Theme Integrity | **Affected** — footer.html in theme must be modified to remove Netlify Forms attributes. The theme override mechanism (project-level `layouts/`) is used per Phase 4. |
| III. Configuration Consistency | **Affected** — `netlify.toml` removed; deployment config moves to `.github/workflows/`. `params.toml` updated for form action. |
| IV. Asset Pipeline | Not affected |
| V. Internationalisation | Not affected |
| VI. Deployment Safety | **Affected** — deployment mechanism changes entirely. Must ensure both environments work before DNS cutover. |

**Constitution action**: Override `themes/fortify-hugo/layouts/partials/essentials/footer.html` by placing the modified version at `layouts/partials/essentials/footer.html` (Hugo project-level override). Do NOT modify the theme file directly.

## Changes Required

### Phase 1: External Setup (Manual Prerequisites)

**Goal**: Create the Bunny.net resources and GitHub secrets that the workflow and edge rules depend on. Nothing in-repo can be deployed until these exist.

- Create Bunny Storage Zones (draft + production, EU region)
- Create Bunny Pull Zones (draft + production, with custom domains)
- Provision SSL/TLS certificates on both pull zones
- Add GitHub repository secrets: `BUNNY_API_KEY`, `BUNNY_STORAGE_ZONE_DRAFT`, `BUNNY_STORAGE_ZONE_PROD`, `BUNNY_STORAGE_API_KEY_DRAFT`, `BUNNY_STORAGE_API_KEY_PROD`, `BUNNY_PULL_ZONE_ID_DRAFT`, `BUNNY_PULL_ZONE_ID_PROD`

### Phase 2: GitHub Actions Workflow

**Goal**: Automated build and deploy on push to `develop` or `main`.

| # | File | Change |
|---|---|---|
| 2.1 | `.github/workflows/deploy.yml` | **Create** — single workflow with branch-based environment selection |

**Workflow design**:

```yaml
name: Build and Deploy
on:
  push:
    branches: [develop, main]

concurrency:
  group: deploy-${{ github.ref_name }}
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      HUGO_VERSION: "0.148.2"
    steps:
      # 1. Checkout with submodules (for Hugo theme)
      # 2. Setup Go 1.21+
      # 3. Setup Hugo 0.148.2 extended
      # 4. Setup Node 20 + npm install
      # 5. Build Hugo:
      #    - develop branch: hugo --gc --minify -b https://draft.alkemio.org
      #    - main branch:    hugo --gc --minify -b https://alkemio.org
      # 6. Upload public/ to Bunny Storage Zone (branch-dependent zone)
      #    - Use BunnyCDN Storage API or ayeressian/bunnycdn-storage-deploy action
      # 7. Purge Bunny Pull Zone cache via API
```

**Branch → environment mapping** (in workflow):

| Branch | Base URL | Storage Zone Secret | Pull Zone ID Secret |
|---|---|---|---|
| `develop` | `https://draft.alkemio.org` | `BUNNY_STORAGE_API_KEY_DRAFT` | `BUNNY_PULL_ZONE_ID_DRAFT` |
| `main` | `https://alkemio.org` | `BUNNY_STORAGE_API_KEY_PROD` | `BUNNY_PULL_ZONE_ID_PROD` |

**GitHub Secrets to configure** (manual, in repo settings):

| Secret | Purpose |
|---|---|
| `BUNNY_API_KEY` | Account-level API key for cache purge |
| `BUNNY_STORAGE_ZONE_DRAFT` | Storage zone name for draft |
| `BUNNY_STORAGE_ZONE_PROD` | Storage zone name for production |
| `BUNNY_STORAGE_API_KEY_DRAFT` | Storage zone password for draft |
| `BUNNY_STORAGE_API_KEY_PROD` | Storage zone password for production |
| `BUNNY_PULL_ZONE_ID_DRAFT` | Pull zone ID for draft (cache purge) |
| `BUNNY_PULL_ZONE_ID_PROD` | Pull zone ID for production (cache purge) |

### Phase 3: Bunny Edge Rules (Manual Configuration)

**Goal**: Replicate Netlify's headers and redirects on the Bunny Pull Zones.

These are configured in the Bunny.net dashboard (or via API), not in the repo. Document them here for reference.

**Edge Rules for each pull zone**:

1. **Security headers** (apply to all requests `/*`):
   - `X-Frame-Options: SAMEORIGIN`
   - `X-XSS-Protection: 1; mode=block`
   - `X-Content-Type-Options: nosniff`
   - `Report-To: {"group":"default","max_age":31536000,"endpoints":[{"url":"https://alkemio.report-uri.com/a/d/g"}],"include_subdomains":true}`
   - `Content-Security-Policy:` (see below)

2. **Redirect rule**: URL matches `/post/*` → 301 redirect to `/blog/*`

3. **Updated CSP** (Netlify domains removed, formspark.io added):
   ```
   default-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com;
   style-src 'self' 'unsafe-hashes' 'unsafe-inline' https://*.alkemio.org https://*.alkemio.foundation
     https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://api.fontshare.com;
   script-src 'self' 'unsafe-hashes' 'unsafe-inline' 'unsafe-eval' https://cdn.segment.com
     https://unpkg.com https://cdn.jsdelivr.net;
   font-src 'self' https://cdnjs.cloudflare.com https://api.fontshare.com https://use.fontawesome.com data:;
   connect-src 'self' https://cdn.segment.com;
   img-src 'self' blob: data: https:;
   form-action 'self' https://formspark.io;
   base-uri 'self';
   report-uri https://alkemio.report-uri.com/r/d/csp/enforce;
   ```

   **Changes from current CSP**:
   - Removed: `https://netlify.com`, `https://*.netlify.com`, `https://*.netlify.app`, `https://www.netlifystatus.com`
   - Added: `https://formspark.io` to `form-action`

### Phase 4: Contact Form Migration

**Goal**: Replace Netlify Forms with formspark.io so the form works regardless of hosting.

| # | File | Change |
|---|---|---|
| 4.1 | `config/_default/params.toml` | Set `contact_form_action = "https://formspark.io/2DIOCxGJ5"` |
| 4.2 | `config/draft/params.toml` | Set `contact_form_action = "https://formspark.io/XxoAI8RE2"` (separate draft endpoint) |
| 4.3 | `config/production/params.toml` | Set `contact_form_action = "https://formspark.io/2DIOCxGJ5"` |
| 4.4 | `layouts/partials/essentials/footer.html` | Create project-level override of the theme footer. Change the form: remove `data-netlify="true"`, `netlify-honeypot="bot-field"`, hidden `form-name` input, and honeypot `<p>`. Set `action` from `contact_form_action` param. |

**Files to create**:
- `layouts/partials/essentials/footer.html` (override of theme file)

**Files to modify**:
- `config/_default/params.toml` (line 21: `contact_form_action`)
- `config/draft/params.toml` (`contact_form_action`)
- `config/production/params.toml` (`contact_form_action`)

### Phase 5: Cleanup

**Goal**: Remove all Netlify/Amplify artifacts.

| # | File | Action |
|---|---|---|
| 4.1 | `netlify.toml` | **Delete** |
| 4.2 | `static/_redirects` | **Delete** |
| 4.3 | `amplify.yml` | **Delete** |
| 4.4 | `go.mod` | Update module path from `hugoplate.netlify.app` to a non-Netlify name (e.g., `alkemio.foundation`) |
| 4.5 | `go.sum` | Regenerate after `go.mod` change |

### Phase 6: DNS Cutover (Manual)

**Goal**: Point domains to Bunny Pull Zones.

| Domain | Record | Target |
|---|---|---|
| `draft.alkemio.org` | CNAME | Bunny pull zone hostname (draft) |
| `alkemio.org` | CNAME (or A/ALIAS for apex) | Bunny pull zone hostname (prod) |

**Pre-cutover checklist**:
1. Both Bunny Storage Zones created and pull zones configured
2. Edge Rules configured on both pull zones (headers, redirects, CSP)
3. SSL/TLS certificates provisioned on Bunny for both custom domains
4. GitHub Actions workflow tested — successful deploy to both zones
5. Contact form submission verified on draft environment
6. Visual spot-check of draft site against current Netlify site

## Bunny.net Setup (Manual, Pre-Implementation)

Before the GitHub Actions workflow can deploy, these resources must exist in the Bunny.net dashboard:

1. **Storage Zone — Draft**: name e.g. `alkemio-foundation-draft`, region EU
2. **Storage Zone — Production**: name e.g. `alkemio-foundation-prod`, region EU
3. **Pull Zone — Draft**: origin = draft storage zone, custom domain `draft.alkemio.org`
4. **Pull Zone — Production**: origin = prod storage zone, custom domain `alkemio.org`
5. **Edge Rules**: Configured per Phase 3 above on both pull zones
6. **SSL**: Free Let's Encrypt certificates for both custom domains (Bunny auto-provision)

## Risks

| Risk | Mitigation |
|---|---|
| DNS propagation delay during cutover | Deploy to Bunny first, verify, then switch DNS. Keep Netlify active until DNS fully propagates. |
| Bunny Edge Rules don't support CSP complexity | Test CSP header length limits. Fallback: inject CSP via a Hugo `<meta>` tag in `<head>` (less ideal but works). |
| formspark.io downtime | Low risk — simple third-party service. Monitor for failed submissions. |
| Hugo module path change breaks build | Test locally after `go.mod` module path update. Run `hugo mod tidy`. |
| Theme update overwrites footer override | The project-level `layouts/` override takes priority. Document this in the constitution. |

## Implementation Order

1. **Phase 1** — External setup (create Bunny zones, GitHub secrets — prerequisite for everything)
2. **Phase 2** — GitHub Actions workflow (can be tested without DNS change)
3. **Phase 3** — Bunny Edge Rules (manual, depends on zones from Phase 1)
4. **Phase 4** — Contact form (can run in parallel with Phase 2/3; formspark.io works from any host)
5. **Phase 5** — Cleanup (after Phases 2–4 verified on draft, remove Netlify/Amplify files)
6. **Phase 6** — DNS cutover (only after all above verified)
