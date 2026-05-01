# Omni Bridge — Web Landing

Marketing landing page for Omni Bridge. Static Next.js export, deployed to Firebase Hosting at:

- Production: <https://omnibridge.marshalx.dev>
- UAT: <https://uat.omnibridge.marshalx.dev>
- PR previews: auto-generated Firebase preview channels (URL posted to the PR)

## Stack

- Next.js 16 (App Router, static export — `output: 'export'`)
- React 19
- TypeScript, strict mode
- Plain CSS (single `globals.css`) — no Tailwind, no UI lib

Theme tokens mirror `lib/core/theme/app_theme.dart` so the site stays visually consistent with the desktop app.

## Develop

```bash
cd web_landing
npm install
npm run dev          # http://localhost:3000
npm run build        # static export to ./out
```

## Deploy

CI handles all deploys ([.github/workflows/web_landing_ci.yml](../.github/workflows/web_landing_ci.yml)):

| Trigger | Target |
|---|---|
| PR opened/updated touching `web_landing/**` | Firebase preview channel (URL posted to PR) |
| Push to `uat` branch | `https://uat.omnibridge.marshalx.dev` |
| Push to `main` branch | `https://omnibridge.marshalx.dev` (requires `production` environment approval) |

Manual local deploy (rare):

```bash
npm run build
firebase deploy --only hosting:omnibridge --project omni-bridge-ai-translator
```

## Files

```
src/
  app/
    layout.tsx        # root layout, metadata, fonts
    page.tsx          # home (composes all sections)
    globals.css       # all styles — kept in one file by design
  components/
    Navbar.tsx
    Hero.tsx
    Features.tsx
    Engines.tsx
    HowItWorks.tsx
    Pricing.tsx
    Platforms.tsx
    Footer.tsx
```

## Domain & DNS

See [docs/05_maintenance/27_domains_and_subdomains.md](../docs/05_maintenance/27_domains_and_subdomains.md) for the canonical domain inventory, Cloudflare proxy state, and TLS issuer per record.
