<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.

 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 30 — History Screen Redesign

> Implementation plan to rebuild the existing [`HistoryPanel`](../../lib/features/history/presentation/screens/history/history_panel.dart) so its visual language matches the redesigned Subscription ([28](28_subscription_screen_redesign.md)) and Billing ([29](29_billing_screen_redesign.md)) screens, plus the `History.html` prototype. Stays inside the **in-memory, session-scoped** history model that ships today — no persistence work in this phase.

**Source of truth for visuals:** `demo/prototypes/screens/History.html` (gitignored — local only).
**Owning feature slice:** [`lib/features/history/`](../../lib/features/history/).
**Data model:** [`HistoryEntry`](../../lib/features/history/domain/entities/history_entry.dart), populated in-memory by [`HistoryLocalDataSource`](../../lib/features/history/data/datasources/history_local_datasource.dart).
**Related docs:** [25 — Billing Management](25_billing_management.md), [29 — Billing Screen Redesign](29_billing_screen_redesign.md), [DESIGN.md](../../DESIGN.md), [CLAUDE.md](../../CLAUDE.md).

---

## 1. In-memory constraint (read first)

This redesign **does not introduce persistence**. Reasons that shape every section below:

- **Today's history is RAM-only.** [`HistoryLocalDataSource`](../../lib/features/history/data/datasources/history_local_datasource.dart) holds two `ValueNotifier<List<HistoryEntry>>` instances (`liveEntries`, `chunkedEntries`). They survive route changes but **`reset()` clears them on logout** (via `IResettable`), and a process restart wipes everything.
- **The prototype's "1.2 MB used · stored locally on this device" copy is aspirational** — it doesn't reflect what ships today. The redesign replaces that with a "Session history · cleared on logout" line so users aren't misled. Persistent local history (SQLite / Hive) is a separate epic, tracked in [§14](#14-out-of-scope-followups).
- **Tier gating stays.** [`history_panel.dart` lines 44-79](../../lib/features/history/presentation/screens/history/history_panel.dart#L44-L79) blocks the Free tier outright and shows the 5-second re-translation column only on the highest tier. The prototype doesn't mention this — keep our gating, just re-skin it.
- **No `HistoryEntry` schema rewrite.** One additive nullable field (`engine`) — no migration, nothing breaks if it's null.

## 2. Goals

Apply the same composition principles that landed in [29](29_billing_screen_redesign.md):

- **Move into `AppDashboardShell`.** The screen currently runs as its own window (`/history-panel` route, `setToHistoryPosition`, custom `WindowBorder` + `MoveWindow` header). Switching to the dashboard shell brings the nav rail, matches Subscription and Billing, and eliminates a bespoke window state. See [§8](#8-screen-level-refactor) for the navigation impact.
- **Vertical scroll, max-content ~1180.** Same width bracket as the redesigned Billing screen so the layouts feel consistent.
- **Three-pane layout** at full width: language filter sidebar (left, ~220 px) + grouped entry list (centre, flex) + entry detail panel (right, ~360 px). Mirrors the prototype.
- **Day grouping** (Today / Yesterday / N days ago / weekday name) replaces the flat ListView.
- **Tier accents from theme**, not hex literals. Unblock states: amber for free-tier gate, teal for the active filter, purple for enterprise-only chunked panel.
- **Reuse global widgets** — `OmniSearchBar`, `OmniBadge`, `OmniCard`, `OmniProgressBar` (storage card), `OmniDropdown` (collapsed lang filter on narrow widths). Don't recreate.

## 3. Non-goals

- **No persistence.** Keep the in-memory `ValueNotifier`s. Adding SQLite/Hive is out of scope — see [§14](#14-out-of-scope-followups).
- **No latency / token / confidence cells per entry.** The prototype shows a 6-cell metadata grid in the detail panel. Today's `HistoryEntry` doesn't carry latency or confidence. The redesign drops those cells rather than fabricating numbers. Engine name is the only addition (it's already known at capture time).
- **No cross-feature data import.** The detail panel shows engine as a string only; it does **not** call into `translation/data/` for live engine status. The engine name is captured at write time on the entry itself, so the History feature owns its own data.
- **No 5-second re-translation rewrite.** "Intelligent Context Refresh" stays as-is — only its column gets restyled.
- **No multi-select / bulk delete.** Single-entry delete + Clear All is the prototype's full surface area; matches what we have.
- **No export to file.** The prototype has an "Export" button. The redesign keeps the button but wires it to clipboard-only (markdown table of all visible entries) — no file picker, no `path_provider` dependency. Disk export is a follow-up.

## 4. Gap analysis — prototype vs current

| Aspect | Prototype (`History.html`) | Current ([`history_panel.dart`](../../lib/features/history/presentation/screens/history/history_panel.dart)) |
|---|---|---|
| Window | Inside `AppFrame` (their dashboard shell) | Standalone window with `WindowBorder` + `MoveWindow` |
| Page width | Three columns (~200 + flex + 380) inside max-content ~1180 | Two equal columns (Live · Chunked) full width |
| Header | "Translation History" hero + entry count + search + Export + Clear All | 32 px title bar with icon + Clear icon button |
| Search | Filters by transcription OR translation text (case-insensitive) | None |
| Lang filter | Sidebar with flag + name + count, "All languages" + top 6 sorted by frequency | None |
| Day grouping | Today / Yesterday / N days ago / weekday name | Flat scroll, no headers |
| Entry card | Lang strip (flag + ISO + arrow + flag + ISO) + engine + relative time + on-hover Copy/Delete + transcription + translation | Time + lang pair badge + transcription + translation |
| Selection | Click entry → highlight + populates detail panel | No selection state |
| Detail panel | Right column: lang pair, ORIGINAL block, TRANSLATION block, 6-cell metadata grid | Not present |
| Empty state | Centred "📜 No matching entries" + reset hint | Centred message text |
| Storage card | "Local · 1.2 MB used" + cloud-sync teaser | Not present |
| Confirm clear | Modal with backdrop blur | None — Clear runs immediately |
| Tier gates | Not represented | `_TierGateView` for free tier (full screen) and non-Enterprise (chunked column) |
| Hex literals | Many (raw `rgba(...)`, `#161616`, `C.teal+'10'`) | Several: `Color(0xFF161616)`, `Color(0xFF0F0F0F)` gradient, `Colors.tealAccent` literals, `Colors.orangeAccent`, `Colors.white10/12/38/54` |

## 5. Domain / data layer changes

Three small additive changes. None require migration. **`HistoryEntry` gains one nullable field, the datasource captures it, no callers break.**

### 5.1 Add `engine` to `HistoryEntry`

The prototype shows the engine label per row (`"Riva NMT"`, `"Llama 3.1 8B"`, etc.). It's already known at capture time — `AsrWebsocketDataSource` invokes `AddHistoryEntryUseCase` after a translation completes, and the active engine is in the same datasource.

```dart
// lib/features/history/domain/entities/history_entry.dart
class HistoryEntry {
  // ...existing fields...
  final String? engine; // 'riva-nmt' | 'llama' | 'google' | 'google_api' | 'mymemory' | null
}
```

- Nullable — old entries (mid-session before this change lands) continue to work.
- Display name resolved at render time via `sl<ISubscriptionRepository>().getModelDisplayName(engine)` — no string baked into the entry.

### 5.2 Datasource captures the active engine

```dart
// lib/features/history/data/datasources/history_local_datasource.dart
void configure({
  required String sourceLang,
  required String targetLang,
  required String? Function() activeEngineProvider, // NEW
  required Future<String> Function(...) translateFn,
}) { ... }

void addEntry(String transcription, String translation) {
  liveEntries.value = [...liveEntries.value, HistoryEntry(
    // ...
    engine: _activeEngineProvider?.call(),
  )];
}
```

The provider lambda is passed in by the translation layer at configure time. **No cross-feature import** — the datasource just receives a `String? Function()`.

Repository + use-case (`AddHistoryEntryUseCase`) signatures are **unchanged** — the engine is captured implicitly via the datasource's provider lambda. Translation BLoC's wiring is the only thing that changes upstream.

### 5.3 New use-case: `GetVisibleHistoryUseCase`

Wraps the tier-aware filtering that today lives in `_filterByTier` ([history_panel.dart:211-220](../../lib/features/history/presentation/screens/history/history_panel.dart#L211-L220)). The screen-level filter has no business in presentation — it's a domain rule:

- `rank == 0` → empty (handled at screen level — gate view shown instead)
- `rank == 1` → all `liveEntries` (session is the only window)
- `rank == 2` → `liveEntries.where(after now-3d)`
- `rank >= 3` → all `liveEntries`

```dart
class GetVisibleHistoryUseCase {
  final IHistoryRepository history;
  final ISubscriptionRepository subscription;

  GetVisibleHistoryUseCase(this.history, this.subscription);

  List<HistoryEntry> call(List<HistoryEntry> entries, String tier) { ... }
}
```

The new bloc reads through this use-case so the screen widget stops importing `ISubscriptionRepository` directly for filtering logic.

## 6. BLoC changes

Today `HistoryBloc` exposes `liveEntries`, `chunkedEntries`, `subscriptionStatus`. The redesign adds **selection + filter + search state** so they survive when the user toggles language or types in the search box.

```dart
class HistoryLoaded extends HistoryState {
  final List<HistoryEntry> liveEntries;
  final List<HistoryEntry> chunkedEntries;
  final QuotaStatus subscriptionStatus;

  // NEW
  final String search;             // current query
  final String langFilter;         // 'all' | ISO code
  final int? selectedEntryIndex;   // index into the *filtered* list
}
```

New events:

- `HistorySearchChanged(String query)`
- `HistoryLangFilterChanged(String code)` — `'all'` or ISO
- `HistoryEntrySelected(int? index)`
- `HistoryExportRequestedEvent` — copies the visible (filtered) entries to clipboard as a markdown table; no file write.

Selection lives in the bloc (not local widget state) so the right-pane detail stays put when the user types in the search box and the filtered list reflows.

`HistoryClearEvent` (existing) is kept; the screen wraps it in a `showDialog` confirm before dispatching.

## 7. New presentation widgets

All in [`lib/features/history/presentation/screens/history/components/`](../../lib/features/history/presentation/screens/history/components/) — replacing the existing `history_entry_item.dart`, `history_list_components.dart`, `history_header.dart`.

| Widget | Responsibility | Maps to prototype |
|---|---|---|
| `HistoryHeroBlock` | Title "Translation History" + count + subtitle "Session history — cleared on logout" + Search + Export + Clear All | `PageHeader` |
| `HistoryLangSidebar` | Filter list (top 6 langs by frequency) + entry-count footer + storage notice | left sidebar |
| `HistoryEntryCard` | One row: lang strip + engine + relative time + hover Copy/Delete + transcription + translation. Selectable. | `HistoryEntry` |
| `HistoryDayGroup` | Day label + count + divider, wraps a list of `HistoryEntryCard`s | `DayGroup` |
| `HistoryDetailPanel` | Right column: lang pair, ORIGINAL block, TRANSLATION block, 4-cell meta grid (engine/date/time/length) — no fabricated latency / confidence cells | `DetailPanel` |
| `HistoryConfirmClearDialog` | Material `AlertDialog` styled like the redesigned Billing dialogs (no custom modal) | `ConfirmModal` |
| `HistoryStorageNotice` | Single-card line "Session history · cleared on logout" + cloud-sync teaser CTA gated to Enterprise | replaces prototype's "1.2 MB" line |
| `HistoryEmptyState` | Three variants: no entries yet (running translator), no search match, free-tier gate | `EmptyState` + reused `_TierGateView` |

### Reuse — don't recreate

- [`OmniSearchBar`](../../lib/core/widgets/omni_search_bar.dart) for the header search input. Drops the prototype's bespoke text field.
- [`OmniBadge`](../../lib/core/widgets/omni_badge.dart) for the language strip pair (flag + ISO).
- [`OmniCard`](../../lib/core/widgets/omni_card.dart) wherever a tinted container appears (storage notice, gate view).
- The existing [`_TierGateView`](../../lib/features/history/presentation/screens/history/history_panel.dart#L225-L319) — extract to its own file `history_tier_gate.dart`, drop the inline `Colors.orangeAccent` literals (replace with `AppColors.amber`), reuse for both the free-tier full-screen gate and the chunked-panel Enterprise gate.

## 8. Screen-level refactor

```text
AppDashboardShell(currentRoute: AppRouter.historyPanel)
  └ SingleChildScrollView (vertical, max-content ~1180)
      ├ HistoryHeroBlock          (title + count + subtitle + search + Export + Clear All)
      ├ Row(IntrinsicHeight)
      │   ├ HistoryLangSidebar          (220 fixed)
      │   ├ Expanded(HistoryListColumn)  (flex; day groups; live + chunked tabs)
      │   └ HistoryDetailPanel          (360 fixed; collapses to placeholder when nothing selected)
```

### Live vs Chunked columns

The prototype only shows one entry stream. Today's screen has two side-by-side. **The redesign keeps both via a top-of-list segmented control** ([`OmniSegmentedControl`](../../lib/core/widgets/omni_segmented_control.dart) with `Live` / `5-sec`) — no extra column needed. State lives in the bloc as `entryStream: 'live' | 'chunked'`. Tier-gate the `5-sec` option to the highest tier (disable + tooltip) instead of an entire blocked column.

This collapses the layout from 2 + Detail to 1 + Detail and frees ~50 % of the screen for the entry rows.

### Window mode

- The screen leaves `WindowMode.history` and joins `WindowMode.dashboard` (the same mode used by Subscription, Billing, Settings).
- [`my_nav_observer.dart`](../../lib/core/routes/my_nav_observer.dart#L66-L67) drops the `setToHistoryPosition()` branch — the route is handled by the dashboard route map.
- [`window_manager.dart`](../../lib/core/platform/window_manager.dart#L148-L162) — `setToHistoryPosition()` is removed; `WindowMode.history` removed from the enum.
- The route stays at `'/history-panel'` to avoid touching every callsite. (Renaming the route is its own follow-up; track in [§14](#14-out-of-scope-followups).)

> **Window-management checklist** in [CLAUDE.md § Window management](../../CLAUDE.md#window-management) covers what NOT to do here. Removing a `WindowMode` value is allowed — it's just collapsing two states into one.

## 9. Concrete file change list

### Modify (8)

1. [`history_panel.dart`](../../lib/features/history/presentation/screens/history/history_panel.dart) — full rewrite as a thin shell that delegates to the new widgets. Drops the `WindowBorder` + custom gradient; wraps in `AppDashboardShell`.
2. [`history_entry.dart`](../../lib/features/history/domain/entities/history_entry.dart) — add nullable `engine` field.
3. [`history_local_datasource.dart`](../../lib/features/history/data/datasources/history_local_datasource.dart) — `configure()` takes an `activeEngineProvider`; `addEntry` captures `engine`.
4. [`history_bloc.dart`](../../lib/features/history/presentation/blocs/history_bloc.dart) — selection / filter / search / stream-toggle state; new event handlers; export action.
5. [`history_state.dart`](../../lib/features/history/presentation/blocs/history_state.dart) — extra fields on `HistoryLoaded` + `copyWith`.
6. [`history_event.dart`](../../lib/features/history/presentation/blocs/history_event.dart) — 4 new events.
7. [`history.dart` barrel](../../lib/features/history/history.dart) — re-export new widgets + use-case.
8. [`my_nav_observer.dart`](../../lib/core/routes/my_nav_observer.dart) + [`window_manager.dart`](../../lib/core/platform/window_manager.dart) — remove the `history` window-mode branch.

### Create (8)

1. `lib/features/history/presentation/screens/history/components/history_hero_block.dart`
2. `lib/features/history/presentation/screens/history/components/history_lang_sidebar.dart`
3. `lib/features/history/presentation/screens/history/components/history_entry_card.dart` (replaces `history_entry_item.dart`)
4. `lib/features/history/presentation/screens/history/components/history_day_group.dart`
5. `lib/features/history/presentation/screens/history/components/history_detail_panel.dart`
6. `lib/features/history/presentation/screens/history/components/history_storage_notice.dart`
7. `lib/features/history/presentation/screens/history/components/history_tier_gate.dart` (extracted from inline `_TierGateView`)
8. `lib/features/history/domain/usecases/get_visible_history_usecase.dart` + DI registration in [`usecase_di.dart`](../../lib/core/di/parts/usecase_di.dart).

### Delete (2)

1. `lib/features/history/presentation/screens/history/components/history_entry_item.dart` — replaced by `history_entry_card.dart`.
2. `lib/features/history/presentation/screens/history/components/history_list_components.dart` — `buildHistoryColumnHeader` / `buildHistoryEmptyState` move into `history_day_group.dart` and `history_empty_state.dart` (or get inlined).

### Translation-side wiring (1)

[`asr_websocket_datasource.dart`](../../lib/features/translation/data/datasources/asr_websocket_datasource.dart) (or whichever Translation layer file calls `historyDataSource.configure(...)`) — pass an `activeEngineProvider` lambda that returns the current settings' translation model ID. Stays inside the Translation feature — no History feature import.

### Tests (2)

- `test/features/history/domain/get_visible_history_usecase_test.dart` — covers the four tier-rank branches and the 3-day cutoff edge case (entry exactly at boundary).
- `test/features/history/presentation/blocs/history_bloc_test.dart` — extended: `HistorySearchChanged` / `HistoryLangFilterChanged` / `HistoryEntrySelected` / clear flow with confirm cancellation.

## 10. Implementation order

| # | Step | What ships |
|---|---|---|
| 1 | Add nullable `engine` to `HistoryEntry`. Datasource captures it via `activeEngineProvider`. Translation-side wires the lambda. | New entries carry engine. UI unchanged. |
| 2 | `GetVisibleHistoryUseCase` + unit tests. Move tier filter out of the screen widget. | Filter logic owned by domain; existing screen still works. |
| 3 | Extend `HistoryBloc` with search / filter / selection / stream-toggle state + new events. Test the new event handlers. | Bloc tests pass; UI still using old layout but bloc shape ready. |
| 4 | Replace `history_panel.dart` with the dashboard-shell shell + hero block. Drop `WindowBorder` + gradient + custom 32 px header. Remove `setToHistoryPosition()` and the `historyPanel` branch in `MyNavObserver`. | Screen visually broken in places but inside the dashboard shell — header + nav rail show. |
| 5 | `HistoryEntryCard` + `HistoryDayGroup` + `HistoryEmptyState`. Wire to bloc's filtered list. | Centre column complete with hover Copy/Delete + day grouping. |
| 6 | `HistoryLangSidebar` + `HistoryStorageNotice`. Lang counts derived from `state.liveEntries` (memoised). | Left sidebar complete. |
| 7 | `HistoryDetailPanel`. 4-cell meta grid (engine, date, time, length). | Right pane complete; selection round-trips. |
| 8 | `HistoryTierGate` (extracted) + the `OmniSegmentedControl` Live/5-sec toggle with the Enterprise gate on `5-sec`. | Tier gating in its final form; chunked column collapses into a toggle. |
| 9 | Confirm-clear dialog + Export-to-clipboard action. | Destructive action gated; Export button does something useful. |

Steps 1-3 are data + bloc prep — UI looks identical to today after each. Step 4 onwards is the visible refactor.

## 11. Design-system compliance

Per [DESIGN.md](../../DESIGN.md) and [CLAUDE.md §14](../../CLAUDE.md#hard-prohibitions):

- **No hex literals.** The current screen has several — `Color(0xFF161616)`, `Color(0xFF0F0F0F)`, plus raw `Colors.tealAccent` / `Colors.orangeAccent` / `Colors.white10|12|38|54|70`. All must be replaced:

| Current | Replacement |
|---|---|
| `Color(0xFF161616) → 0xFF0F0F0F` gradient | drop entirely — the dashboard shell already provides the background |
| `Colors.tealAccent` | `AppColors.accentTeal` |
| `Colors.orangeAccent` (tier-gate) | `AppColors.amber` |
| `Colors.redAccent` (delete / clear) | `AppColors.accentRed` |
| `Colors.white10` | `AppColors.cardBorder` or `AppColors.white(0.06)` |
| `Colors.white12` | `AppColors.cardBorder` |
| `Colors.white24` | `AppColors.textFaint` |
| `Colors.white38` | `AppColors.textDisabled` |
| `Colors.white54` | `AppColors.textMuted` |
| `Colors.white70` | `AppColors.textSecondary` |

- **Tier accents come from the same map [29 §11](29_billing_screen_redesign.md#11-design-system-compliance) and [28 §15](28_subscription_screen_redesign.md#15-implementation-status-shipped) use** — `free → textSecondary`, `trial → amberAccent`, `pro → accentTeal`, `enterprise → splashPurple`. The chunked-panel "Enterprise feature" badge picks `splashPurple`; the active language filter pill picks `accentTeal`.
- **Motion / shapes.** Reuse `AppShapes.sm/md/lg`. Hover lift on entry cards (200 ms ease, –1 px translateY) — same recipe as the redesigned plan / billing cards but smaller (entries are denser).
- **Typography.** Go through `Theme.of(context).textTheme`. The prototype uses 9 / 10 / 11.5 / 12 / 12.5 / 13 / 13 / 15 — map to `labelSmall / bodySmall / bodyMedium / bodyLarge / titleSmall`.
- **Iconography.** Material rounded variants, no inline SVGs. Map: `history_rounded`, `arrow_forward_rounded` (lang pair arrow), `copy_rounded`, `delete_outline_rounded`, `download_rounded` (Export), `clear_all_rounded` (Clear All), `manage_search_rounded` (filter sidebar header), `inbox_outlined` (empty state).
- **Animations.** AnimatedContainer + MouseRegion for hover lift (200 ms `Curves.easeOut`); AnimatedSize for the detail panel's enter/exit; AnimatedSwitcher for the empty state.

## 12. Acceptance criteria

1. `flutter analyze` reports **zero** issues across `lib/features/history/` and `test/features/history/`.
2. The History screen renders correctly inside `AppDashboardShell` at the minimum window size (no horizontal scroll, no overflow warnings).
3. **All four tier states render correctly:**
   - `free` → full-screen `HistoryTierGate` ("Upgrade to Trial+ to access history")
   - `trial` → live entries from current session only; 5-sec toggle disabled with tooltip
   - `pro` → live entries from the last 3 days; 5-sec toggle disabled with tooltip
   - `enterprise` → unlimited live entries; 5-sec toggle enabled
4. Searching filters by both `transcription` and `translation` (case-insensitive); language filter narrows by `sourceLang`. Both filters compose. Empty result shows "No matching entries" with a Reset Filters CTA.
5. Selecting an entry highlights it (teal accent border) and populates `HistoryDetailPanel` with the original, translation, and 4-cell meta grid. Selection persists across search edits.
6. Hover on a row reveals Copy + Delete icon-buttons. Copy lands the `<source>\n→ <translation>` in clipboard with a toast. Delete removes the row from the in-memory list (no confirm — single-row is undoable via the cleared list snapshot kept in bloc).
7. Clear All shows a confirm dialog; cancelling does nothing; confirming wipes both `liveEntries` and `chunkedEntries`.
8. Export button copies a markdown table of all visible (filtered + grouped) entries to the clipboard. Toast confirms.
9. The 5-sec `OmniSegmentedControl` swaps the centre list to `chunkedEntries` for Enterprise users; clicking it on lower tiers shows a "Requires Enterprise" toast.
10. New `GetVisibleHistoryUseCase` unit test passes; existing `HistoryBloc` tests still pass after extension.
11. No `print` / `debugPrint`, no swallowed exceptions, no cross-feature `data/` imports, no `.instance` outside the data layer, **no hex literals** — same audit gates as [29 §16](29_billing_screen_redesign.md#16-implementation-status-shipped).

## 13. Risks / open questions

| Risk | Mitigation |
|---|---|
| Moving History out of its own window changes the user's mental model — they may expect a popup as before | Keep the route name (`/history-panel`) so deep links still work. The visual change is the upside; if the team wants a popup variant for the overlay use-case, that's a separate translucent panel — out of scope. |
| `HistoryEntry.engine` is null for entries written before this PR ships *during the same session* | Detail panel gracefully shows `"—"` in the engine cell. UI doesn't break. |
| `activeEngineProvider` lambda creates a closure that reads from the Translation BLoC — risk of stale value | Provider reads the *current settings doc* (single source of truth via repository), not BLoC state. No staleness. |
| Memoising lang counts (`Map<String, int>` over a list that mutates on every entry) | Compute lazily inside the bloc with `equatable`-friendly props; only recompute when `liveEntries.length` changes. |
| Detail panel makes the page feel narrow on minimum window (~600 px) | Below ~900 px viewport, hide the lang sidebar and collapse the detail panel into a bottom drawer (similar to mobile inbox patterns). Width breakpoints per [DESIGN.md](../../DESIGN.md). |
| Tier gate `_TierGateView` extraction may surface that today's gate doesn't link to `/billing` (only `/subscription`) | Update the extracted version to route to `/subscription` (current behaviour). Billing only exists for paid users — Free users go to subscription first. |
| Removing `WindowMode.history` could break other places that switch on the enum | `grep WindowMode.history` — only `window_manager.dart` and `my_nav_observer.dart` reference it. Nothing else. |

## 14. Out of scope (follow-ups)

- **Persistent local history.** Today's RAM-only model works for power users who keep the app running; for casual sessions a Hive box scoped to `users/{uid}` would survive restarts. Tracked separately because the schema choice (Hive vs SQLite vs Firestore subcollection for cloud sync) is a product call, not a screen-redesign call.
- **Cloud history sync.** Would require a Firestore subcollection + paid tier gate. The storage notice card is already worded as a teaser for this — the CTA can light up once the feature lands.
- **Disk export.** A real "Export to .csv / .json / .md file" action with `path_provider` + `file_picker`. Clipboard is enough for v1.
- **Multi-select + bulk delete.** Selection state in the bloc already supports `int?` — easy to lift to `Set<int>` later.
- **Per-entry latency / confidence.** Requires the Translation pipeline to attach those values to the entry — a Flutter ↔ Python contract change. Doc 22 (token estimation) gives some of this; the rest needs a server-side change.
- **Route rename `/history-panel` → `/history`.** Cosmetic; defer to avoid touching every nav callsite for no functional benefit.

## 15. Documentation update on completion

Per [CLAUDE.md doc map](../../CLAUDE.md#documentation-update-map), when this redesign ships:

- Add an **Implementation status (shipped)** section to this doc once landed, mirroring [28 §15](28_subscription_screen_redesign.md#15-implementation-status-shipped) and [29 §16](29_billing_screen_redesign.md#16-implementation-status-shipped) — file map per step + departures + architecture audit.
- Update [03_project_structure.md](../01_core/03_project_structure.md) — history slice description: new components, new use-case, new entity field.
- Update [05_flutter_architecture.md](../02_architecture/05_flutter_architecture.md) — add `GetVisibleHistoryUseCase` to the History feature use-cases list.
- Update [13_new_screen_setup_guide.md](../03_guides/13_new_screen_setup_guide.md) **only if** the dashboard-shell migration introduces a new pattern worth documenting.
- Update [00_doc_index.md](../../docs/00_doc_index.md) — add `30` next.
- Update [23_pre_launch_todo.md](../05_maintenance/23_pre_launch_todo.md) — new "History screen redesign" row in Completed.

## 16. Implementation status (shipped)

Landed on `main` (single commit). Numbered against §10:

| Step | Status | Files touched |
|---|---|---|
| 1 — Engine threaded through the data chain | ✅ | [`history_entry.dart`](../../lib/features/history/domain/entities/history_entry.dart) (+`engine`), [`history_local_datasource.dart`](../../lib/features/history/data/datasources/history_local_datasource.dart) (`configure(activeEngineProvider)` + `addEntry` captures it; chunk-timer write also captures it), [`i_history_repository.dart`](../../lib/features/history/domain/repositories/i_history_repository.dart) + [`history_repository_impl.dart`](../../lib/features/history/data/repositories/history_repository_impl.dart) (pass-through), [`configure_history_usecase.dart`](../../lib/features/history/domain/usecases/configure_history_usecase.dart), [`asr_websocket_datasource.dart`](../../lib/features/translation/data/datasources/asr_websocket_datasource.dart) (passes `() => translationModel`) |
| 2 — `GetVisibleHistoryUseCase` + tests | ✅ | New use-case [`get_visible_history_usecase.dart`](../../lib/features/history/domain/usecases/get_visible_history_usecase.dart), DI in [`usecase_di.dart`](../../lib/core/di/parts/usecase_di.dart), 7 tests in [`get_visible_history_usecase_test.dart`](../../test/features/history/domain/get_visible_history_usecase_test.dart) — all green |
| 3 — Bloc state + new events + tests | ✅ | [`history_event.dart`](../../lib/features/history/presentation/blocs/history_event.dart) (+`HistorySearchChanged`, `HistoryLangFilterChanged`, `HistoryEntrySelected`, `HistoryStreamToggled`, `HistoryEntryDeleted`, plus the `HistoryStream` enum), [`history_state.dart`](../../lib/features/history/presentation/blocs/history_state.dart) (search / langFilter / selectedIndex / stream + `copyWith`), [`history_bloc.dart`](../../lib/features/history/presentation/blocs/history_bloc.dart) (handlers + optional `IHistoryRepository` for delete), [`bloc_di.dart`](../../lib/core/di/parts/bloc_di.dart). 6 new bloc tests appended in [`history_bloc_test.dart`](../../test/features/history/presentation/blocs/history_bloc_test.dart) |
| 4 — Layout shell rewrite | ✅ | [`history_panel.dart`](../../lib/features/history/presentation/screens/history/history_panel.dart) — full rewrite; wraps in `AppDashboardShell`, drops `WindowBorder` + custom gradient + 32 px header. `WindowMode.history` removed from [`window_manager.dart`](../../lib/core/platform/window_manager.dart) along with `setToHistoryPosition()`; the History branch in [`my_nav_observer.dart`](../../lib/core/routes/my_nav_observer.dart) falls through to `setToDashboardPosition()`. |
| 5 — Centre column widgets | ✅ | New [`history_entry_card.dart`](../../lib/features/history/presentation/screens/history/components/history_entry_card.dart), [`history_day_group.dart`](../../lib/features/history/presentation/screens/history/components/history_day_group.dart), [`history_empty_state.dart`](../../lib/features/history/presentation/screens/history/components/history_empty_state.dart). Shared metadata helpers in [`history_lang_metadata.dart`](../../lib/features/history/presentation/screens/history/components/history_lang_metadata.dart) (flag map, relative-time, day-label). |
| 6 — Lang sidebar + storage notice | ✅ | [`history_lang_sidebar.dart`](../../lib/features/history/presentation/screens/history/components/history_lang_sidebar.dart) (top-6 langs by count, accent on active, count badges) + [`history_storage_notice.dart`](../../lib/features/history/presentation/screens/history/components/history_storage_notice.dart) (replaces the prototype's "1.2 MB" copy with "session only — cleared on logout") |
| 7 — Detail panel | ✅ | [`history_detail_panel.dart`](../../lib/features/history/presentation/screens/history/components/history_detail_panel.dart) — empty placeholder + selected-state with `ORIGINAL`/`TRANSLATION` blocks (per-block copy button) + 4-cell meta grid (engine via `getModelDisplayName`, chars, date, time). `AnimatedSwitcher` for the empty/selected swap. |
| 8 — Tier gate + Live/5-sec toggle | ✅ | New [`history_tier_gate.dart`](../../lib/features/history/presentation/screens/history/components/history_tier_gate.dart) used both as the full-screen gate (free tier) and conceptually for the 5-sec stream gate. The 5-sec switch is built around `OmniSegmentedControl` — locked tiers see a `LOCKED` chip and a SnackBar on tap. |
| 9 — Confirm-clear dialog + Export-to-clipboard | ✅ | Inline `_confirmAndClear` in `history_panel.dart` reuses the styled `AlertDialog` pattern from `BillingSubscriptionCard`. `_exportToClipboard` formats the visible (filtered) entries as a markdown table and lands them on the system clipboard with a toast. |

### Departures from plan

- **Three obsolete component files were deleted in step 9 instead of step 5** — `history_entry_item.dart`, `history_list_components.dart`, and `history_header.dart` (the old 32 px overlay-style title bar). Plan §9 listed only the first two; deleting the header was a follow-on of step 4 (the new screen uses `OmniHeader` directly inside `AppDashboardShell`).
- **`HistoryEntryDeleted` reaches the datasource via a new `removeEntry` method on the repository chain** — plan didn't spell this out but in-memory delete that doesn't reach the source list would be undone the next time the notifier fires. The bloc now optionally takes `IHistoryRepository` so test wiring stays unchanged when the dependency is omitted.
- **No new "Reset Filters" CTA route** — the reset action is wired through the empty-state's button (per acceptance criteria #4). No standalone bloc event was needed; the screen dispatches `HistorySearchChanged('')` + `HistoryLangFilterChanged('all')` together.
- **Width breakpoint collapse for narrow windows is not yet implemented** — plan §13 flagged this. The 3-pane layout still renders at minimum window width (~600 px) and squeezes; a follow-up will move to a `LayoutBuilder` that hides the sidebar / collapses the detail panel below ~900 px.

### Architecture audit (clean)

- ✅ No `print` / `debugPrint` — entry capture goes through the existing repository chain.
- ✅ No swallowed exceptions.
- ✅ No cross-feature `data/` imports — the engine provider is a `String? Function()` lambda passed at configure time.
- ✅ No `.instance` outside the data layer.
- ✅ **No hex literals** — every colour comes from `AppColors.*`. The full `Color(0xFF161616)`/`Color(0xFF0F0F0F)` gradient and all `Colors.tealAccent`/`Colors.orangeAccent`/`Colors.white10|12|24|38|54|70` literals from the old screen are gone.
- ✅ Tier filter logic moved out of the screen widget into `GetVisibleHistoryUseCase` (domain).
- ✅ `flutter analyze` — zero issues across `lib/` and `test/`.
- ✅ All 17 history tests pass (7 use-case + 10 bloc).

### Follow-ups

1. **Persistent local history** — replace the in-memory `ValueNotifier`s with a Hive box scoped to `users/{uid}` so the list survives app restart. Storage notice card already teases this; the CTA can light up once the feature lands.
2. **Cloud history sync** for paid tiers — Firestore subcollection `users/{uid}/history/{push-id}`.
3. **Width-aware collapse** — `LayoutBuilder` to hide the sidebar / drop the detail panel into a bottom drawer below ~900 px viewport.
4. **Disk export** — real "Export to .csv / .json / .md file" action with `path_provider` + `file_picker`. Clipboard is enough for v1.
5. **Multi-select + bulk delete** — selection state in the bloc already supports `int?`; lift to `Set<int>` later.
6. **Per-entry latency / confidence** — needs the Translation pipeline (Flutter ↔ Python) to attach those values to the entry. Out of scope for this redesign.

## 17. Post-redesign refinement

After the initial ship, two iterations landed that change the §16 layout meaningfully — capture them here so the doc reflects what's actually on `main`:

### 17.1 Visual restructure — three independent panes, no detail

User feedback: the original §16 wrapped the three columns in one big bordered shell; the new request was "remove that one big card; on right panel show retranslation; in mid translation history newest on top first; remove the details panel."

What landed:

| Step 16 (initial) | Post-redesign (current) |
|---|---|
| Three panes in a single rounded `Container(border)` shell with `bg: cardBackground` | Three **independent** panes, no shell. Lang sidebar gets `bg: black 15%` + `border-right`; centre is page bg; right pane gets `bg: black 18%` + `border-left`. Mirrors the prototype's `rgba(0,0,0,0.15)/(0.18)` treatment. |
| Centre column had `OmniSegmentedControl` toggling `Live` / `5-sec re-translations` | **Toggle removed.** Centre always shows live transcripts; 5-sec re-translations have their own pane on the right. Both streams visible simultaneously. |
| Centre entries grouped oldest-first inside their day groups | **Newest first.** Centre and right panes both reverse the filtered list before grouping, so the most recent entry sits at the top of "Today". |
| `HistoryDetailPanel` on the right with `ORIGINAL`/`TRANSLATION` blocks + 4-cell meta grid | **Detail panel deleted.** Replaced by `_RetranslationPane` — a chunked-entries list (or `HistoryTierGate` for non-Enterprise users) with the same `HistoryEntryCard` styling. |
| Entry cards were tap-to-select with a teal accent border | **Click-to-select dropped.** Cards keep hover-only Copy / Delete icon-buttons; no selected state. |

Files deleted: [`history_detail_panel.dart`](../../lib/features/history/presentation/screens/history/components/history_detail_panel.dart) (gone), inline `_StreamToggle` class in `history_panel.dart` (gone). New private widget `_RetranslationPane` lives inline in the screen file (paired tightly with the layout — not reused elsewhere).

### 17.2 Bloc cleanup

After the visual changes, the leftover state in `HistoryBloc` no longer had any UI consumer. Cleaned up:

- `HistoryStream` enum — removed
- `HistoryEntrySelected` event + `_selectedIndex` field + `HistoryEntrySelected` handler — removed
- `HistoryStreamToggled` event + `_stream` field + `HistoryStreamToggled` handler — removed
- `HistoryLoaded.selectedIndex`, `HistoryLoaded.stream`, and `copyWith.clearSelection` flag — removed
- `HistorySearchChanged` / `HistoryLangFilterChanged` no longer reset selection (because there is no selection)

3 corresponding tests in [`history_bloc_test.dart`](../../test/features/history/presentation/blocs/history_bloc_test.dart) deleted. The remaining 7 bloc tests + 7 use-case tests still pass — 14 total.

### 17.3 Server-side fixes uncovered during testing

While testing the redesign, two server-side issues surfaced that were unrelated to the History feature itself but became visible because of how often we exercised the live pipeline. Fixed in the same commit chain:

1. **Missing `device_update` / `mic_update` handlers.** The Flutter Settings screen has been emitting these WebSocket commands for a while ([`translation_websocket_client.dart`](../../lib/features/translation/data/datasources/translation_websocket_client.dart) — `sendDeviceUpdate`, `sendMicToggleUpdate`) but the server's [`router.py`](../../server/src/network/router.py) had no handlers registered, so it logged `[Router] No handler registered for command: device_update` and silently dropped them.
   - Added `update_devices(websocket, msg)` and `update_mic(websocket, msg)` in [`config_handler.py`](../../server/src/network/handlers/config_handler.py).
   - Both write to `ctx.config`, hot-swap `audio_meter` via its existing `configure(...)` method, and trigger a light `SessionHandler.start(reload_models=False)` if a session is currently running.
   - Registered in [`flutter_server.py`](../../server/flutter_server.py) alongside `volume_update`.

2. **Stuck session after a language change (light-restart fragility).** Switching source/target language during a live session occasionally left captures running but no captions appearing — only pause + resume restored output. Two contributing causes, both fixed:
   - **Session lifecycle was implicit.** [`audio_poll_loop`](../../server/src/audio/handler.py) checked `session_id == get_context_func()["session_id"]` as a secondary exit, but `ctx.session_id` was never incremented, so old and new audio_poll_loops both looked like "session 0" and the lifecycle relied entirely on `is_running` flapping. [`session_handler.py`](../../server/src/network/handlers/session_handler.py) now increments `ctx.session_id` once per `start()` call (after the inner `stop()`, before the new thread spawn) so the old loop has a clean, race-free exit signal.
   - **Stale dedup state could swallow the first new transcript for up to 6 seconds.** [`asr_dispatcher.py`](../../server/src/asr/asr_dispatcher.py) keeps a 6-second `_last_transcript` dedup window. Across a light restart with the same orchestrator instance, that memory carried over — a fresh first transcript that happened to match got silently dropped. Added `ASRDispatcher.reset_dedup_state()` and call it from [`orchestrator.py`](../../server/src/pipeline/orchestrator.py) `start_stream()` whenever it reconfigures the dispatcher.

   Pause + resume bypassed both because it does a full `reload_models=True` that recreates Riva ASR's gRPC services. The fixes above make the *light* restart path equivalent for the failure modes that mattered.

3. **Open follow-up:** if the bug recurs after these fixes, the next suspect is Riva ASR's gRPC channel state — specifically, when switching into a Canary-only language ("auto" → multi) the warmup fires in a background thread and the first real chunk can pay the 5-6s TLS handshake cost, which can look like "stuck" to the user. If this is a recurring complaint we'll add a synchronous re-warmup on light restart.
