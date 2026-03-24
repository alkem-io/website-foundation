<!--
Sync Impact Report
- Version: 1.0.0
- Initial ratification
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

- The site deploys via GitHub Actions to Bunny CDN. The workflow in `.github/workflows/deploy.yml` MUST produce a working site.
- Hugo version used in CI MUST match the version used for local development.
- All changes MUST be verified with a local `hugo` build before pushing to avoid broken deployments.

## Development Workflow

- **Static site generator**: Hugo (Go-based)
- **Theme**: fortify-hugo (in `themes/`)
- **CSS**: TailwindCSS with custom plugin (`tailwind-plugin/`)
- **Content**: Markdown with Hugo front matter in `content/english/`
- **Data**: YAML/TOML/JSON files in `data/`
- **Build**: `hugo` for production, `hugo server` for local development
- **Deployment**: GitHub Actions + Bunny CDN (`.github/workflows/deploy.yml`)

## Governance

- This constitution is the authoritative source for project-wide engineering principles and constraints.
- All code changes (PRs, reviews) MUST be verified against these principles before merge.
- Amendments to this constitution require:
  1. A documented rationale for the change.
  2. A version bump following semantic versioning (MAJOR for principle removals/redefinitions, MINOR for additions, PATCH for clarifications).
  3. An updated Sync Impact Report (HTML comment at top of this file).

**Version**: 1.0.0 | **Ratified**: 2026-03-20
