<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.

 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 29 — Billing Screen Redesign

> Implementation plan to rebuild the existing [`BillingScreen`](../../lib/features/subscription/presentation/screens/billing_screen.dart) so its visual language matches the redesigned Subscription screen ([28](28_subscription_screen_redesign.md)) and the `Billing.html` prototype, while staying inside the **Razorpay-URL checkout** model already wired into the project.

**Source of truth for visuals:** `demo/prototypes/screens/Billing.html` (gitignored — local only).
**Owning feature slice:** `lib/features/subscription/`.
**Data model:** [`BillingInfo`](../../lib/features/subscription/domain/entities/billing_info.dart), [`PaymentEvent`](../../lib/features/subscription/domain/entities/payment_event.dart), populated by Firestore + the [`razorpayWebhook`](../../functions/src/razorpayWebhook.ts) Cloud Function.
**Related docs:** [25 — Billing Management](25_billing_management.md), [16 — Monetization Plan](16_monetization_plan.md), [28 — Subscription Screen Redesign](28_subscription_screen_redesign.md), [DESIGN.md](../../DESIGN.md), [CLAUDE.md](../../CLAUDE.md).

---

## 1. Razorpay-URL constraint (read first)

This project doesn't use Razorpay's native SDK. Checkout, card management, and method updates all happen on **`razorpay.com` hosted pages** that we open via `url_launcher`. The implications shape every section of this plan:

