<!--
Sync Impact Report
- Version: 1.1.0
- 1.1.0: Tightened Deployment Safety with deterministic build check; removed Development Workflow section (moved to CLAUDE.md)
- 1.0.0: Initial ratification
- Follow-up TODOs: none
-->

# Alkemio Foundation Website Constitution

## Core Principles

### I. Hugo Theme Integrity

- The website uses the **fortify-hugo** theme. Theme files in `themes/fortify-hugo/` MUST NOT be modified directly.
- Customisations MUST be applied via Hugo's override mechanism: place overriding files in the project-level `layouts/`, `assets/`, or `static/` directories.
- Theme updates MUST be tested against existing content before deployment.

### II. Content Structure Fidelity

- All content lives under `content/english/` following Hugo's content organisation conventions.
- Content files use Hugo front matter (TOML or YAML) and Markdown body.
- Shortcodes and partials MUST be used consistently — no inline HTML in content files unless absolutely necessary.
- Data-driven content (e.g., team members, partners) MUST use Hugo data files in `data/` rather than hardcoded markup.

### III. Configuration Consistency

- Site configuration is centralised in `hugo.toml` at the repository root.
- Environment-specific overrides use Hugo's configuration directory pattern or build-time environment variables.
- Deployment configuration (`.github/workflows/deploy.yml`) MUST stay in sync with the Hugo build commands and output directory.

### IV. Asset Pipeline

- Static assets (images, fonts, documents) go in `static/`.
- Processed assets (SCSS/CSS, JS requiring bundling) go in `assets/` and are handled by Hugo Pipes.
- TailwindCSS configuration and plugins (`tailwind-plugin/`) MUST be maintained alongside Hugo's asset pipeline.
- Build stats (`hugo_stats.json`) are auto-generated and MUST NOT be manually edited.

### V. Internationalisation Readiness

- The site supports multiple languages via Hugo's i18n system (`i18n/` directory, `defaultContentLanguage` setting).
- All user-facing strings SHOULD use i18n keys rather than hardcoded English text in templates.
- Content translations follow Hugo's filename convention (e.g., `index.md`, `index.fr.md`).

### VI. Deployment Safety

- The site deploys via GitHub Actions (`.github/workflows/deploy.yml`) to Bunny CDN. A deployment is "working" when: (1) `hugo --gc --minify` exits 0, (2) all files upload to the Bunny Storage Zone, and (3) the Bunny Pull Zone cache purge succeeds.
- Hugo version used in CI MUST match the version specified in the workflow (`HUGO_VERSION` env var). Local development SHOULD use the same version.
- All changes MUST pass `hugo` locally before pushing. A pre-commit hook or CI check SHOULD enforce this deterministically.

## Governance

- This constitution is the authoritative source for project-wide engineering principles and constraints.
- All code changes (PRs, reviews) MUST be verified against these principles before merge.
- Amendments to this constitution require:
  1. A documented rationale for the change.
  2. A version bump following semantic versioning (MAJOR for principle removals/redefinitions, MINOR for additions, PATCH for clarifications).
  3. An updated Sync Impact Report (HTML comment at top of this file).

**Version**: 1.1.0 | **Ratified**: 2026-03-20 | **Updated**: 2026-03-24
