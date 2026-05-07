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

**Two Firebase Hosting sites in the same project** (one Firebase project, two sites within it — not two projects). Each environment gets its own site so its custom domain binds at the site level (= the live channel) without requiring channel-domain UI features that aren't exposed in every Firebase Console rollout.

| Hostname | Site | Target alias (in `firebase.json`) | Default URL | DNS | CF proxy | TLS issuer |
|---|---|---|---|---|---|---|
| `omnibridge.marshalx.dev` | `omni-bridge-ai-translator` (default site) | `omnibridge` | `omni-bridge-ai-translator.web.app` | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase |
| `uat.omnibridge.marshalx.dev` | `omni-bridge-ai-translator-uat` | `omnibridge-uat` | `omni-bridge-ai-translator-uat.web.app` | Cloudflare DNS | **OFF** | Let's Encrypt via Firebase |
| (PR previews) | `omni-bridge-ai-translator` | `omnibridge` | auto `omni-bridge-ai-translator--pr-NNN-<hash>.web.app` | Firebase | n/a | Firebase |

> **Why proxy must be OFF:** Firebase Hosting provisions its TLS cert via Let's Encrypt by performing the TLS handshake directly with the domain. Cloudflare's orange-cloud proxy intercepts that handshake and breaks cert provisioning. Set the A records to **DNS only** (grey cloud) for both apex and uat subdomain.

> **Why two sites, not channels:** The cleanest pattern would be one site with `live` and `uat` channels, each bound to its own custom domain (Fluxora does this). It requires Firebase Console's "channel custom domains" UI, which isn't exposed in every project rollout. omni-bridge falls back to the more universally-supported pattern: two sites, each with a site-level domain.

---

## Custom domain setup (Firebase Console)

Each domain binds to its own dedicated site at the site level — no channel selection needed. Both sites have only a `live` channel that the workflow deploys to.

### Production domain (`omnibridge.marshalx.dev` → site `omni-bridge-ai-translator`)

1. Firebase Console → Hosting → site **`omni-bridge-ai-translator`** → **Add custom domain**
2. Enter `omnibridge.marshalx.dev`
3. Choose **Serve traffic from this domain** (don't check "Redirect")
4. Firebase shows 2 A-record IPs + 1 TXT verification token
5. Add to Cloudflare DNS, **proxy OFF** (DNS only)
6. Click **Verify** in Firebase — provisioning takes a few minutes

### UAT domain (`uat.omnibridge.marshalx.dev` → site `omni-bridge-ai-translator-uat`)

> **Prerequisite:** the UAT site must exist. Created via `firebase hosting:sites:create omni-bridge-ai-translator-uat`. After that, push to the `uat` branch deploys to the UAT site's `live` channel.

1. Firebase Console → Hosting → site **`omni-bridge-ai-translator-uat`** (the UAT site, NOT the default one) → **Add custom domain**
2. Enter `uat.omnibridge.marshalx.dev`
3. Choose **Serve traffic from this domain**
4. Same DNS dance — A records + TXT token from Firebase, paste into Cloudflare, proxy OFF, Verify

### Common mistake

Adding `uat.omnibridge.marshalx.dev` to the **default site** (`omni-bridge-ai-translator`) instead of the UAT site routes it to production content. If `uat.omnibridge.marshalx.dev` shows the wrong build, remove the binding from the default site's Custom domains tab and re-add it on the `omni-bridge-ai-translator-uat` site instead.

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
| `FIREBASE_SERVICE_ACCOUNT_OMNI_BRIDGE_AI_TRANSLATOR` | Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the entire JSON. |

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
