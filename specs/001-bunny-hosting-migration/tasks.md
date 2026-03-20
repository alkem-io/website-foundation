# Tasks: Migrate Hosting from Netlify to Bunny.net

**Input**: Design documents from `/specs/001-bunny-hosting-migration/`
**Prerequisites**: plan.md (required), spec.md (required)

**Organization**: Tasks are grouped by user story. Stories 1–3 are P1 and should be completed before Stories 4 (P2). Manual/external tasks (Bunny dashboard, DNS) are clearly marked.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- **[MANUAL]**: Performed outside the repo (Bunny dashboard, DNS provider, GitHub settings)

---

## Phase 1: External Setup (Manual Prerequisites)

**Purpose**: Create the Bunny.net resources and GitHub secrets that the workflow and edge rules depend on. Nothing in-repo can be deployed until these exist.

- [ ] T001 [MANUAL] [US1] Create Bunny Storage Zone for draft (e.g. `alkemio-foundation-draft`, EU region)
- [ ] T002 [MANUAL] [US1] Create Bunny Storage Zone for production (e.g. `alkemio-foundation-prod`, EU region)
- [ ] T003 [MANUAL] [US1] Create Bunny Pull Zone for draft, origin = draft storage zone, custom domain `draft.alkemio.org`
- [ ] T004 [MANUAL] [US1] Create Bunny Pull Zone for production, origin = prod storage zone, custom domain `alkemio.org`
- [ ] T005 [MANUAL] [US1] Provision SSL/TLS certificates on both pull zones (Bunny free Let's Encrypt)
- [ ] T006 [MANUAL] [US1] Add GitHub repository secrets: `BUNNY_API_KEY`, `BUNNY_STORAGE_ZONE_DRAFT`, `BUNNY_STORAGE_ZONE_PROD`, `BUNNY_STORAGE_API_KEY_DRAFT`, `BUNNY_STORAGE_API_KEY_PROD`, `BUNNY_PULL_ZONE_ID_DRAFT`, `BUNNY_PULL_ZONE_ID_PROD`

**Checkpoint**: Bunny infrastructure ready. GitHub secrets configured. Workflow can now deploy.

---

## Phase 2: US1 — Automated Two-Environment Deploy (Priority: P1)

**Goal**: GitHub Actions builds Hugo and deploys to the correct Bunny Storage Zone based on branch.

**Independent Test**: Push to `develop`, verify files appear in draft storage zone. Push to `main`, verify files appear in prod storage zone. Visit both domains after DNS cutover.

### Implementation

- [ ] T007 [US1] Create `.github/workflows/deploy.yml` — single workflow triggered on push to `develop` and `main`. Steps: checkout, setup Go 1.21, setup Hugo 0.148.2 extended, npm install, Hugo build with branch-dependent base URL (`https://draft.alkemio.org` or `https://alkemio.org`), upload `public/` to branch-dependent Bunny Storage Zone, purge branch-dependent Bunny Pull Zone cache. Use `concurrency: deploy-${{ github.ref_name }}` to prevent overlapping deploys.
- [ ] T008 [US1] Test workflow on `develop` branch — push a minor change, verify GitHub Actions run succeeds, files land in draft storage zone.
- [ ] T009 [US1] Test workflow on `main` branch — merge to main, verify files land in prod storage zone.

**Checkpoint**: Automated builds deploy to both Bunny storage zones. Sites are accessible via Bunny pull zone hostnames (not yet custom domains).

---

## Phase 3: US2 — Security Headers & Redirects (Priority: P1)

**Goal**: Both Bunny Pull Zones serve the same security headers and redirects that Netlify currently provides.

**Independent Test**: `curl -I https://draft.alkemio.org/` returns all expected security headers. `curl -I https://draft.alkemio.org/post/test` returns 301 to `/blog/test`.

### Implementation

- [ ] T010 [MANUAL] [P] [US2] Configure Edge Rule on draft pull zone: add response headers `X-Frame-Options: SAMEORIGIN`, `X-XSS-Protection: 1; mode=block`, `X-Content-Type-Options: nosniff`, `Report-To` (JSON blob per plan.md)
- [ ] T011 [MANUAL] [P] [US2] Configure Edge Rule on draft pull zone: add `Content-Security-Policy` header per plan.md Phase 3 (Netlify domains removed, `submit-form.com` added to `form-action`)
- [ ] T012 [MANUAL] [P] [US2] Configure Edge Rule on draft pull zone: redirect `/post/*` → `/blog/*` with 301 status
- [ ] T013 [MANUAL] [P] [US2] Replicate all three Edge Rules (T010–T012) on the production pull zone
- [ ] T014 [US2] Verify headers on draft: `curl -I https://<draft-pullzone-hostname>/` — confirm all headers present, no Netlify domains in CSP
- [ ] T015 [US2] Verify redirect on draft: `curl -I https://<draft-pullzone-hostname>/post/test` — confirm 301 to `/blog/test`

**Checkpoint**: Both pull zones serve correct security headers and redirects. No Netlify references in CSP.

---

## Phase 4: US3 — Contact Form Migration (Priority: P1)

**Goal**: Footer contact form and contact page hero form submit to `submit-form.com/2DIOCxGJ5` instead of Netlify Forms.

**Independent Test**: Visit draft site, fill in the footer contact form, submit. Verify submission arrives in submit-form.com dashboard.

### Implementation

- [ ] T016 [P] [US3] Update `config/_default/params.toml` line 21: change `contact_form_action = "#"` to `contact_form_action = "https://submit-form.com/2DIOCxGJ5"`
- [ ] T017 [P] [US3] Create project-level footer override at `layouts/partials/essentials/footer.html` — copy from `themes/fortify-hugo/layouts/partials/essentials/footer.html`, then modify the active contact form (lines 86–103): set `action="https://submit-form.com/2DIOCxGJ5"`, remove `data-netlify="true"` attribute, remove `netlify-honeypot="bot-field"` attribute, remove hidden `<input type="hidden" name="form-name" value="contact" />`, remove honeypot `<p class="hidden">...</p>` block. Keep all form fields (name, email, message) and styling intact.
- [ ] T018 [US3] Verify locally: run `hugo server`, inspect footer form HTML — confirm action is `https://submit-form.com/2DIOCxGJ5`, confirm no Netlify attributes remain.
- [ ] T019 [US3] Verify contact page hero form: run `hugo server`, navigate to contact page — confirm the hero form action is `https://submit-form.com/2DIOCxGJ5` (inherited from `contact_form_action` param).
- [ ] T020 [US3] Deploy to draft (push to `develop`), submit test message via footer form, confirm submission received in submit-form.com dashboard.

**Checkpoint**: Contact forms work on submit-form.com. No Netlify Forms dependency remains.

---

## Phase 5: US4 — Remove Legacy Deployment Configs (Priority: P2)

**Goal**: Clean up all Netlify and Amplify artifacts from the repository.

**Independent Test**: `grep -ri "netlify\|amplify" --include="*.toml" --include="*.yml" --include="*.yaml" .` returns zero results (excluding `.git/`, `specs/`, and `node_modules/`).

### Implementation

- [ ] T021 [P] [US4] Delete `netlify.toml`
- [ ] T022 [P] [US4] Delete `static/_redirects`
- [ ] T023 [P] [US4] Delete `amplify.yml`
- [ ] T024 [US4] Update `go.mod`: change module path from `hugoplate.netlify.app` to `alkemio.foundation` (or another non-Netlify name)
- [ ] T025 [US4] Run `hugo mod tidy` to regenerate `go.sum` after `go.mod` change
- [ ] T026 [US4] Run `hugo` locally to verify the build still succeeds after module path change
- [ ] T027 [US4] Remove the commented-out Netlify Forms version of the footer form from the project-level `layouts/partials/essentials/footer.html` override (lines 52–76 in original theme file, if carried over in T017)

**Checkpoint**: Repository contains zero Netlify/Amplify configuration. Build still succeeds.

---

## Phase 6: DNS Cutover & Validation (Manual)

**Goal**: Point custom domains to Bunny and verify everything end-to-end.

### Pre-cutover

- [ ] T028 [MANUAL] [US1] Verify draft site accessible via Bunny pull zone hostname (before DNS change)
- [ ] T029 [MANUAL] [US1] Verify production site accessible via Bunny pull zone hostname (before DNS change)
- [ ] T030 [MANUAL] [US2] Spot-check security headers and redirects on both pull zone hostnames

### DNS change

- [ ] T031 [MANUAL] [US1] Update DNS: point `draft.alkemio.org` CNAME to draft Bunny pull zone hostname
- [ ] T032 [MANUAL] [US1] Update DNS: point `alkemio.org` to production Bunny pull zone hostname (CNAME, or A/ALIAS if apex domain)

### Post-cutover validation

- [ ] T033 [US1] Verify `https://draft.alkemio.org` loads correctly with valid SSL
- [ ] T034 [US1] Verify `https://alkemio.org` loads correctly with valid SSL
- [ ] T035 [US2] Verify `curl -I https://alkemio.org/` returns all security headers
- [ ] T036 [US2] Verify `curl -I https://alkemio.org/post/test` returns 301 redirect
- [ ] T037 [US3] Submit contact form on `https://alkemio.org`, verify received in submit-form.com
- [ ] T038 [MANUAL] Decommission Netlify site (after DNS fully propagated and verified stable for 48+ hours)

**Checkpoint**: Migration complete. Both environments live on Bunny.net. Netlify decommissioned.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (External Setup)
  └──► Phase 2 (Deploy Workflow)  ── can start in-repo work before Phase 1,
  │                                   but cannot test deploys until zones exist
  └──► Phase 3 (Edge Rules)       ── needs pull zones from Phase 1

Phase 4 (Contact Form)            ── independent, can run in parallel with Phase 2/3

Phase 5 (Cleanup)                 ── should wait until Phase 2+3+4 verified on draft

Phase 6 (DNS Cutover)             ── depends on ALL previous phases being complete
```

### Parallel Opportunities

- **T001–T006** (Phase 1): All manual tasks can be done in one Bunny dashboard session
- **T010–T013** (Phase 3): All edge rules can be configured in parallel across both zones
- **T016–T017** (Phase 4): `params.toml` and footer override are independent files
- **T021–T023** (Phase 5): All file deletions are independent
- **Phase 2 + Phase 4**: Can be developed in parallel (different files, no overlap)

### Critical Path

```
T001–T006 → T007 → T008 → T010–T015 → T031–T032 → T033–T038
                     ↕ (parallel)
              T016–T017 → T018–T020
```

---

## Notes

- Phase 1 (external setup) is the prerequisite for everything — do this first
- Phase 4 (contact form) can be merged to `develop` and deployed to current Netlify safely — submit-form.com works from any host, so this is a zero-risk early merge
- Phase 5 (cleanup) should be the last in-repo change — only after both environments are verified on Bunny
- Keep Netlify active until at least 48 hours after DNS cutover to handle any propagation lag
