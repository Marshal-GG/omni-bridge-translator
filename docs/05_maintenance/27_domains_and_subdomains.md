# 27 — Domains & Subdomains

> **Category:** Infrastructure · **Status:** Active — landing page on Firebase Hosting, app uses Firebase backend SDKs (no public API subdomain)

Canonical inventory of every public-facing hostname Omni Bridge uses. Cross-link this whenever a new public surface is introduced.

---

## Naming philosophy

| Decision | Rationale |
|---|---|
| Use `omnibridge.marshalx.dev` as the eTLD+1 | Owner already owns `marshalx.dev`. No need to register a brand TLD until product traction warrants it. |
| Apex (`omnibridge.marshalx.dev`) is the **marketing landing page** | Static, public, low risk. The desktop app talks to Firebase / RTDB / Razorpay directly — no public API subdomain needed. |
| Subdomains over paths for new concerns | DNS routing is free and out of the request path. Path-based routing requires an owned proxy. |
| Cloudflare proxy state per-record | Apex must be **proxy off** (Firebase TLS handshake required for cert provisioning). Anything sitting behind Cloudflare Workers / Tunnel can be **proxy on**. |

---

## Live domains

| Hostname | Purpose | Backed by | DNS provider | CF proxy | TLS issuer | Notes |
|---|---|---|---|---|---|---|
| `omnibridge.marshalx.dev` | Marketing landing page | Firebase Hosting (Next.js static export, target `omnibridge`) | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase | Proxy must be OFF — Firebase performs the TLS handshake directly. Turning proxy on breaks renewal. |
| `uat.omnibridge.marshalx.dev` | UAT / staging landing page | Firebase Hosting (`uat` channel on the `omnibridge` target) | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase | Same TLS constraint as apex. 30-day channel TTL, auto-renewed on every push to the `uat` branch. |
| `*.omni-bridge-landing.web.app` | Firebase auto-generated PR-preview channels | Firebase Hosting | Firebase | n/a | Firebase | Temporary URLs created per pull request, deleted when the PR closes. Posted by the Firebase action as a PR comment. Not user-facing. |

The Firebase site name is `omni-bridge-landing` (must be globally unique on Firebase). `firebase.json` references it via the target alias `omnibridge`, mapped in `.firebaserc`.

---

## Cloudflare DNS records to add

The DNS records below need to exist in the `marshalx.dev` zone before either deploy will resolve. Set them once — the Firebase action handles cert provisioning automatically when the custom domain is connected.

| Type | Name | Value | Proxy | TTL |
|---|---|---|---|---|
| A | `omnibridge` | (Firebase will surface 2 IPs in Hosting console) | OFF | Auto |
| A | `omnibridge` | (second Firebase IP) | OFF | Auto |
| TXT | `omnibridge` | `firebase=omni-bridge-landing` (verification record from Firebase console) | n/a | Auto |
| A | `uat.omnibridge` | (same 2 Firebase IPs as apex) | OFF | Auto |
| A | `uat.omnibridge` | (second Firebase IP) | OFF | Auto |
| TXT | `uat.omnibridge` | `firebase=omni-bridge-landing` | n/a | Auto |

Get the actual IPs and TXT verification token from **Firebase Console → Hosting → Custom domains → Add custom domain** for each of `omnibridge.marshalx.dev` and `uat.omnibridge.marshalx.dev`. Provision the apex first, then the UAT subdomain on the same site.

---

## CI / CD

Workflow: [.github/workflows/web_landing_ci.yml](../../.github/workflows/web_landing_ci.yml)

| Trigger | Target | Approval |
|---|---|---|
| PR opened/updated touching `web_landing/**` | Firebase preview channel | None — auto-deploys, URL posted to the PR |
| Push to `uat` branch | `https://uat.omnibridge.marshalx.dev` | None — auto-deploys |
| Push to `main` branch | `https://omnibridge.marshalx.dev` | **Required** — `production` GitHub Environment gate |

### Required secrets

Add these in **GitHub repo → Settings → Secrets and variables → Actions**:

