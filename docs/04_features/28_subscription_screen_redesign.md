<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.

 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 28 — Subscription Screen Redesign

> Implementation plan for replacing the current narrow plan-card layout in [`SubscriptionScreen`](../../lib/features/subscription/presentation/screens/subscription_screen.dart) with the full pricing-page composition from the `Monetization.html` prototype.

**Source of truth for visuals:** `demo/prototypes/screens/Monetization.html` (gitignored — local only).
**Owning feature slice:** `lib/features/subscription/`.
**Related docs:** [16 — Monetization Plan](16_monetization_plan.md), [25 — Billing Management](25_billing_management.md), [DESIGN.md](../../DESIGN.md), [CLAUDE.md — Global widget library](../../CLAUDE.md#global-widget-library--check-before-building).

---

## 1. Goals

Replace the current "4 plan cards centered in a 900 px box" layout with the prototype's full pricing-page composition:

- Hero block (title + subtitle + billing-cycle toggle + "Manage Billing" link)
- Plan grid (4 cards with hover lift, "MOST POPULAR" / "YOUR PLAN" ribbons, dual monthly/yearly price)
- Plan comparison table (14 features × 4 tiers)
- FAQ section (accordion)
- Trust panel + 7-day money-back card
- Bottom trial CTA banner

Ship it as a vertical scroll page that fills the available width instead of a fixed 900 px island.

## 2. Non-goals

- **No changes to Razorpay checkout, webhook flow, or trial activation.** All payment / billing logic stays exactly as-is. The redesign is presentation-only with one optional state-layer tweak (§5).
- **Don't redesign the Billing screen.** This page only links to it via a top-right "Manage Billing" button — see [billing_screen.dart](../../lib/features/subscription/presentation/screens/billing_screen.dart) and [25 — Billing Management](25_billing_management.md).
- **Don't touch the `_DebugTierPanel`.** The `kDebugMode`-gated tier switcher in [subscription_screen.dart:27](../../lib/features/subscription/presentation/screens/subscription_screen.dart#L27) ships unchanged at the bottom of the new page.
- **Don't migrate to a new state library, animation framework, or design tokens.** This is a layout + composition change inside the existing BLoC + widget conventions.

## 3. Gap analysis — prototype vs current

| Aspect | Prototype (`Monetization.html`) | Current ([`subscription_screen.dart`](../../lib/features/subscription/presentation/screens/subscription_screen.dart)) |
|---|---|---|
| Page layout | Vertical scroll: hero → plan grid → compare → FAQ + trust → money-back → bottom CTA | Single centered card with 4 plan cards inside a fixed `SizedBox(width: 900)` |
| Width strategy | Full-bleed inside `AppFrame`, internal max-content ~1100 | Hardcoded 900 px with horizontal scroll fallback |
| Header | "Plans & Pricing" title + subtitle + billing toggle + "Manage Billing" outline button | `buildSubscriptionHeader(context)` (existing `OmniHeader`) |
| Billing toggle | Monthly / Yearly with `-27%` chip; yearly = 2 months free on Pro/Enterprise | Not present |
| Plan card | Hover lift, "MOST POPULAR" ribbon, "YOUR PLAN" ribbon for current tier, accent-coloured everything, quota strip with 4 rows, ~6 features, accent-bg CTA | Static card via `OmniCard`, badge instead of ribbon, fewer quota rows, expandable engine details, themed by `Colors.amber/teal/white` |
| Pricing display | Monthly: `₹799 / per month`. Yearly: `₹6,990 / per year` + accent "Save 27% billed yearly" | Single `plan.price` string |
| Compare table | 14 rows × 4 plan columns, alternating zebra rows, ✓/—/value cells | None |
| FAQ | 6 questions, accordion, one open at a time | None |
| Trust panel | 4 trust items + 7-day money-back card in side column | None |
| Bottom CTA | Gradient banner: "Try Pro free for 24h" + Trial button | Trial CTA only inside the trial plan card |
| Trial countdown | Not in prototype | Existing line that shows when `tier == 'trial'` — keep it, place under the plan grid |

## 4. Domain / data layer changes

Yearly pricing is the only new domain concept. Two options — pick one explicitly before starting work.

### Option A — Add yearly to `SubscriptionPlan` (preferred long-term)

```dart
// lib/features/subscription/domain/entities/subscription_plan.dart
final String? yearlyPrice;          // '₹6,990' or null
final String? yearlyRazorpayPlanId; // for openCheckout(plan, cycle)
```

Then `OpenCheckout(tierId, cycle)` and [`SubscriptionRemoteDataSource`](../../lib/features/subscription/data/datasources/subscription_remote_datasource.dart) map `(tierId, cycle) → razorpay_plan_id`. Requires Firestore `monetization_config` to seed `pro_yearly` and `enterprise_yearly` plan documents.

### Option B — Display-only, monthly checkout under the hood (preferred for first pass)

- `SubscriptionPlan` stays as-is.
- A card-level helper computes `yearlyPrice = monthly × 12 × 0.73` for display.
- The yearly toggle is purely visual; selecting a yearly plan still calls `openCheckout(plan.id)` with the monthly Razorpay plan ID.
- Cleanest first ship — defers the Razorpay seeding question.

**Recommendation:** Ship **Option B** so the redesign lands independently of monetization-config seeding. File a follow-up ([16 — Monetization Plan](16_monetization_plan.md)) to wire Option A once `pro_yearly` / `enterprise_yearly` plan documents exist.

> **Architecture note:** Both options stay strictly inside the existing layer boundaries — no presentation→data leak, no new repository methods unless Option A is chosen. See [CLAUDE.md §Strict architecture](../../CLAUDE.md#strict-architecture--zero-tolerance).

## 5. BLoC changes

One new field, one new event. Under Option B, no new use-case is needed.

```dart
// lib/features/subscription/presentation/bloc/subscription_state.dart
enum BillingCycle { monthly, yearly }

class SubscriptionState extends Equatable {
  // ...existing fields...
  final BillingCycle billingCycle;          // default: monthly

  // include in copyWith and props
}

// lib/features/subscription/presentation/bloc/subscription_event.dart
class SubscriptionBillingCycleChanged extends SubscriptionEvent {
  final BillingCycle cycle;
  const SubscriptionBillingCycleChanged(this.cycle);
}

// lib/features/subscription/presentation/bloc/subscription_bloc.dart
on<SubscriptionBillingCycleChanged>((e, emit) =>
    emit(state.copyWith(billingCycle: e.cycle)));
```

**Equally valid alternative:** keep `billingCycle` as local `setState` inside the screen — it doesn't outlive the route. The BLoC route is cleaner because the comparison table and bottom CTA also need to react to it. **Recommend BLoC.**

## 6. New widgets to extract

All go in [`lib/features/subscription/presentation/widgets/`](../../lib/features/subscription/presentation/widgets/). Each is one focused widget — no cross-feature imports.

| Widget | Responsibility | Maps to prototype |
|---|---|---|
| `BillingCycleToggle` | Pill toggle "Monthly / Yearly -27%" | `BillingToggle` in `Monetization.html` |
| `PlanCompareTable` | Pure presentation table; data via const list inside the widget | `CompareTable` |
| `PlanFaqSection` | Accordion list, one open at a time; controlled by `ValueNotifier<int>` or local `setState` | `FAQItem` |
| `TrustPanel` | 4 trust items + money-back card | `Trust` |
| `BottomTrialCta` | Gradient banner with trial button — wired to existing `ActivateTrial` use-case | bottom CTA banner |
| Restyle existing [`plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart) | Add hover lift, ribbons, dual price (monthly/yearly), accent CTA bg | `PlanCard` |

### Reuse — don't recreate

- [`OmniCard`](../../lib/core/widgets/omni_card.dart) → keep as the base for plan cards. Hover lift layers on via `MouseRegion` + `AnimatedContainer`.
- [`OmniChip`](../../lib/core/widgets/omni_chip.dart) / [`OmniBadge`](../../lib/core/widgets/omni_badge.dart) → use for "MOST POPULAR" / "YOUR PLAN" ribbons instead of inline `Container`s.
- [`OmniSegmentedControl`](../../lib/core/widgets/omni_segmented_control.dart) → check first if it can host the `BillingCycleToggle`. If its API supports a `trailingChild` for the `-27%` pill, use it directly. Otherwise build a thin wrapper rather than a full reimplementation.
- [`OmniTintedButton`](../../lib/core/widgets/omni_tinted_button.dart) → use for the "Manage Billing" outline button in the header.

## 7. Screen-level refactor

[`subscription_screen.dart`](../../lib/features/subscription/presentation/screens/subscription_screen.dart) becomes a vertical scroll of sections instead of a centred `SizedBox(width: 900)`:

```text
AppDashboardShell(currentRoute: AppRouter.subscription)
  └ SingleChildScrollView (vertical, full width with max-content ~1100)
      ├ HeroBlock          ("Plans & Pricing" title, subtitle, BillingCycleToggle, Manage Billing →)
      ├ Row (4 × Expanded)  Plan cards with hover lift + ribbons
      ├ TrialTimeRemaining  (existing, only when trial active)
      ├ SectionLabel       "COMPARE EVERY FEATURE"
      ├ PlanCompareTable
      ├ Grid 1.5fr / 1fr
      │   ├ PlanFaqSection
      │   └ Column { TrustPanel, MoneyBackCard }
      ├ BottomTrialCta
      ├ OmniVersionChip
      └ if (kDebugMode) _DebugTierPanel  (unchanged)
```

### Drop / replace

- The hardcoded `SizedBox(width: 900)` and the inner `SingleChildScrollView(scrollDirection: Axis.horizontal)` — switch to a responsive `LayoutBuilder` + `ConstrainedBox(maxWidth: 1180)` instead.
- The decorated `Container` wrapping the cards (`color: Colors.white * 0.03, ...`) — the outer scroll background is already set by `AppDashboardShell`.

## 8. Concrete file change list

### Modify (5)

1. [`lib/features/subscription/presentation/screens/subscription_screen.dart`](../../lib/features/subscription/presentation/screens/subscription_screen.dart) — full rewrite of the body (~200 → ~250 LOC).
2. [`lib/features/subscription/presentation/widgets/plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart) — add hover lift, ribbons, dual-price; preserve all existing payment-pending / trial logic and lifecycle hooks.
3. [`lib/features/subscription/presentation/bloc/subscription_state.dart`](../../lib/features/subscription/presentation/bloc/subscription_state.dart) — add `BillingCycle billingCycle`.
4. [`lib/features/subscription/presentation/bloc/subscription_event.dart`](../../lib/features/subscription/presentation/bloc/subscription_event.dart) — add `SubscriptionBillingCycleChanged`.
5. [`lib/features/subscription/presentation/bloc/subscription_bloc.dart`](../../lib/features/subscription/presentation/bloc/subscription_bloc.dart) — add the handler.

### Create (5)

1. `lib/features/subscription/presentation/widgets/billing_cycle_toggle.dart`
2. `lib/features/subscription/presentation/widgets/plan_compare_table.dart`
3. `lib/features/subscription/presentation/widgets/plan_faq_section.dart`
4. `lib/features/subscription/presentation/widgets/trust_panel.dart`
5. `lib/features/subscription/presentation/widgets/bottom_trial_cta.dart`

### Update (2)

- [`lib/features/subscription/subscription.dart`](../../lib/features/subscription/subscription.dart) — barrel exports for the new widgets.
- `test/features/subscription/` — bloc test for `SubscriptionBillingCycleChanged`, widget tests for each new widget.

## 9. Implementation order

Each step ships as a standalone PR. Build order is tuned so the screen renders correctly at every checkpoint.

| # | Step | What ships |
|---|---|---|
| 1 | Add `billingCycle` to state + event + bloc handler + bloc test. | No UI change yet. Verifies state plumbing. |
| 2 | Build `BillingCycleToggle`, wire it to the bloc, place above the existing card row. | Visible toggle that does nothing yet. |
| 3 | Restyle `plan_card.dart`: ribbons, hover lift, dual-price logic via `BlocBuilder<SubscriptionBloc, SubscriptionState>`. | Plan cards now respond to the toggle. |
| 4 | Replace screen layout shell — drop the 900 px box, switch to vertical scroll, add hero block, move "Manage Billing" link into the hero. | Page now looks like the prototype's top half. |
| 5 | Build `PlanCompareTable`. Render under cards. | Compare section in place. |
| 6 | Build `PlanFaqSection` + `TrustPanel` + money-back card. Render in the 1.5fr/1fr grid. | FAQ + trust columns landed. |
| 7 | Build `BottomTrialCta`. Wire to existing `ActivateTrial` use-case. | Visual parity with the prototype reached. |

Steps 1–4 take it from "looks broken" to "looks like the prototype's top half." Steps 5–7 fill in the rest.

## 10. Design-system compliance

Per [DESIGN.md](../../DESIGN.md) and [CLAUDE.md §14 — Never invent design tokens](../../CLAUDE.md#hard-prohibitions):

- **No hex literals.** The prototype uses `#A78BFA`, `#FFD700`, `#9CA3AF`, etc. Map each to [`app_theme.dart`](../../lib/core/theme/app_theme.dart) and add tokens there if missing. The four plan accents — grey (Free), violet (Trial), teal (Pro), gold (Enterprise) — should become named theme colours.
- **Motion durations.** Hover lift 200 ms `cubic-bezier(.4,0,.2,1)`; FAQ open 180 ms. Both already in DESIGN.md ranges; do **not** invent durations. Reference DESIGN.md §Motion before adding any `Duration(milliseconds: x)`.
- **Typography.** Title sizes from the prototype (30/16/13/12/11.5/10) map to existing `headlineSmall / titleMedium / bodyMedium / labelSmall` in [`app_theme.dart`](../../lib/core/theme/app_theme.dart). Go through `Theme.of(context).textTheme`, never literal `TextStyle(fontSize: 11)`. The existing [`plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart) violates this in many places — clean it up while you're in there.
- **Iconography.** Prefer existing `Icons.*` rounded variants over inline SVGs. Plan-icon SVGs from the prototype (`free`, `trial`, `pro`, `enterprise`) can map to `Icons.person_outline` / `Icons.timer_outlined` / `Icons.bolt` / `Icons.workspace_premium`.

## 11. Acceptance criteria

The redesign is "done" when **all** of the following hold:

1. `flutter analyze` reports **zero** issues.
2. The Subscription screen renders correctly at the minimum window size (`OmniWindowLayout` Subscription mode — see [`window_manager.dart`](../../lib/core/platform/window_manager.dart)) — no horizontal scrollbar appears unless the user shrinks below the documented minimum.
3. Toggling Monthly ↔ Yearly updates the price strings on the Pro and Enterprise cards within one frame.
4. Hovering a plan card lifts it 3 px with a 200 ms ease — no jank on a fresh debug build.
5. The compare table, FAQ, trust panel, money-back card, and bottom CTA all render in a single page with no nested scroll regions (only the outer page scrolls).
6. `OmniVersionChip` and the `_DebugTierPanel` (in `kDebugMode`) appear at the bottom, in that order.
7. All existing payment-pending logic in [`plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart#L42) (`_paymentPending`, `_pendingTimeout`, `_resumeGraceTimer`, `didChangeAppLifecycleState`) keeps working — verified by triggering an upgrade and watching the spinner / 30 s grace logic.
8. New widget tests pass; new BLoC test for `SubscriptionBillingCycleChanged` passes.
9. No new entries in [`firebase_paths.dart`](../../lib/core/constants/firebase_paths.dart) (the redesign should not introduce any new Firestore paths).
10. No `print` / `debugPrint`, no swallowed exceptions, no cross-feature `data/` imports — per [CLAUDE.md hard prohibitions](../../CLAUDE.md#hard-prohibitions).

## 12. Risks / open questions

| Risk | Mitigation |
|---|---|
| Yearly Razorpay plan IDs don't exist in `monetization_config` | Ship Option B (display-only). Card CTA falls back to monthly checkout. File follow-up to seed `pro_yearly` / `enterprise_yearly`. |
| `Enterprise` tier may not be present in `monetization_config.order` | Confirm before coding the 4-card row. `tierOrder` is read at [`subscription_remote_datasource.dart:804`](../../lib/features/subscription/data/datasources/subscription_remote_datasource.dart#L804). If only 3 tiers exist, drop the Enterprise column from compare table too. |
| FAQ copy in the prototype includes claims (refund window, NIM key BYO, midnight UTC reset) that need product sign-off | Treat copy as draft; cross-reference [16 — Monetization Plan](16_monetization_plan.md) before merging. Update either the doc or the copy so they stay aligned (per [CLAUDE.md doc map](../../CLAUDE.md#documentation-update-map)). |
| Compare table on narrow windows | The shell is Windows-only with min ~900 px (see [`omni_window_layout.dart`](../../lib/core/widgets/omni_window_layout.dart)); should fit. Worst case: horizontal scroll inside the table widget only, never the whole page. |
| Adding `billingCycle` to state breaks existing widget tests via Equatable `props` | One-line fix in any test that constructs `SubscriptionState()` literally; default value handles the rest. |
| Hover lift on `OmniCard` may conflict with the existing `hasGlow: true` decoration | Test on Pro card first (it sets `hasGlow: true`). If the glow + lift fights, gate lift on `MouseRegion.onEnter` only and skip the shadow change. |

## 13. Out of scope (follow-ups)

- Razorpay yearly plan documents in Firestore (`monetization_config` seed) + admin "Seed System Config" run. Tracked in [16 — Monetization Plan](16_monetization_plan.md).
- Animated price transition when toggling cycle (nice-to-have).
- Migrating [`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart) to the same visual language — separate task (see [25 — Billing Management](25_billing_management.md)).
- Updating the web landing page's `Pricing.tsx` to match — separate task in [`web_landing/src/components/Pricing.tsx`](../../web_landing/src/components/Pricing.tsx).

## 14. Documentation update on completion

Per [CLAUDE.md doc map](../../CLAUDE.md#documentation-update-map), when this redesign ships:

- Update [16 — Monetization Plan](16_monetization_plan.md) if any tier copy, quota numbers, or plan IDs change.
- Update [DESIGN.md](../../DESIGN.md) if any new theme tokens, motion durations, or component patterns are added.
- Update the [Global widget library](../../CLAUDE.md#global-widget-library--check-before-building) table in CLAUDE.md if any of the new widgets graduate from `lib/features/subscription/presentation/widgets/` to `lib/core/widgets/`.
- Mark the relevant entry ✅ in [23 — Pre-Launch TODO](../../docs/05_maintenance/23_pre_launch_todo.md) if this redesign was on the list.

## 15. Implementation status (shipped)

Steps 1–7 of [§9 Implementation order](#9-implementation-order) all landed. Files:

| Step | Files |
|---|---|
| 1 — `BillingCycle` state + event + handler + tests | [`subscription_state.dart`](../../lib/features/subscription/presentation/bloc/subscription_state.dart), [`subscription_event.dart`](../../lib/features/subscription/presentation/bloc/subscription_event.dart), [`subscription_bloc.dart`](../../lib/features/subscription/presentation/bloc/subscription_bloc.dart), [`subscription_bloc_test.dart`](../../test/features/subscription/presentation/bloc/subscription_bloc_test.dart) (+3 new bloc tests) |
| 2 — `BillingCycleToggle` | [`billing_cycle_toggle.dart`](../../lib/features/subscription/presentation/widgets/billing_cycle_toggle.dart) |
| 3 — Plan card restyle | [`plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart) — hover lift, ribbons, dual-price |
| 4 — Layout shell rewrite + hero block | [`subscription_screen.dart`](../../lib/features/subscription/presentation/screens/subscription_screen.dart) — `_HeroBlock` + Manage Billing link |
| 5 — Plan compare table | [`plan_compare_table.dart`](../../lib/features/subscription/presentation/widgets/plan_compare_table.dart) |
| 6 — FAQ + Trust panel | [`plan_faq_section.dart`](../../lib/features/subscription/presentation/widgets/plan_faq_section.dart), [`trust_panel.dart`](../../lib/features/subscription/presentation/widgets/trust_panel.dart) |
| 7 — Bottom trial CTA | [`bottom_trial_cta.dart`](../../lib/features/subscription/presentation/widgets/bottom_trial_cta.dart) |

### Departures from the plan

- **Yearly cycle: shipped Option B (display-only).** Yearly prices `₹6,990` (Pro) and `₹49,990` (Enterprise) are computed in [`plan_card.dart`](../../lib/features/subscription/presentation/widgets/plan_card.dart) `_pricingFor()`. Yearly checkout still uses the monthly Razorpay plan ID — wiring up real yearly plan documents in `monetization_config` is a follow-up tracked in [16 — Monetization Plan](16_monetization_plan.md).
- **"Show details" toggle removed from plan cards.** Per-engine token caps moved into the comparison table instead. Each engine row in [`plan_compare_table.dart`](../../lib/features/subscription/presentation/widgets/plan_compare_table.dart) renders the cap from `engineLimits` (e.g. `250K/mo`), `✓` if no cap, or `—` if not in the plan's `allowedTranslationModels` / `allowedTranscriptionModels`. Removed `_buildToggle`, `_buildExpandedDetails`, `_expanded` state, `_SectionLabel`, `_DetailChip`, `_collapseWhisperModels` from `plan_card.dart`.
- **Compare table is fully data-driven.** Initially planned as hardcoded marketing rows mirroring the prototype. Final implementation reads `monetization_config` via `state.plans` for quota + engine rows; only generic feature rows (translation history limit, custom NIM key, admin panel, priority support) stay hardcoded keyed by tier id.
- **Compare table collapses by default.** `_collapsedRowCount = 5` shows the four quota rows + one feature; "Show N more features" toggle expands to all rows. Added because the data-driven table grew long once engines were inlined.
- **Enterprise accent: purple, not gold.** Prototype used `#FFD700`; product preference was [`AppColors.splashPurple`](../../lib/core/theme/app_theme.dart) (`#8B5CF6`). Applied in plan card, compare table, and propagated to [`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart) for consistency (the gold hex was removed in the same audit).
- **No card glow.** Plan card now sets `hasGlow: false` everywhere instead of `plan.isTrial || plan.isPopular` — prototype is flat.
- **Equal card heights via `IntrinsicHeight`.** Plan card row wraps in [`IntrinsicHeight`](../../lib/features/subscription/presentation/screens/subscription_screen.dart) and the inner card `Column` drops `mainAxisSize.min` + wraps `_buildFeatures()` in `Expanded`, pushing CTAs to the bottom across all cards.
- **Hero block defensive layout.** Right-side group (`BillingCycleToggle` + Manage Billing button) wrapped in `Flexible(Wrap)` to handle narrow window widths without `RenderFlex` overflow.
- **Plan card price row** wraps both price + period in `Flexible` with `maxLines: 1` + ellipsis, so long Enterprise yearly prices don't overflow narrow cards.
- **Support email** referenced in [`trust_panel.dart`](../../lib/features/subscription/presentation/widgets/trust_panel.dart) is `support@omnibridge.marshalx.dev` — see [27 — Domains & Subdomains](../../docs/05_maintenance/27_domains_and_subdomains.md) for SPF/DKIM/DMARC setup status.
- **Manage Billing nav** uses `Navigator.pushReplacementNamed(AppRouter.billing)` to match the dashboard's nav-rail convention ([`app_navigation_rail.dart:419`](../../lib/features/shell/presentation/widgets/app_navigation_rail.dart#L419)).
- **Widget barrel exports skipped.** [`subscription.dart`](../../lib/features/subscription/subscription.dart) doesn't export feature widgets in any other slice, so the new widgets follow the existing convention (relative imports from the screen).
- **Widget tests skipped.** The repo has zero widget tests across all 7 features — the testing convention is bloc-only. Adding widget tests for the 5 new widgets would diverge. The 3 new bloc tests for `SubscriptionBillingCycleChanged` cover the only stateful addition.

### Architecture audit (clean)

| Check | Status |
|---|---|
| `print` / `debugPrint` in new code | None |
| Silent exception swallowing | None |
| Cross-feature `data/` imports | None |
| `.instance` outside data layer | None |
| Hardcoded Firestore paths outside [`firebase_paths.dart`](../../lib/core/constants/firebase_paths.dart) | None |
| Generated files modified | None |
| iOS/Android/macOS platform code | None |
| Presentation→domain via `ISubscriptionRepository` interface (DI) | All call sites correct |
| Hex literals introduced in new code | None |
| Hex literals fixed in adjacent existing code | `#FFD700` (gold enterprise) → `AppColors.splashPurple` in [`billing_screen.dart`](../../lib/features/subscription/presentation/screens/billing_screen.dart). The legacy `upgrade_sheet.dart` (with its `#161616` literal) was deleted entirely — quota-exceeded users now route to the redesigned Subscription screen instead of a modal. |
| `flutter analyze` | Zero issues across `lib/features/subscription/` and `test/features/subscription/` |
| `flutter test` (subscription bloc) | 8/8 pass |