- **We never see a saved payment method.** Razorpay holds the customer's UPI handles, cards, net-banking entries. The hosted checkout shows them, the user picks one, the webhook tells us *which method type* a payment used (UPI / card / netbanking) but not the masked details.
- **There is no in-app "Payment Methods" CRUD.** The prototype's add/remove/make-default UI is unimplementable as-shown. The redesign replaces it with a one-line summary of the most-recent method + a "Manage in Razorpay" outline button that opens the Razorpay customer portal URL.
- **All actions that change billing state go through Cloud Functions** (`createSubscription`, `cancelSubscription`, `resumeSubscription`) which call Razorpay's REST API server-side. The Flutter app never holds Razorpay secrets.
- **No card details ever reach the app or our backend.** Per [CLAUDE.md hard prohibition #13](../../CLAUDE.md#hard-prohibitions). The footnote on the page has to make that explicit so users understand why there's no card-input form.

## 2. Goals

Apply the same composition principles that landed in [28](28_subscription_screen_redesign.md):

- **Vertical scroll, max-content ~1180.** Drop the current `maxWidth: 580` centre column.
- **Status banner at the top** for `halted` / `cancelled-pending` states (already exists; restyle, don't reinvent).
- **Two-column hero**: subscription summary card (left, ~420 px) + this-period usage card (right, flex). Mirrors the prototype.
- **Section-based scroll**: status → hero row → invoices → footnote. Drop the "Payment Methods" section per §1.
- **Tier accents from theme**, not hex literals. Enterprise = `AppColors.splashPurple` (already aligned in [28](28_subscription_screen_redesign.md#15-implementation-status-shipped)).
- **Compare Plans button** in header → `AppRouter.subscription` (mirrors the Subscription screen's "Manage Billing" button — symmetric navigation).
- **Reuse the new widgets where they fit** — `OmniProgressBar`, `OmniCard`, `OmniBadge`. Don't recreate.

## 3. Non-goals

- **No new payment-method CRUD.** Per §1.
- **No invoice PDF generation in-app.** PDFs come from Razorpay (download URL on `PaymentEvent` — already on the entity). The download button just `url_launcher`s that link.
- **No latency / sessions / languages stat cells.** The prototype's right-side card shows them; in the app those metrics live in the Usage feature, not Billing. Cross-feature data fetching is a clean-arch violation. The redesigned Usage card will show only what `BillingInfo` + `QuotaStatus` give us natively (monthly + daily tokens). The deep-dive Stats live one click away in [Usage Analytics](14_usage_analytics_guide.md).
- **No reorder of `BillingInfo` fields, no schema migration.** All redesign work stays in `presentation/`. New optional fields (e.g. `lastPaymentMethod`) are additive only.

## 4. Gap analysis — prototype vs current

| Aspect | Prototype (`Billing.html`) | Current ([`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart)) |
|---|---|---|
| Page width | Full-bleed inside `AppFrame`, max-content ~1180 | Centred `ConstrainedBox(maxWidth: 580)` |
| Layout | Status banner → 420 / flex hero row → Payment Methods → Invoices → Footnote | Hero card → optional alert → Subscription Details → Actions → Invoices |
| Header CTA | "Compare Plans" outline button → /subscription | None |
| Hero | Subscription summary card with KV grid + 2 buttons (left), Usage card with 3 progress bars + 4 stat cells (right) | Single full-width hero with countdown + cycle progress + 3 stat cells |
| Status banner | Top of page, full-width — failed (red) / cancelled (amber) | Inline below hero — both states share `_AlertBanner` |
| Subscription card | Tier name + price + period, "Renews/Trial active/Cancelled" line, KV grid (Started, Cycle, Customer ID, Sub ID), Change Plan + Cancel buttons | Subscription Details list with copy-to-clipboard rows; actions are in a separate "Actions" section below |
| Usage card | Monthly + daily + RPM progress bars + 4 stat cells (Translations / Sessions / Languages / Avg latency) | Not present (Usage lives on a separate screen) |
| Payment Methods | UPI / Card / Net Banking list with primary badge + add/remove/make-default | Not present |
| Invoices | Grid: ID / Date / Amount / Method / Status / Download | List with date + amount + status — no method column, no download button |
| Footnote | Razorpay disclaimer + billing email | Not present |

## 5. Domain / data layer changes

Three small, additive changes. None require Firestore migration.

### 5.1 Capture payment method on `PaymentEvent`

The Razorpay webhook receives `payment.method` on `subscription.charged` events. Currently it's discarded.

```dart
// lib/features/subscription/domain/entities/payment_event.dart
class PaymentEvent {
  // ...existing fields...
  final String? method;        // 'upi' | 'card' | 'netbanking' | 'wallet' | null
  final String? methodSummary; // 'UPI · maya@okhdfcbank' | 'Card · HDFC •• 4421' | null
  final String? invoiceUrl;    // Razorpay-hosted PDF URL — already on Razorpay's invoice object
}
```

Webhook update ([`functions/src/razorpayWebhook.ts`](../../functions/src/razorpayWebhook.ts)) — read `payload.payment.entity.method` + a derived summary, write to the `subscription_events` doc. This is a **server-side change** and ships in the same PR per [CLAUDE.md Flutter ↔ Python lockstep](../../CLAUDE.md#flutter--python-lockstep) (the rule applies to ↔ Cloud Functions too).

### 5.2 Expose Razorpay customer portal URL

Razorpay's customer portal lets the user manage saved methods without us touching them. The URL is `https://dashboard.razorpay.com/app/customer/<customer_id>` for the customer.

```dart
// lib/features/subscription/domain/entities/billing_info.dart
final String? customerId;        // 'cust_NXqM92'
final String? customerPortalUrl; // computed from customerId or stored
```

Customer ID is already on the Razorpay subscription object — capture it in the webhook on first activation, write to `users/{uid}.razorpayCustomerId`.

### 5.3 New use-case: `GetBillingPeriodSummary`

Pure presentation derivation from `BillingInfo` + `QuotaStatus`. No new datasource calls.

```dart
class BillingPeriodSummary {
  final DateTime periodStart;        // nextBillingAt - 30d
  final DateTime periodEnd;          // nextBillingAt
  final int monthlyTokensUsed;       // QuotaStatus.monthlyTokensUsed
  final int monthlyTokensLimit;      // SubscriptionPlan.monthlyTokens
  final int dailyTokensUsed;
  final int dailyTokensLimit;
}
```

Implemented as a domain use-case so the BLoC stays thin. Reads `ISubscriptionRepository` only — no cross-feature imports.

## 6. BLoC changes

`BillingScreen` currently uses raw `ValueListenableBuilder<BillingInfo>` on the repository's notifier. The redesign keeps that pattern (it works) and adds a small `BillingBloc` only if section state grows complex enough to need it (e.g. invoice pagination, expanded rows). **Recommend deferring** the BLoC introduction — the screen is read-mostly with two side-effect actions (cancel, resume) already wired through use-cases.

If a BLoC turns out to be needed in step 5 (invoices), introduce it then with: `BillingState { isLoading, invoices, hasMore, error }` + `BillingInvoicesLoadMoreEvent`.

## 7. New presentation widgets

All in [`lib/features/subscription/presentation/widgets/`](../../lib/features/subscription/presentation/widgets/).

| Widget | Responsibility | Maps to prototype |
|---|---|---|
| `BillingSubscriptionCard` | Tier + price + period header, next-bill line, KV grid (started, cycle, customer ID, sub ID), 2 action buttons (Change Plan / Cancel or Resume) | `Card accent` block |
| `BillingUsageCard` | "This billing period" header with date range, 3 progress bars (monthly/daily tokens, RPM cap), no stat cells in v1 | `Card padding` block on the right |
| `BillingInvoiceTable` | Grid header + rows; each row: id, date, amount, method, status chip, download icon-button | `Card padding={0}` invoice block |
| `BillingPaymentMethodNotice` | Single-line "Most recent: UPI · maya@okhdfcbank" + outline "Manage in Razorpay" button | Replaces the prototype's full Payment Methods CRUD |
| `BillingFootnote` | Razorpay disclaimer + `billing@omnibridge.marshalx.dev` link | Footnote block |

### Reuse — don't recreate

- [`OmniProgressBar`](../../lib/core/widgets/omni_progress_bar.dart) for the three usage bars in the Usage card. Pass `color: tierAccent` so each bar matches the tier.
- [`OmniBadge`](../../lib/core/widgets/omni_badge.dart) for the invoice status chip ("Paid" / "Refunded") — replaces the inline `Chip` from the prototype.
- [`OmniTintedButton`](../../lib/core/widgets/omni_tinted_button.dart) for the header "Compare Plans" button — matches the Subscription screen's "Manage Billing" pattern.
- The existing [`_AlertBanner`](../../lib/features/subscription/presentation/screens/billing_screen.dart) — keep, restyle inline. No new widget.
- The existing [`_HeroCard`](../../lib/features/subscription/presentation/screens/billing_screen.dart) gradient + accent bar work — fold the relevant pieces into `BillingSubscriptionCard` so the gradient stays.

## 8. Screen-level refactor

```text
AppDashboardShell(currentRoute: AppRouter.billing)
  └ SingleChildScrollView (vertical, full width with max-content ~1180)
      ├ HeroBlock                  ("Billing" title + subtitle + Compare Plans button)
      ├ StatusBanner               (existing _AlertBanner; halted / cancel-pending)
      ├ Row(crossAxisStretch)
      │   ├ Flexible(flex: 7) BillingSubscriptionCard
      │   └ Flexible(flex: 9) BillingUsageCard
      ├ BillingPaymentMethodNotice
      ├ SectionLabel "INVOICES" + Export-all link (when ≥ 1 invoice)
      ├ BillingInvoiceTable
      └ BillingFootnote
```

### Drop / replace

- The hardcoded `ConstrainedBox(maxWidth: 580)` — switch to `1180` to match the Subscription screen.
- The standalone "Subscription Details" card with copy-to-clipboard rows — its data folds into `BillingSubscriptionCard`'s KV grid (Customer ID and Sub ID get the existing tap-to-copy behaviour).
- The standalone "Actions" section — its buttons fold into `BillingSubscriptionCard`'s footer.

## 9. Concrete file change list

### Modify (3)

1. [`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart) — full rewrite of `_BillingBody`, drop `_HeroCard` / `_DetailsCard` / `_ActionsSection` (their pieces move into `BillingSubscriptionCard`), keep `_AlertBanner` + `_UpsellCard` (free/trial fallback).
2. [`payment_event.dart`](../../lib/features/subscription/domain/entities/payment_event.dart) — add `method`, `methodSummary`, `invoiceUrl` fields (all nullable, additive).
3. [`billing_info.dart`](../../lib/features/subscription/domain/entities/billing_info.dart) — add `customerId`, `customerPortalUrl`.

### Create (5)

1. `lib/features/subscription/presentation/widgets/billing_subscription_card.dart`
2. `lib/features/subscription/presentation/widgets/billing_usage_card.dart`
3. `lib/features/subscription/presentation/widgets/billing_invoice_table.dart`
4. `lib/features/subscription/presentation/widgets/billing_payment_method_notice.dart`
5. `lib/features/subscription/presentation/widgets/billing_footnote.dart`

### Server-side (2)

1. [`functions/src/razorpayWebhook.ts`](../../functions/src/razorpayWebhook.ts) — capture `payment.method`, derive `methodSummary`, capture `customer_id` on first activation. Write to Firestore.
2. [`subscription_remote_datasource.dart`](../../lib/features/subscription/data/datasources/subscription_remote_datasource.dart) — read the new fields; populate `BillingInfo.customerId` + `PaymentEvent.method/methodSummary/invoiceUrl`.

### Domain (1)

1. New use-case: `lib/features/subscription/domain/usecases/get_billing_period_summary.dart`. DI registration in [`core/di/parts/usecase_di.dart`](../../lib/core/di/parts/usecase_di.dart).

### Tests (1)

- `test/features/subscription/domain/get_billing_period_summary_test.dart` — pure unit test of the period-derivation logic. (Widget tests skipped per [28 §15 acceptance gaps](28_subscription_screen_redesign.md#15-implementation-status-shipped) — repo is bloc-only.)

## 10. Implementation order

| # | Step | What ships |
|---|---|---|
| 1 | Webhook captures `payment.method` + `customerId` (server) + datasource reads them (Flutter). | Data flows but no UI change. Verify on a test charge. |
| 2 | Add `customerId` / `method` / `methodSummary` / `invoiceUrl` fields. Migrate `BillingInfo.empty`. | Equatable `props` updated; existing screen unaffected. |
| 3 | `GetBillingPeriodSummary` use-case + unit test. | Period-window math tested in isolation. |
| 4 | Layout shell rewrite — drop the 580 max, switch to 1180; hero block (title + subtitle + Compare Plans button). | Page width changes; everything else still inside the old card layout. |
| 5 | `BillingSubscriptionCard` — fold hero gradient + KV grid + actions. Replaces `_HeroCard` + `_DetailsCard` + `_ActionsSection`. | Left half of the prototype's hero row landed. |
| 6 | `BillingUsageCard` — three progress bars driven by `GetBillingPeriodSummary`. Place in Row(flex: 7 / flex: 9) with the subscription card. | Prototype's hero row complete. |
| 7 | `BillingPaymentMethodNotice` — single-line summary + Razorpay portal link via `url_launcher`. | Replaces the prototype's Payment Methods section. |
| 8 | `BillingInvoiceTable` — restyle existing invoice list to match the prototype grid; add download button → `url_launcher(invoice.invoiceUrl)`. Use `OmniBadge` for status. | Invoices visually match prototype. |
| 9 | `BillingFootnote` — Razorpay disclaimer + `billing@omnibridge.marshalx.dev`. | Page complete. |

Steps 1–3 are data-layer prep — UI looks identical to today after each. Step 4 onwards is the visible refactor.

## 11. Design-system compliance

Per [DESIGN.md](../../DESIGN.md) and [CLAUDE.md §14](../../CLAUDE.md#hard-prohibitions):

- **No hex literals.** Use `AppColors.*` for everything. The prototype's amber-on-cancel banner maps to `AppColors.amber`; red-on-failed maps to `AppColors.accentRed`. Tier accents come from the same map used in [28](28_subscription_screen_redesign.md) (`free → textSecondary`, `trial → amberAccent`, `pro → accentTeal`, `enterprise → splashPurple`).
- **Motion / shapes.** Reuse `AppShapes.sm/md/lg`. Hover lift on the subscription card (200ms ease, –3 px translateY) — same recipe as the redesigned plan cards.
- **Typography.** Go through `Theme.of(context).textTheme`. The prototype uses 30 / 16 / 14 / 13 / 12 / 11.5 / 10 — map to `headlineSmall / titleMedium / bodyLarge / bodyMedium / labelSmall`.
- **Iconography.** Material rounded variants, no inline SVGs. Map: `bolt_rounded` (Pro), `workspace_premium_rounded` (Enterprise), `hourglass_top_rounded` (Trial), `account_balance_wallet_outlined` (payment), `download_rounded` (invoice download), `compare_arrows_rounded` (Compare Plans header button).

## 12. Acceptance criteria

1. `flutter analyze` reports **zero** issues across `lib/features/subscription/` and `test/features/subscription/`.
2. The Billing screen renders correctly on the minimum window (`AppDashboardShell` width); no horizontal scroll appears.
3. **All five `BillingInfo` states render correctly:**
   - `none` (free/trial without sub history) → upsell view (existing `_UpsellCard`)
   - `active` → subscription card with "Renews automatically" + green countdown + Cancel button
   - `halted` → red status banner at top, Re-subscribe action visible
   - `cancelled` (paid tier still active, `isCancelPending`) → amber banner, Resume button visible
   - `cancelled` (tier downgraded) / `completed` → upsell view
4. Tier accent applied consistently: status banner border, subscription card top accent, progress bars, buttons. Enterprise renders purple, Pro teal, Trial amber.
5. Cancel and Resume actions still reach the existing use-cases and trigger the existing optimistic-update + webhook flow.
6. Invoice rows show ID, date, amount, method (`UPI · maya@okhdfcbank`), status (Paid/Refunded). Download icon opens the Razorpay invoice URL via `url_launcher`. If `invoiceUrl` is missing, the icon is disabled with a tooltip.
7. "Manage in Razorpay" outline button opens `customerPortalUrl` if present; otherwise hidden.
8. Compare Plans header button uses `pushReplacementNamed(AppRouter.subscription)` (symmetric with [28](28_subscription_screen_redesign.md#15-implementation-status-shipped)'s Manage Billing button).
9. The new `GetBillingPeriodSummary` unit test passes.
10. No `print` / `debugPrint`, no swallowed exceptions, no cross-feature `data/` imports, no `.instance` outside the data layer — same audit gates as [28](28_subscription_screen_redesign.md#architecture-audit-clean).

## 13. Risks / open questions

| Risk | Mitigation |
|---|---|
| Razorpay webhook payload structure for `payment.method` may differ between UPI / card / netbanking | Test with one of each in the Razorpay sandbox before relying on `methodSummary` formatting. Worst case: omit summary, show only `method` enum as a Chip. |
| Customer portal URL may require auth (Razorpay session) — won't open useful page if user isn't signed in there | Verify before shipping the "Manage in Razorpay" button. If unauthenticated, fall back to a plain "Payment is managed by Razorpay" message + link to https://razorpay.com/support/ |
| `monthlyTokens` from `SubscriptionPlan` may be `< 0` (unlimited tier) — divide-by-zero in usage progress | `BillingPeriodSummary` should expose `isUnlimited` flag; usage card renders "∞" instead of a progress bar when unlimited. |
| Old PaymentEvent docs in Firestore won't have `method` / `invoiceUrl` (pre-migration data) | Optional fields handle this naturally; UI gracefully degrades (omit method column cell, disable download). No backfill needed. |
| Period start derivation (`nextBillingAt - 30 days`) is approximate — actual cycle may be longer for plans on different cadences | Razorpay subscriptions in this app are monthly only (per [16 — Monetization Plan](16_monetization_plan.md)). If yearly plans land (per [28 §13](28_subscription_screen_redesign.md)), revisit. |
| Webhook captures `customerId` only on **first** activation — existing pre-redesign users won't have it | Add a one-shot Cloud Function task to backfill `razorpayCustomerId` from Razorpay's API for all paid users. Track as follow-up. |

## 14. Out of scope (follow-ups)

- **Customer portal SSO.** True one-click access to Razorpay's customer portal would need a Razorpay OAuth flow we don't have. Tracked for after the redesign ships.
- **Invoice PDF generation in-app.** Razorpay-hosted PDFs are good enough; building our own is unnecessary scope.
- **Refund-request UI.** Currently refunds are email-only via the trust panel ([trust_panel.dart](../../lib/features/subscription/presentation/widgets/trust_panel.dart)). A self-serve refund button is a separate product decision.
- **Multi-currency.** All prices are INR per the existing app constraint; if USD/EUR plans are added, the formatter on `BillingPeriodSummary` and `lastPaymentFormatted` needs updating.

## 15. Documentation update on completion

Per [CLAUDE.md doc map](../../CLAUDE.md#documentation-update-map), when this redesign ships:

- Update [25 — Billing Management](25_billing_management.md) with the new layout structure, the dropped Payment Methods section explanation, and the new entity fields.
- Update [16 — Monetization Plan](16_monetization_plan.md) if the webhook captures any new data points worth documenting.
- Add an **Implementation status (shipped)** section to this doc once landed, mirroring [28 §15](28_subscription_screen_redesign.md#15-implementation-status-shipped) — file map per step + departures.
- Update the [docs/00_doc_index.md](../../docs/00_doc_index.md) — already includes `28`; add `29` next.

## 16. Implementation status (shipped)

Landed on `main` (single commit). Numbered against §10:

| Step | Status | Files touched |
|---|---|---|
| 1 — Webhook + datasource read new fields | ✅ | [`functions/src/razorpayWebhook.ts`](../../functions/src/razorpayWebhook.ts) (added `buildMethodSummary` helper; `payment.captured`, `subscription.activated`, `subscription.charged` now write `lastPaymentMethod`/`lastPaymentMethodSummary` and capture `razorpayCustomerId` on first activation), [`subscription_remote_datasource.dart`](../../lib/features/subscription/data/datasources/subscription_remote_datasource.dart) (reads new fields in both `_loadInvoices` and `_listenToUserDoc`; optimistic-update sites in cancel/resume preserve them) |
| 2 — Entity fields | ✅ | [`payment_event.dart`](../../lib/features/subscription/domain/entities/payment_event.dart) (+`method`, `methodSummary`, `invoiceUrl`), [`billing_info.dart`](../../lib/features/subscription/domain/entities/billing_info.dart) (+`customerId`, `lastPaymentMethod`, `lastPaymentMethodSummary`, derived getter `customerPortalUrl`) |
| 3 — `GetBillingPeriodSummary` use-case + tests | ✅ | New entity [`billing_period_summary.dart`](../../lib/features/subscription/domain/entities/billing_period_summary.dart), use-case [`get_billing_period_summary.dart`](../../lib/features/subscription/domain/usecases/get_billing_period_summary.dart) (also exposes a pure `deriveBillingPeriodSummary` function for tests), DI in [`usecase_di.dart`](../../lib/core/di/parts/usecase_di.dart), 7 tests in [`get_billing_period_summary_test.dart`](../../test/features/subscription/domain/get_billing_period_summary_test.dart) — all green |
| 4 — Layout shell rewrite | ✅ | [`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart) — `maxWidth` 580 → 1180, vertical `SingleChildScrollView`, new `_HeroBlock`, status banner moved above hero row, footnote added, upsell pulled into its own `_UpsellLayout` so the same hero block renders for every state |
| 5 — `BillingSubscriptionCard` | ✅ | [`billing_subscription_card.dart`](../../lib/features/subscription/presentation/widgets/billing_subscription_card.dart) — folds gradient header + KV grid (Started, Last paid, Subscription ID, Customer ID) + status pill + actions (Cancel / Resume / Re-subscribe / Upgrade / Compare Plans) into one component. Hover lift `–3 px` matches the redesigned plan cards. |
| 6 — `BillingUsageCard` | ✅ | [`billing_usage_card.dart`](../../lib/features/subscription/presentation/widgets/billing_usage_card.dart) — period range header, monthly + daily progress bars (uses `OmniProgressBar`), optional rate-limit row. Renders ∞ for unlimited tiers. |
| 7 — `BillingPaymentMethodNotice` | ✅ | [`billing_payment_method_notice.dart`](../../lib/features/subscription/presentation/widgets/billing_payment_method_notice.dart) — single-line summary + "Manage in Razorpay" button (hidden when `customerPortalUrl` is null). Falls back to bare method name if the webhook didn't send `methodSummary`. |
| 8 — `BillingInvoiceTable` | ✅ | [`billing_invoice_table.dart`](../../lib/features/subscription/presentation/widgets/billing_invoice_table.dart) — 6-column grid (label/id, date, amount, method, status, action). Uses `OmniBadge` for status, `Icons.download_rounded` for invoice link, disabled when `invoiceUrl` is missing. |
| 9 — `BillingFootnote` | ✅ | [`billing_footnote.dart`](../../lib/features/subscription/presentation/widgets/billing_footnote.dart) — Razorpay PCI-DSS disclaimer + refund SLA line + `billing@omnibridge.marshalx.dev` mailto link. |

### Departures from plan

- **`OmniTintedButton` for the Compare Plans header button** (§7 reuse list) was not used — the Subscription screen's symmetric "Manage Billing" button is a plain `OutlinedButton.icon`, so the Billing header now mirrors it instead. Keeps the two screens visually identical.
- **Concurrent sessions cell** isn't on the Usage card. Plan didn't promise it; flagging here so the omission is explicit. The Usage feature surfaces it under engine usage.
- **`PaymentEvent.invoiceUrl`** is wired through but the webhook does **not** populate it yet (Razorpay's `subscription.charged` payload exposes the invoice via `payload.invoice.entity.short_url`, which currently isn't read). The download icon-button is disabled-with-tooltip when missing — no UI bug, just a follow-up to capture the field server-side. Track as item 1 of the follow-ups below.

### Architecture audit (clean)

- ✅ No `print` / `debugPrint` — all logging through `AppLogger`.
- ✅ No swallowed exceptions — `catch (e)` blocks all log via `AppLogger.w` before continuing.
- ✅ No cross-feature `data/` imports.
- ✅ No `.instance` outside the data layer.
- ✅ No hex literals — colors come from `AppColors.*`.
- ✅ All shapes from `AppShapes.sm/md/lg`.
- ✅ Use-case takes `ISubscriptionRepository` only; the BLoC layer wasn't introduced because the screen stays read-mostly with two side-effect actions (cancel / resume) that already route through use-cases.
- ✅ `flutter analyze` — zero issues across `lib/` and `test/`.

### Follow-ups

1. **Capture `invoiceUrl` server-side.** Wire `payload.invoice.entity.short_url` from `subscription.charged` into `PaymentEvent.invoiceUrl` in the webhook so the download button activates for new renewals. Existing rows stay disabled.
2. **Backfill `razorpayCustomerId`.** Per §13: existing paid users from before this change won't have a customer ID and so won't see the "Manage in Razorpay" button. Schedule a one-shot admin script that fetches `customer_id` from each subscription's Razorpay record and writes it back to Firestore.
3. **`activeAnnouncement` banner.** The status banner only handles `halted` / cancel-pending today. If product wants per-tier announcements landing on the Billing screen, lift the existing `activeAnnouncement` config from the subscription path.