| Secret | Source |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_OMNI_BRIDGE` | Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the entire JSON. |

### Required GitHub Environments

Set up in **GitHub repo → Settings → Environments**:

| Environment | Purpose | Recommended protection rules |
|---|---|---|
| `production` | Gate for `main → live` deploys | Required reviewers: at least 1 (yourself) · Wait timer: 0 min |
| `uat` | Visibility-only; no protection needed | None |

The `deploy-production` job uses `environment: production` so the deploy pauses for approval before pushing to the live channel. Without this gate, every merge to `main` would ship unreviewed.

---

## Cloudflare DNS provider notes

All records are managed in Cloudflare DNS for the `marshalx.dev` zone (shared with Fluxora and any future personal projects).

| Setting | Value | Why |
|---|---|---|
| DNSSEC | Enabled | Prevents DNS hijacking. |
| Proxy default for new records | OFF | Firebase needs explicit proxy decisions; safer to opt in than out. |
| TTL | Auto (~5 min) | Lets us flip records quickly during incidents. |
| Email DMARC/SPF | Out of scope | No `support@omnibridge.marshalx.dev` email yet. When added, document SPF/DKIM/DMARC here. |

---

## Reserved / deferred

Not on the roadmap, but pre-noted so they aren't claimed accidentally.

| Hostname | Intended purpose | Trigger to provision |
|---|---|---|
| `api.omnibridge.marshalx.dev` | If we ever expose a public REST surface (e.g. SaaS subscriptions, server health endpoint) outside Firebase Cloud Functions | Currently all backend traffic uses Firebase SDKs which talk to Google-hosted endpoints directly. Reconsider only if a self-hosted backend is added. |
| `docs.omnibridge.marshalx.dev` | If user-facing docs ever split out from the marketing site or GitHub repo | When `/docs` on the apex grows beyond ~10 pages. |
| `cdn.omnibridge.marshalx.dev` | Static asset CDN (release installer mirrors, Whisper model cache) | When the GitHub Releases bandwidth becomes a bottleneck or release downloads need geographic edge caching. |
| `status.omnibridge.marshalx.dev` | Public status page if any backend dependency starts having outages | Once the user count makes a status page worth maintaining. |

---

## Cloudflare Functions (existing)

The desktop app calls these Cloud Functions URLs directly from `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`. They do **not** sit on a custom domain — the Google-hosted `*.run.app` URLs are written to `system/monetization → function_urls` in Firestore and read at runtime.

| Function | URL | Purpose |
|---|---|---|
| `createSubscription` | `https://createsubscription-f3n57yyena-uc.a.run.app` | Creates a Razorpay subscription for the signed-in user, returns the unique `short_url` to open in the browser |
| `cancelSubscription` | `https://cancelsubscription-f3n57yyena-uc.a.run.app` | Cancels at the end of the current billing cycle (Razorpay `cancel_at_cycle_end: 1`) |
| `resumeSubscription` | `https://resumesubscription-f3n57yyena-uc.a.run.app` | Reactivates a pending-cancel subscription |
| `razorpayWebhook` | `https://razorpaywebhook-f3n57yyena-uc.a.run.app` | Razorpay webhook receiver (HMAC-SHA256 verified) |

These do not need DNS records. If they ever move to a custom domain, register the new hostname in this file and re-seed `system/monetization → function_urls`.

---

## Naming conventions for any new subdomain

1. **One-word lowercase**, hyphenated only when necessary — `api` ✓, `web-app` ✗ (prefer `webapp`).
2. **Function-named, not implementation-named** — `api.` ✓, `cloudfn.` ✗ (the implementation may change; the function won't).
3. **No version numbers in hostnames** — version lives in URL paths (`/v1/...`).
4. **Document proxy state, TLS issuer, and provisioning method** in the table above before going live.
5. **Cross-link** in [docs/00_doc_index.md](../00_doc_index.md) if the surface is user-facing.

---

## Cross-references

- Web landing source: [web_landing/](../../web_landing/)
- CI workflow: [.github/workflows/web_landing_ci.yml](../../.github/workflows/web_landing_ci.yml)
- Firebase config: [firebase.json](../../firebase.json) · [.firebaserc](../../.firebaserc)
- Pre-launch TODO: [23_pre_launch_todo.md](23_pre_launch_todo.md)
- Monetization (function URLs): [docs/04_features/16_monetization_plan.md](../04_features/16_monetization_plan.md)
