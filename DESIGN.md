# DESIGN.md — Omni Bridge

> Machine-readable design system spec for **Omni Bridge**. AI design agents (Google Stitch, Claude, v0, etc.) should read this file first before generating any UI, motion, or marketing artifact.
>
> **Source of truth:** `lib/core/theme/app_theme.dart` (runtime app). This file mirrors every token from that file verbatim, and adds the motion, iconography, and video-export rules that live in the design-export bundle.
>
> **When values diverge between the runtime app and the demo video:** the runtime app wins for any generated UI. The demo sizes apply only to the 27 s video export.

---

## 1. Brand Identity

| Field | Value |
|---|---|
| Name | **Omni Bridge** |
| Tagline | *Any language. One app.* |
| Subline | *Real-time speech translation, right on your desktop.* |
| Platform | **Windows 10 / 11 desktop** (Flutter) — no mobile, no web, no macOS |
| Tone | Energetic & bold · punchy motion · technical-but-friendly · zero filler |
| Voice | Confident, declarative. Say what it does, not what you hope users feel. |
| Audience | Bilingual professionals, live-meeting users, localization teams, developers |
| Category | Real-time AI translation · desktop productivity |
| Repo | `github.com/Marshal-GG/omni-bridge-translator` |
| Stack | Flutter 3 · `bitsdojo_window` · `get_it` · BLoC · Firebase · Python FastAPI server |

### Logo

- **Asset:** `assets/icon.png` (square PNG) — also serves as the Windows taskbar / tray icon.
- **Minimum size:** 16 px favicon · 18 px in window chrome · 32 px in nav rail · 96–132 px in hero reveals.
- **Teal glow (size ≥ 32 px):** `drop-shadow(0 6px 18px #64FFDA55) drop-shadow(0 0 1px rgba(0,0,0,0.4))`
- **Hero glow (size ≥ 96 px):** `drop-shadow(0 0 60px #64FFDA88)`
- Never recolor, outline, add drop-caps, or animate the mark's interior.

---

## 2. Color Palette

All colors below mirror `AppColors` and `UsageColors` in `lib/core/theme/app_theme.dart`. **Dark theme is the only theme** — there is no light mode and no theme switcher.

### 2.1 Surfaces — `AppColors`

| Token | Hex | Flutter const | Use |
|---|---|---|---|
| `bg.deepest` | `#0F0F0F` | `AppColors.bgDeepest` | Titlebar, nav rail, window frame, splash background |
| `bg.deep` | `#121212` | `AppColors.bgDeep` | Primary window background, surface in ColorScheme |
| `bg.medium` | `#161616` | `AppColors.bgMedium` | Secondary surfaces, gradients |
| `bg.light` | `#1A1A1A` | `AppColors.bgLight` | Hover states on dark surfaces |
| `bg.elevated` | `#1E1E1E` | `AppColors.bgElevated` | Cards, dialogs, dropdowns, `surfaceContainerHighest` |
| `bg.menu` | `#2C2C2C` | `AppColors.bgMenu` | Context menus, tooltips |

### 2.2 Brand accents

| Token | Hex | Flutter const | Use |
|---|---|---|---|
| `accent.teal` ★ | `#64FFDA` (Colors.tealAccent) | `AppColors.accentTeal` | **Primary** — active state, CTAs, focus ring, progress, `ColorScheme.primary` |
| `accent.cyan` | `#18FFFF` (Colors.cyanAccent) | `AppColors.accentCyan` | Secondary accent, FAB default, `ColorScheme.secondary` |
| `accent.red` | `#FF5252` (Colors.redAccent) | `AppColors.accentRed` | Destructive, error, `ColorScheme.error` |
| `translation.teal` | `#2DD4BF` | `AppColors.translationTeal` | Translation stream, gradient stop, `ColorScheme.tertiary` |
| `semantic.asr` | `#6366F1` | `AppColors.semanticAsr` | ASR/source stream (speech recognition) |
| `semantic.translation` | `#10B981` | `AppColors.semanticTranslation` | Emerald — success, "real-time" indicator, translation feature highlight |

### 2.3 Splash / decorative

| Token | Hex | Flutter const | Use |
|---|---|---|---|
| `splash.blue` | `#3B82F6` | `AppColors.splashBlue` | Splash/onboarding gradient stop |
| `splash.purple` | `#8B5CF6` | `AppColors.splashPurple` | Splash gradient, avatar gradient start |
| `amber` | `#F59E0B` | `AppColors.amber` | Trial countdown, warnings, highlight chips |
| `orange` | `#EF4444` | `AppColors.orange` | ⚠ Named "orange" but is red — halt/failure states |
| `pink` | `#EC4899` | `AppColors.pink` | Avatar gradient end, decorative |
| `offWhite` | `#E8E8E8` | `AppColors.offWhite` | Chat message text, `onTertiaryContainer` |
| `errorDark` | `#2A1A1A` | `AppColors.errorDark` | Error container background |

### 2.4 Ticket statuses (Support feature)

| Token | Color | Flutter const |
|---|---|---|
| `status.open` | `Colors.blueAccent` | `AppColors.statusOpen` |
| `status.inProgress` | `Colors.orangeAccent` | `AppColors.statusInProgress` |
| `status.resolved` | `Colors.greenAccent` | `AppColors.statusResolved` |
| `status.closed` | `Colors.grey` | `AppColors.statusClosed` |

### 2.5 Usage dashboard — `UsageColors`

Distinct palette for the analytics dashboard (`/usage`):

| Token | Hex | Use |
|---|---|---|
| `usage.cardBackground` | `#1A1D2E` | Engine cards (slightly blue-tinted dark) |
| `usage.statBackground` | `rgba(255,255,255,0.03)` | Stat tile fill |
| `usage.asrAccent` | `#818CF8` | ASR engines (lighter indigo than `semantic.asr`) |
| `usage.translationAccent` | `#2DD4BF` | Translation engines |
| `usage.disabledAccent` | `#64748B` | Out-of-plan / disabled engines (slate grey) |
| `usage.errorRed` | `#EF4444` | Exceeded quota |
| `usage.barTrack` | `rgba(255,255,255,0.06)` | Progress bar track |

Helper rule: `UsageColors.accentFor({isAsr, isInPlan})` returns `disabledAccent` if not in plan, else `asrAccent` or `translationAccent`.

### 2.6 Text

| Token | Value | Flutter const |
|---|---|---|
| `text.primary` | `#FFFFFF` | `AppColors.textPrimary` |
| `text.secondary` | `Colors.white70` (≈ 70%) | `AppColors.textSecondary` |
| `text.muted` | `Colors.white54` (≈ 54%) | `AppColors.textMuted` |
| `text.disabled` | `Colors.white38` (≈ 38%) | `AppColors.textDisabled` |
| `text.faint` | `Colors.white24` (≈ 24%) | `AppColors.textFaint` |

### 2.7 Glass / card

| Token | Value | Flutter const |
|---|---|---|
| `card.background` | `rgba(255,255,255,0.05)` (`0x0DFFFFFF`) | `AppColors.cardBackground` |
| `card.border` | `rgba(255,255,255,0.08)` (`0x14FFFFFF`) | `AppColors.cardBorder` |

### 2.8 Gradients

| Name | Flutter / CSS | Where |
|---|---|---|
| `primaryGradient` | `LinearGradient([accentCyan, translationTeal], topLeft → bottomRight)` | Default brand gradient, `AppColors.primaryGradient` |
| `gradient.tagline` | `135deg, #64FFDA → #2DD4BF` | Hero tagline emphasis word |
| `gradient.progress` | `90deg, #6366F1 → #64FFDA → #2DD4BF` | Top progress ribbon (demo video) |
| `gradient.avatar` | `135deg, #8B5CF6 → #EC4899` | User-initials avatar |

**Do not invent new gradient pairs.** If a gradient is needed for new UI, use `primaryGradient` or pick a pair from this list.

### 2.9 Ambient backgrounds & orbs

Every hero / marketing surface in Omni Bridge layers **four** things on top of the solid base color: a radial gradient for depth, two blurred color orbs for warmth, an optional vignette, and a whisper-low ambient-color noise layer. Flat `#0F0F0F` fills are for UI chrome only — never use them on hero or full-screen surfaces.

#### 2.9.1 Base canvas tones

| Token | Hex | Use |
|---|---|---|
| `canvas.bold` | `#0a0a0a` | **Default demo body** — bolder / slightly warmer feel |
| `canvas.cinematic` | `#050508` | Cinematic tone variant (darker, pushes orbs forward) |
| `canvas.hookDark` | `#050609` | Scene 0 hook outer edge |
| `canvas.hookCenter` | `#0a1218` | Scene 0 hook center — very subtle blue-black tint |

#### 2.9.2 Layered hero background (recipe)

Stack, back to front:

```
1. Base canvas fill          → canvas.bold (#0a0a0a)
2. Radial gradient            → radial-gradient(ellipse at center, canvas.hookCenter 0%, canvas.hookDark 80%)
3. Orb A (indigo, top-left)   → 380 px circle @ 15% left / 20% top · blur 40 px · opacity via ${asrIndigo}22 (~13%)
4. Orb B (teal, bottom-right) → 420 px circle @ 10% right / 10% bottom · blur 40 px · opacity via ${translationTeal}22
5. Vignette (optional)        → radial-gradient(ellipse at center, transparent 30%, rgba(0,0,0,X) 100%)
                                  X = 0.2 at rest, ramps to 0.9 during dramatic collapses
6. Noise layer (optional)     → see §2.9.4
```

Orbs are `position: absolute` children — they live inside the hero container, **do not** scroll with content, **do not** block pointer events (`pointer-events: none`).

#### 2.9.3 CTA / closing orb (pulsing)

The CTA scene uses a single large teal orb instead of two accent orbs, and it **pulses**:

| Property | Value |
|---|---|
| Background fill | `radial-gradient(ellipse at center, bg.deep 0%, bg.deepest 70%)` |
| Orb size | 600 × 600 px |
| Orb fill | `radial-gradient(circle, ${accentTeal}18 0%, transparent 60%)` |
| Orb blur | `filter: blur(60px)` |
| Orb animation | `ob-pulse 4s ease-in-out infinite alternate` (slow, subtle) |
| Position | centered |

#### 2.9.4 Noise / ambient-color layer (`.noise::before`)

A whisper-low overlay that introduces two tiny color-bleed radials. Use on full-screen marketing surfaces only — never inside cards or small components.

```css
.noise::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  background-image:
    radial-gradient(circle at 20% 10%, rgba(45, 212, 191, 0.07), transparent 40%),
    radial-gradient(circle at 85% 85%, rgba(99, 102, 241, 0.08), transparent 45%);
}
```

Colors are `translationTeal` (top-left, 7% alpha) and `asrIndigo` (bottom-right, 8% alpha). Fixed positions — never randomize them per session.

#### 2.9.5 Flutter equivalents

Dart equivalents for each layer — the runtime app uses these on the splash / translation-overlay / CTA surfaces. Never use a plain `Container(color: ...)` on a hero route.

```dart
// Layer 1 + 2 — base fill + radial gradient
Container(
  decoration: const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center, radius: 0.9,
      colors: [Color(0xFF0A1218), Color(0xFF050609)],
      stops: [0.0, 0.8],
    ),
  ),
  child: Stack(children: [
    // Layer 3 — indigo orb (top-left)
    Positioned(
      left: -40, top: -40,
      child: _Orb(size: 380, color: const Color(0xFF6366F1), alpha: 0.13),
    ),
    // Layer 4 — teal orb (bottom-right)
    Positioned(
      right: -60, bottom: -60,
      child: _Orb(size: 420, color: const Color(0xFF2DD4BF), alpha: 0.13),
    ),
    // Layer 5 — vignette
    const _Vignette(strength: 0.2),
    // Your content
    child,
  ]),
);

class _Orb extends StatelessWidget {
  final double size; final Color color; final double alpha;
  const _Orb({required this.size, required this.color, this.alpha = 0.13});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: alpha), Colors.transparent], stops: const [0.0, 0.7]),
      ),
      // Flutter has no CSS filter:blur — use ImageFiltered for true blur,
      // but a wide RadialGradient with transparent outer stop reads equivalent
      // at runtime and is ~20× cheaper than a live blur.
    ),
  );
}

class _Vignette extends StatelessWidget {
  final double strength;
  const _Vignette({this.strength = 0.2});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.center, radius: 0.85,
        colors: [Colors.transparent, Colors.black.withValues(alpha: strength)],
        stops: const [0.3, 1.0],
      ),
    )),
  );
}
```

For the pulsing CTA orb, wrap `_Orb` in an `AnimationController` (`AppMotion` doesn't define this one — use `Duration(seconds: 4)` with `Curves.easeInOut`, `repeat(reverse: true)`, tween opacity `0.8 ↔ 1.2`).

Skip the `_Vignette` and noise layer for compact dashboard routes — they're hero-only.

---

## 3. Spacing & Shapes

### 3.1 `AppSpacing` (Flutter runtime — base unit 4 px)

| Token | Value | Flutter const |
|---|---|---|
| `space.xs` | **4 px** | `AppSpacing.xs` |
| `space.sm` | **8 px** | `AppSpacing.sm` |
| `space.md` | **16 px** | `AppSpacing.md` |
| `space.lg` | **24 px** | `AppSpacing.lg` |
| `space.xl` | **40 px** | `AppSpacing.xl` |
| `space.xxl` | **64 px** | `AppSpacing.xxl` |

### 3.2 Structural dimensions

| Token | Value | Flutter const |
|---|---|---|
| `navRail.width` | **256 px** (expanded) | `AppSpacing.navRailWidth` |
| `navRail.widthCollapsed` | **64 px** (default) | `AppSpacing.navRailWidthCollapsed` |
| `ticketList.width` | 320 px | `AppSpacing.ticketListWidth` |
| `sidebar.width` | 350 px | `AppSpacing.sidebarWidth` |
| `window.headerHeight` | **32 px** | `AppSpacing.windowHeaderHeight` |
| `dashboard.maxWidth` | 800 px | `AppSpacing.maxDashboardWidth` |

> ⚠ The demo video renders a 72 px nav rail for cinematic fit — the **runtime** uses 64 px collapsed / 256 px expanded. When generating UI, use the runtime values.

### 3.3 `AppShapes` — radii

| Token | Value | Flutter const |
|---|---|---|
| `radius.sm` | **6 px** | `AppShapes.radiusSm` |
| `radius.md` | **8 px** | `AppShapes.radiusMd` |
| `radius.lg` | **12 px** | `AppShapes.radiusLg` |
| `radius.xl` | **16 px** | `AppShapes.radiusXl` |
| `radius.round` | **40 px** | `AppShapes.radiusRound` — pill buttons, avatar |

Cards default to `AppShapes.sm` (6 px). Windows and elevated containers use `radius.md` (8 px). Dialogs use `radius.lg` (12 px).

### 3.4 Elevation / shadows

| Token | Value | Use |
|---|---|---|
| `elev.card` | `0 12px 40px rgba(0,0,0,0.5)` | Floating cards / tweaks panel |
| `elev.window` | `0 30px 80px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.03)` | Main window frame (demo) |
| `elev.callout` | `0 8px 24px ${color}50, 0 0 0 1px rgba(0,0,0,0.2)` | Video callouts (accent-tinted) |
| `elev.glow` | `0 0 16px ${accent}` | Active toggle buttons, live indicators |

Flutter runtime Material elevations: cards **0** (flat, border only), FAB **4**, FAB highlighted **8**, all other elevations **0**. The app uses borders + color, not Material shadows.

### 3.5 Window modes (from `core/platform/window_manager.dart`)

| Mode | Size | Routes |
|---|---|---|
| `splash` | 880 × 700 | `/splash` |
| `onboarding` | 400 × 600 | `/onboarding`, `/login` |
| `overlay` | 480 × 240 (min) | `/translation-overlay` |
| `dashboard` | 1140 × 720 | `/account`, `/about`, `/usage`, `/support`, `/admin`, `/billing`, `/history` |
| `settingsOverlay` | 900 × 680 | `/settings-overlay` |
| `subscription` | 1340 × 820 | `/subscription` |

---

## 4. Typography

### 4.1 Fonts

| Stack | Use |
|---|---|
| `'Inter', system-ui, sans-serif` | **All UI text** — default face |
| `'JetBrains Mono', monospace` | Code, timestamps, URLs, IDs, keyboard shortcuts, timeline labels |
| `'Noto Sans JP', 'Noto Sans SC'` | CJK fallback for hero phrases in the demo |

(Flutter app inherits the system default face since no explicit font is set — effectively Segoe UI on Windows. Marketing/web assets use Inter.)

### 4.2 `AppTextStyles` — Flutter runtime scale

Exactly as declared in `app_theme.dart`. Use these when generating Flutter widgets.

| Token | Size / Weight / Color | Flutter const |
|---|---|---|
| `display` | 32 · bold · `text.primary` | `AppTextStyles.display` — mapped to `displayLarge` |
| `title` | 20 · w600 · `text.primary` | `AppTextStyles.title` — mapped to `headlineMedium` |
| `titleLarge/Medium` | 16 · w600 · `text.primary` | (inline in theme) |
| `body` | 14 · regular · `text.primary` · line-height 1.5 | `AppTextStyles.body` — `bodyLarge` |
| `bodyMedium` | 13 · regular · `text.secondary` · line-height 1.5 | (inline in theme) |
| `caption` | 12 · regular · `text.secondary` | `AppTextStyles.caption` — `bodySmall` / `labelMedium` |
| `label` | 12 · w600 · `text.primary` | `AppTextStyles.label` — `labelLarge` |
| `chatMessage` | 14 · regular · `offWhite` · line-height 1.4 | `AppTextStyles.chatMessage` |
| `labelSmall` | 10 · regular · `text.muted` | (inline in theme) |
| `labelTiny` | 9 · regular · `text.disabled` | `AppTextStyles.labelTiny` |

### 4.3 Marketing / video scale

Larger sizes used only in the demo video, splash, and landing-page style heroes:

| Token | Size / Weight / LS | Use |
|---|---|---|
| `display.hero` | 52 px · 800 · −1.3 | Hero tagline ("Any language. One app.") |
| `display.cta` | 44 px · 800 · −1.0 | CTA title ("Omni Bridge") |
| `heading.1` | 36 px · 700 · −0.5 | Hook language phrases |
| `heading.2` | 24 px · 700 · −0.3 | Screen titles |
| `heading.3` | 18 px · 600 · −0.2 | Hero subtitle / CTA subline |
| `micro` | 10 px · 700 · +0.8em · uppercase | Chip labels, nav rail captions |
| `nano` | 8–9 px · 700 · +0.3em · uppercase | Badge text, usage micro-labels |

### 4.4 Type rules

- Headings always use **negative letter-spacing** (tighter feels premium)
- Metadata/labels always **uppercase** + positive tracking (+0.08em to +0.12em)
- Never use italic. Never `text-decoration: underline` — use color/weight
- Numbers in stats/quotas use **JetBrains Mono** for tabular alignment
- One gradient accent per sentence (tagline rule) — highlight words use `gradient.tagline`, never solid colors

---

## 5. Iconography

### 5.1 System

- **Stroke only** — no filled icons except status dots and the logo
- Default stroke width: **2 px** at 24×24 viewBox (`strokeWidth="2"`, `fill="none"`)
- Color inherits `currentColor`; parent sets `color: accentTeal` for active, `text.muted` for idle
- Render sizes: 16 px nav · 20 px inline · 24 px buttons · 32 px+ hero

### 5.2 Required nav rail icon set

Full SVG strings — paste verbatim into `SvgPicture.string()` (requires `flutter_svg`) or any web target. Do **not** substitute Material or Phosphor icons.

Viewbox 24×24 · `stroke="currentColor"` · `stroke-width="2"` · `fill="none"` · `stroke-linecap="round"` · `stroke-linejoin="round"`. Parent sets the color — `accentTeal` for active, `text.muted` for idle.

```xml
<!-- translate -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h7M8 3v2c0 4.4-4 8-4 8M9 11c0 2 3 6 8 6M14 21l5-11 5 11M16 17h6"/></svg>

<!-- history -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>

<!-- chart (usage) -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V10M10 20V4M16 20v-8M22 20H2"/></svg>

<!-- settings (gear) -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>

<!-- user (account) -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>

<!-- mic -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10v2a7 7 0 01-14 0v-2M12 19v3M8 22h8"/></svg>
```

The `billing` nav item is the only Material exception — use `Icons.receipt_long_rounded` there.

### 5.3 Window chrome controls (Windows 11)

ViewBox 10×10 · stroke **1.2** · color `text.secondary` · hitbox 38×32. On hover: minimize/maximize background → `bg.menu`; close background → `#E81123` (Windows system red).

```xml
<!-- minimize -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M1 5H9"/></svg>

<!-- maximize -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.2"><rect x="1" y="1" width="8" height="8" fill="none"/></svg>

<!-- close -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M1 1L9 9M9 1L1 9"/></svg>
```

### 5.4 Icon animations

| Element | Animation | Trigger | Timing |
|---|---|---|---|
| Logo (hero) | Scale-in `easeOutBack`, 0 → 1 | Scene reveal | 450 ms |
| Nav icon (active) | Tint swap + `teal15` bg fill-in | Tab switch | 200 ms |
| Mic bars | `ob-bar` — scaleY 0.35 ↔ 1 | While listening | 700 ms loop · 80 ms stagger |
| Ripple dot | `ob-pulse` — scale 1 → 2.4, opacity 0.7 → 0 | Hotspot highlight | 1400 ms loop · 2 concentric delayed 500 ms |
| Progress ribbon | Gradient fill left → right | Playback | Tied to timeline |
| Status dot (live) | Steady glow `0 0 16px` | While streaming | Static |
| Chip / badge | None at rest · mount fade+slideUp 300 ms | On mount | — |
| Trial countdown timer | None — monospace amber text only | Trial active | Static |

### 5.5 Keyframe library

Keep these names — they're referenced by code.

```css
@keyframes ob-pulse {
  0%   { transform: scale(1);   opacity: 0.7; }
  100% { transform: scale(2.4); opacity: 0;   }
}
@keyframes ob-pulse-hint {
  0%, 100% { transform: scale(1); }
  50%      { transform: scale(1.05); }
}
@keyframes ob-shimmer {
  0%   { background-position: -200px 0; }
  100% { background-position:  200px 0; }
}
@keyframes ob-bar {
  0%, 100% { transform: scaleY(0.35); }
  50%      { transform: scaleY(1);    }
}
@keyframes ob-dot {
  0%, 80%, 100% { opacity: 0.2; }
  40%           { opacity: 1;   }
}
```

### 5.6 Flutter implementation (SVG + animations)

The runtime app is Flutter. The SVGs in §5.2–5.3 and the keyframes in §5.5 must be translated to Flutter idioms. This section gives AI agents everything needed to replicate the icons and their animations in Dart without reinventing values.

#### 5.6.1 Rendering the SVGs in Flutter

**Option A — `flutter_svg` (recommended):** add `flutter_svg: ^2.0.10+1` to `pubspec.yaml`, then use `SvgPicture.string()`:

```dart
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  final String svg;      // full <svg>…</svg> string from §5.2
  final double size;
  final Color color;
  const AppIcon({required this.svg, this.size = 16, required this.color, super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svg,
    width: size, height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
```

Store the raw SVG strings as `const` Dart strings in a single `lib/core/constants/app_icons.dart` file so they're easy to audit and update.

**Option B — Material `Icons.*`:** only permitted for the `billing` tile (`Icons.receipt_long_rounded`) and nowhere else. Treat Material as a last resort.

**Option C — `CustomPainter`:** only when an icon animates its path interior (e.g. drawing the stroke progressively). Overkill for the nav rail set; reserve for one-off effects.

#### 5.6.2 Easing → Flutter `Curves` mapping

Use these exact `Curves` constants. **Never** construct an ad-hoc `Cubic(...)` — if nothing maps, the motion doesn't exist in this design system.

| CSS / JS easing | Flutter `Curves.*` | Notes |
|---|---|---|
| `linear` | `Curves.linear` | Only for progress bars and mechanical meters |
| `easeInCubic` | `Curves.easeInCubic` | All exits |
| `easeOutCubic` | `Curves.easeOutCubic` | Most entrances |
| `easeInOutCubic` | `Curves.easeInOutCubic` | Default for neutral tweens |
| `easeOutBack` | `Curves.easeOutBack` | Logo/hero snap (overshoots ~10%) |
| `easeOutExpo` | `Curves.easeOutExpo` | Camera zoom-outs |
| `easeOutElastic` | `Curves.elasticOut` | Reserved for rare celebrations |

#### 5.6.3 Duration constants

Put these in `lib/core/constants/app_motion.dart` and **reference them everywhere** — no inline `Duration(milliseconds: 300)` scattered across widgets.

```dart
class AppMotion {
  // Core durations
  static const Duration instant    = Duration(milliseconds: 150);  // nav hover / toggle
  static const Duration quick      = Duration(milliseconds: 200);  // tab switch tint
  static const Duration pop        = Duration(milliseconds: 300);  // chip / badge reveal
  static const Duration enter      = Duration(milliseconds: 450);  // content enter, logo hero
  static const Duration exit       = Duration(milliseconds: 350);  // content exit
  static const Duration sceneOut   = Duration(milliseconds: 350);  // scene crossfade out
  static const Duration sceneIn    = Duration(milliseconds: 400);  // scene crossfade in

  // Loop durations
  static const Duration micBar     = Duration(milliseconds: 700);  // ob-bar loop
  static const Duration ripple     = Duration(milliseconds: 1400); // ob-pulse loop
  static const Duration hintPulse  = Duration(milliseconds: 1800); // ob-pulse-hint loop
  static const Duration shimmer    = Duration(milliseconds: 1200); // ob-shimmer loop
  static const Duration dotLoader  = Duration(milliseconds: 1400); // ob-dot loop
  static const Duration cursorBlink= Duration(milliseconds: 500);  // 2 Hz blink
}
```

#### 5.6.4 Animation recipes — one-to-one with §5.5 keyframes

Each keyframe translates to a standard `AnimationController` + `Tween` pattern. Use these recipes **exactly**.

**`ob-pulse` — ripple hotspot (scale 1 → 2.4, opacity 0.7 → 0)**

```dart
class RippleDot extends StatefulWidget {
  final Color color;
  final double size;
  const RippleDot({this.color = const Color(0xFF64FFDA), this.size = 60, super.key});
  @override
  State<RippleDot> createState() => _RippleDotState();
}

class _RippleDotState extends State<RippleDot> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: AppMotion.ripple)..repeat();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size, height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        // Two concentric rings, second offset by 50%
        _ring(offset: 0.0),
        _ring(offset: 0.5),
        // Solid center dot (25% inset)
        Container(
          width: widget.size * 0.5, height: widget.size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: widget.color,
            boxShadow: [BoxShadow(color: widget.color, blurRadius: 20)],
          ),
        ),
      ]),
    );
  }

  Widget _ring({required double offset}) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final t = (_ctrl.value + offset) % 1.0;                 // phase offset
      final scale   = 1.0 + (2.4 - 1.0) * t;                  // 1 → 2.4
      final opacity = 0.7 * (1 - t);                          // 0.7 → 0
      return Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 2),
          )),
        ),
      );
    },
  );
}
```

**`ob-bar` — mic bars (scaleY 0.35 ↔ 1, 80 ms stagger)**

```dart
class MicBars extends StatefulWidget {
  final Color color;
  final bool active;
  const MicBars({required this.color, this.active = true, super.key});
  @override
  State<MicBars> createState() => _MicBarsState();
}

class _MicBarsState extends State<MicBars> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: AppMotion.micBar)..repeat();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 16,
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      return Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            if (!widget.active) return _bar(0.35);
            final phase = (_ctrl.value + i * 0.114) % 1.0;      // 80 ms / 700 ms ≈ 0.114
            final sine  = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0→1→0 per cycle
            final scaleY = 0.35 + (1.0 - 0.35) * sine;
            return _bar(scaleY);
          },
        ),
      );
    })),
  );

  Widget _bar(double scaleY) => Transform.scale(
    scaleY: scaleY, alignment: Alignment.center,
    child: Container(width: 3, height: 16,
      decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2))),
  );
}
```

**`ob-pulse-hint` — gentle breathing (scale 1 → 1.05 → 1)**

```dart
final _hintScale = Tween<double>(begin: 1.0, end: 1.05)
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
// _ctrl.duration = AppMotion.hintPulse; _ctrl.repeat(reverse: true);
```

**`ob-shimmer` — skeleton loader gradient sweep (`-200 → 200`)**

Use a `ShaderMask` with a `LinearGradient` whose stops move via controller value. Duration `AppMotion.shimmer`, curve `Curves.linear`, `controller.repeat()`.

**`ob-dot` — three-dot loader (opacity 0.2 ↔ 1, 40% peak)**

Three dots, each phase-offset by 0.2. At phase 0.4 per dot the opacity is 1; elsewhere 0.2. Same `AnimationController` pattern as `ob-bar` but with opacity instead of scaleY.

**Logo hero reveal — scale 0 → 1, 450 ms, `easeOutBack`**

```dart
late final _logoCtrl = AnimationController(vsync: this, duration: AppMotion.enter);
late final _logoScale = Tween<double>(begin: 0.0, end: 1.0)
    .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
// _logoCtrl.forward() on scene entry.
```

**Nav icon active-state swap (200 ms tint + bg fade)**

Use `AnimatedContainer` with `duration: AppMotion.quick` and `curve: Curves.easeOutCubic`. Animate `color`, `border`, and inner icon `color` together — never separately.

**Chip / badge mount reveal (fade + slide-up 300 ms)**

`TweenAnimationBuilder` on first build. Tween: `offset (0, 8) → (0, 0)` and `opacity 0 → 1`. Duration `AppMotion.pop`, curve `Curves.easeOutCubic`.

**Cursor blink (2 Hz)**

```dart
late final _blinkCtrl = AnimationController(vsync: this, duration: AppMotion.cursorBlink)
  ..repeat(reverse: true);
// Visibility: _blinkCtrl.value > 0.5 (square-wave-style)
```

#### 5.6.5 When runtime animations are wanted vs. disabled

The demo video animates heavily. The **runtime app** is intentionally restrained:

| Element | Demo video | Runtime app |
|---|---|---|
| Mic bars during listening | ✓ | ✓ |
| Trial countdown | — | Static text |
| Ripple hotspot | ✓ | Only in first-run coach marks |
| Shimmer on loaders | ✓ | ✓ (skeleton placeholders) |
| Progress bar | ✓ | ✓ |
| Scene crossfades | ✓ | N/A — use standard route transitions |
| Hero language phrases | ✓ | N/A — marketing only |

If in doubt: static is the default. Animate only the elements above.


### 6.1 Easing library (fixed set)

| Name | Flutter `Curves.*` | Use |
|---|---|---|
| `easeOutCubic` | `Curves.easeOutCubic` | Most entrances — content sliding in |
| `easeInCubic` | `Curves.easeInCubic` | All exits — content sliding out |
| `easeOutBack` | `Curves.easeOutBack` | Logo reveals, hero badges (slight overshoot = "snap") |
| `easeInOutCubic` | `Curves.easeInOutCubic` | Default for any `animate()` tween |
| `easeOutElastic` | `Curves.elasticOut` | Reserved for rare celebration moments |
| `easeOutExpo` | `Curves.easeOutExpo` | Camera zoom-outs, vignette darkening |
| `linear` | `Curves.linear` | Progress bars, mechanical meters only |

**Never invent ad-hoc cubic-bezier curves or `Cubic(...)` constructors.** If none of the above fits, the motion doesn't exist in this design system — think harder or pick the nearest match. See §5.6.2 for the full mapping.

### 6.2 Standard durations

| Context | Duration | Easing |
|---|---|---|
| Nav hover / toggle | 150–200 ms | `easeOutCubic` |
| Chip / badge reveal | 300 ms | `easeOutCubic` |
| Content enter | 400–500 ms | `easeOutCubic` |
| Content exit | 300–350 ms | `easeInCubic` |
| Scene crossfade | 350 ms (out) + 400 ms (in), overlap 200 ms | — |
| Logo hero reveal | 450 ms | `easeOutBack` |
| Camera zoom (hook) | 300 ms | `easeInCubic` |

### 6.3 Principles

1. **Enter fast, exit faster.** Entry ≤ 500 ms, exit ≤ 350 ms.
2. **Typewriter for live text** — characters appear linearly over the segment. Source typed over 1.6 s, translation over 1.8 s starting 0.6 s later.
3. **Source leads, translation follows** — always 400–600 ms lag. Creates the "AI thinking then answering" feel.
4. **Cursor blink** — 2 Hz (`Math.floor(t * 2) % 2`). Only on the focused field.
5. **One hero element per frame.** Logo grows → tagline holds. Text slides → nothing else moves.
6. **Scale + opacity together, never alone.** Scale alone feels cheap; opacity alone feels dead.

---

## 7. Component Library

### 7.0 Global widget library (`lib/core/widgets/`) — use first

Every widget below is **already implemented and imported** from `lib/core/widgets/`. Before writing any inline `Container`, `Row`, or `Scaffold` that matches one of these patterns, use the global widget.

| Widget | Key params | Purpose |
|---|---|---|
| `OmniWindowLayout` | `child` | Wraps a screen in `Scaffold(transparent) + WindowBorder + surface bg`. **Required for every top-level screen.** |
| `OmniHeader` | `title`, `icon`, `onBack?`, `onClose?`, `actions?` | Draggable 32 px title bar with minimize & close. **Replaces all manual `MoveWindow + MinimizeWindowButton + CloseWindowButton` rows.** |
| `OmniCard` | `child`, `baseColor`, `padding`, `margin`, `hasGlow` | Tinted card (`color × 0.05` bg, `color × 0.08` border). Pass `hasGlow: true` for a soft ambient shadow. **Replaces all manual card `Container`s.** |
| `OmniChip` | `label`, `color?`, `fontSize?`, `padding?` | Compact pill label — tags, version strings, engine names. |
| `OmniBadge` | `text`, `color` | Smaller status badge — ticket states, category labels. Heavier weight than `OmniChip`. |
| `OmniTintedButton` | `label`, `color`, `icon?`, `onPressed?`, `isLoading`, `alpha` | Tinted action button with hover scale + loading spinner. **Replaces any custom hover-animated tinted button.** |
| `OmniSearchBar` | `hintText`, `onChanged?`, `controller?`, `focusNode?`, `onSubmitted?` | Search `TextField` wired to the global `InputDecorationTheme`. |
| `OmniProgressBar` | — | Quota / usage progress bars. |
| `OmniDropdown` | — | Dropdown selector following system style. |
| `OmniSegmentedControl` | — | Segmented toggle for 2–4 options. |
| `OmniVersionChip` | _(none)_ | Auto-fetches `PackageInfo` and renders `OMNI BRIDGE vX.X.X`. |
| `OmniBranding` | — | Logo + wordmark lockup. |
| `OmniCopyright` | — | Footer copyright line. |

> **Anti-patterns to avoid:**
> - ❌ `Scaffold(backgroundColor: Colors.transparent) + WindowBorder(...)` → use `OmniWindowLayout`
> - ❌ `Row(children: [Icon, Text, MoveWindow(), MinimizeWindowButton(), CloseWindowButton()])` → use `OmniHeader`
> - ❌ `Container(decoration: BoxDecoration(color: color.withValues(alpha:0.05), borderRadius:..., border:...))` → use `OmniCard`
> - ❌ Any inline tinted pill/chip `Container` → use `OmniChip` or `OmniBadge`
> - ❌ Any custom hover+scale tinted button → use `OmniTintedButton`
> - ❌ Raw `TextField` as search → use `OmniSearchBar`
> - ❌ A top-right update badge in `ShellOverlay` — **removed**. `AppNavigationRail` is the sole update notification entry point. Do not re-add header badges.
> - ❌ Calling `setAlwaysOnTop(true)` on dashboard or blocking screens. Only splash/onboarding and the translation overlay use `alwaysOnTop: true`.

### 7.1 Window chrome (`WinChrome`)


Windows 11-style titlebar (32 px) + body:

```
┌─ 32 px Titlebar (bg.deepest, 1px bottom border card.border) ─────────┐
│  [logo 18px]  Title (12px text.secondary)       [— ☐ ✕] 38×32 each  │
├──────────────────────────────────────────────────────────────────────┤
│  Body — flex, overflow:hidden                                        │
└──────────────────────────────────────────────────────────────────────┘
```

Radius 8 px · outer shadow `elev.window`. **No macOS traffic-light dots** — those break the "this is Windows" reading.

### 7.2 Nav rail (runtime)

- Width **64 px** (collapsed) / **256 px** (expanded) · bg `bg.deepest` · right border `card.border`
- Logo 32 px at top · 20 px gap · 48×48 icon tiles · spacer · avatar 32 px circle at bottom
- Active tile: `accentTeal × 0.15` bg + `accentTeal × 0.30` border + `accentTeal` icon/label
- Idle tile: transparent + `text.muted` icon + `text.muted` label
- Expand/collapse animates window width — mandatory coordination with `window_manager`

### 7.3 Chip / pill

```
padding: 3px 8px · radius: 5 · font: 10px / 700 / uppercase / +0.08em
border: 1px solid ${color}4D  (30% alpha)
bg:    filled ? ${color}      : ${color}1A  (10% alpha)
text:  filled ? #0F0F0F       : ${color}
```

### 7.4 Card

- Bg `card.background` (rgba white 5%) · border 1px `card.border` · radius **6 px** (AppShapes.sm)
- Padding 16 px default. No Material shadow — border only.
- Hover/active: bump border alpha to 15–20%, no bg change.

### 7.5 Button hierarchy (Material theme applied)

| Kind | Bg | Fg | Border | Radius |
|---|---|---|---|---|
| Elevated (primary) | `teal × 0.1` | `accentTeal` | — | 8 |
| Outlined | transparent | `accentTeal` | `teal × 0.3` | 8 |
| Text | transparent | `accentTeal` | — | — |
| FAB | `accentCyan` | `bg.deepest` | — | 8 |

Padding `16 × 12` · label style `AppTextStyles.label` (12 px w600).

### 7.6 Input field

Filled, dense:

- Bg `white × 0.05` · text-size 13 · hint color `text.faint`
- Border `card.border` at rest · `accentTeal` 1.5 px when focused
- Radius 6 (AppShapes.sm) · padding `10 × 8`

### 7.7 Switch / slider

- Thumb: `accentTeal` when selected, grey when off
- Track (selected): `accentTeal × 0.5`
- Track (off): `white × 0.24`
- Slider active track + thumb: `accentTeal` · inactive: `text.faint`

### 7.8 Callout (demo video annotation)

- Bg: **solid accent color** (not dark) · text `#0F0F0F`
- Padding `10 × 14` · radius 10 · width 220–250 px
- Shadow `elev.callout` (accent-tinted)
- 12 × 12 rotated square tip, same color, `-6 px` outside the box
- Always pointed at a specific element — never floats unanchored
- Max on-screen 2.5 s

### 7.9 Ripple hotspot

- 2 concentric ripple rings + filled dot · animation `ob-pulse`, delays `0s` / `0.5s`
- Center dot inset 25%, `box-shadow: 0 0 20px ${color}`
- Size 50–80 px · `zIndex: 30`

### 7.10 Mic bars

- 5 × (3 px wide, 16 px tall) · gap 3 · radius 2
- Animation `ob-bar 0.7s infinite` · stagger `i * 0.08s`
- Color: teal for translation stream, indigo (`semantic.asr`) for ASR stream

### 7.11 Progress bar (`OmniProgressBar`)

- Height 5 · radius 3 · track `card.background`
- Fill: `accentTeal` at rest, shifts to `amber` over 70%, `accentRed` at 100%
- No shimmer on runtime progress — shimmer is demo-only

### 7.12 CaptionPair (THE defining UI element)

The dual-label source / translation card is the core of the translate screen. Every other UI pattern supports this one.

```
┌─ Card · padding 16 · radius 12 ──────────────────────────────────────┐
│  Live bg: linear-gradient(135°, asrIndigo10, translationTeal10)       │
│  Live border: teal40 (else card.border)                               │
│  Live: shows LIVE chip top-right (teal dot + label 9px/700)           │
│                                                                       │
│  ● SOURCE · ES          ← 9px / 700 / +0.12em · asrIndigoLight        │
│  Hola, bienvenidos…     ← 19px / 500 / -0.2 · text.secondary          │
│                         (+ blinking cursor in asrIndigoLight if live) │
│                                                                       │
│  ● TRANSLATION · EN     ← 9px / 700 / +0.12em · translationTeal       │
│  Hello, welcome…        ← 22px / 700 / -0.3 · #FFFFFF                 │
│                         (+ blinking cursor in accentTeal if live)     │
└───────────────────────────────────────────────────────────────────────┘
```

**Rules:**
- **Translation text is always larger and bolder than source text** (22 vs 19, 700 vs 500) — the translation is the product.
- Each line has a tiny colored dot before its label (6 px, matching label color).
- `faded` prop drops opacity to 0.4 for older entries; top-most entries fade first (reverse-chronological stack flows bottom → top).
- Gap between source and translation blocks: 10 px. Never stack them horizontally.

### 7.13 FormField

```
Label:  10px / 700 / uppercase / +0.12em
        color: teal when focused, text.faint at rest
        transition color 150ms
        margin-bottom 6

Field:  height 42 · bg bg.elevated · radius 8
        border 1.5px  — card.border at rest, accentTeal when focused
        boxShadow: focused → 0 0 0 3px ${teal}20 (focus ring)
        padding 0 14 · font 14 / Inter · text.primary
        transition all 150ms

Cursor: 1.5 × 18 px · teal · margin-left 1
        visibility via cursorBlink animation (§5.6.4)
```

Placeholder uses `text.faint`. The focus ring (3 px glow) is mandatory — this is the accessibility focus indicator for the whole app.

### 7.14 LangPicker

Horizontal pill showing source → target with country flags:

```
padding: 5 × 12 · radius 7
bg: teal10 · border 1px teal30
[flag 14] Source 11/700 #fff  →  [flag 14] Target 11/700 #fff
arrow: 12×10 svg · stroke teal 1.5 · round cap
gap: 10 between all inline elements
```

### 7.15 StatusDot

Footer status indicator:

```
dot: 6×6 · radius 3 · bg ${color} · boxShadow 0 0 6px ${color}
label: 10px / 700 / +0.4em · color ${color}
font: JetBrains Mono
gap: 5 between dot and label
```

Used in the translate screen footer for model/connection status (LLAMA 3.1 8B, RIVA ASR, WS CONNECTED).

### 7.16 REC indicator

Live recording marker (translate screen header):

```
dot: 8×8 · radius 4 · bg accentRed · boxShadow 0 0 8px accentRed
label: 11px / 700 / +1em / uppercase · accentRed
gap: 8
```

Appears only when `isRunning === true`. No pulse animation on the dot — the glow is enough.

### 7.17 SearchBar

```
width: 220 · height: 32 · radius 7
bg: bg.elevated · border 1px card.border
padding: 0 10 · gap 8
[13×13 search svg · stroke currentColor] placeholder 12px text.faint
```

Placeholder: "Search captions..." (ellipsis, not three dots).

### 7.18 TierBadge

Plan indicator with lightning-bolt icon (a step up from a plain Chip):

```
padding: 5 × 10 · radius 7
bg: teal15 · border 1px teal40
[12×12 lightning svg · fill teal] TIER 11px / 800 / +0.8em · teal
gap: 6
```

Lightning SVG: `<path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" fill="currentColor"/>` on a 24×24 viewBox.

### 7.19 StatCell

Mini stat tile used in the usage strip:

```
padding: 8 × 12 · radius 7 · minWidth 92
bg: card.background · border 1px card.border
Row 1:  [icon 10 ${color}] LABEL 9px / 700 / +0.6em · text.disabled
Row 2:  Value 16px / 800 / -0.3 · #fff
```

### 7.20 EngineCard

Usage dashboard tile — one per engine:

```
padding: 14 · radius 10
bg: selected → ${color}10, else card.background
border: selected → ${color}50, else card.border
Active pill (top-right, offset -6):
  padding 2×6 · radius 4 · bg ${color}
  text 8px / 800 / +0.5em · #0F0F0F · "ACTIVE"

Row 1: [6×6 dot · ${color} · glow 6px] EngineName 12/700 · #fff
Row 2: Tokens 20 / 800 / -0.5 · JetBrains Mono · #fff   tokens 10 · text.faint
Bar:   4 tall · track rgba(white,0.06) · radius 2
       fill: linear-gradient 90°, ${color}80 → ${color} · transition 1.5s ease
Trend: 10px / 600 · emerald if ≥0 else accentRed · "↑ 12.4% vs last week"
```

`color` is `UsageColors.asrAccent` (`#818CF8`) for ASR engines, `UsageColors.translationAccent` (`#2DD4BF`) for translation engines, `UsageColors.disabledAccent` (`#64748B`) for out-of-plan engines.

### 7.21 SectionHeader

Inline divider with icon + uppercase label:

```
[icon 12] LABEL 11 / 800 / +0.08em · ${color}CC    ─── (1px divider, card.border)
gap: 10 between icon, label, and divider
```

### 7.22 Primary gradient CTA button (Sign-in style)

```
height 44 · radius 10 · no border
bg: linear-gradient(135°, accentTeal → translationTeal)
text: 14 / 800 / +0.4em · #0F0F0F (near-black, for contrast on teal)
shadow: 0 8px 20px ${accentTeal}30

Busy state (during async action):
  bg: linear-gradient(90°, accentTeal ${pct}%, ${accentTeal}30 ${pct}%)
  label: "Signing in…" (ellipsis), no spinner — the bar IS the spinner
```

Reserve this variant for **one** primary action per screen (Sign In, Upgrade, Resume). Everything else uses §7.5 button hierarchy.

### 7.23 Dialog / confirmation (Material `AlertDialog`)

Used for destructive confirmations (Cancel Subscription, Reset, Logout, Clear History).

```
bg: bg.elevated (#1E1E1E)       ← NOT bg.deep — dialogs lift off
shape: RoundedRectangle radius 12 (AppShapes.lg)
title: 15 · w600 · text.primary
content: 12 · text.muted · line-height 1.5
actions (TextButton):
  cancel / dismiss:  text.secondary (white54)
  confirm (destructive): accentRed
  confirm (non-destructive): accentTeal
```

Do NOT use a shadow — the elevated bg + the dimmed scrim (Material default 54% black) is enough separation. Two actions max.

### 7.24 Toast / SnackBar

Flutter Material `SnackBar` with `behavior: SnackBarBehavior.floating`. Colors are semantic.

| Variant | `backgroundColor` | Use |
|---|---|---|
| Success | `Colors.teal` (≈ `#009688`) | Subscription activated, settings saved |
| Info | `Colors.blueAccent` | Neutral status ("Copied to clipboard") |
| Warning | `Colors.orange.shade700` | Pending / scheduled actions ("Cancellation scheduled") |
| Error | `Colors.redAccent` | Failures, quota exceeded |

Rules:
- Single line preferred. Two lines max. Never wraps to three.
- Always floating — never stuck-to-bottom edge style.
- Duration: short-lived (3–4 s) unless it contains a retry action. Don't auto-dismiss errors that require user action.
- Plain text only — no emojis, no markdown.

### 7.25 Empty, loading, and error states

Every list/panel needs three states. Never show a blank area.

**Empty state (no data yet):**
```
Icon (32 · text.disabled · monochrome)
Heading (13 · w600 · text.secondary)
Subheading (11 · text.faint · line-height 1.5)
Optional primary action button (§7.5 outlined variant)
Centered in container · gap 12 between elements
```

Example copy: "No transcriptions yet." / "Start the live translator to see captions here."

**Loading state (shimmer skeleton):**
- Use the `ob-shimmer` keyframe (§5.5) on placeholder blocks shaped like the real content.
- Skeleton color: `card.background`. Shimmer highlight: `rgba(255,255,255,0.08)`.
- Duration `AppMotion.shimmer` (1200 ms), `Curves.linear`, infinite.
- Never use a spinner where you could show a shape — skeletons reduce perceived latency by ~40%.

**Inline loading (spinner fallback):**
- Flutter `CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accentTeal))`.
- Size 16–20 px inline, 24 px for button-busy states. Never larger than 40 px.

**Error state (failed to load):**
```
Icon (32 · accentRed · outlined)
Heading (13 · w600 · accentRed)
Subheading (11 · text.muted · line-height 1.5)
[Retry] button (§7.5 outlined, small)
```

Heading should name the failure without jargon ("Can't reach server" > "WebSocket 503"). Subheading can be technical if it helps the user ("Check your internet, then retry.").

---

## 8. Sound Design

Web Audio API procedural synthesis — no sample files. Used in the demo video only; the runtime app plays no sounds.

| Cue | Shape | When |
|---|---|---|
| `pop` | Sine blip 440–880 Hz, 80 ms decay | Phrase flying in, chip reveal |
| `whoosh` | Filtered noise sweep, 220 ms, up or down | Scene transitions |
| `stinger` | Sub-bass thump + sine chord, 400 ms | Logo reveal |
| `thump` | Low sine 60–90 Hz, 150 ms | Scene anchor beat |
| `sparkle` | Arpeggiated sine triad, 300 ms | Translation output appears |
| `click` | Short square 1 kHz, 30 ms | Button press |
| `ping` | Rising sine 800 → 1200 Hz, 120 ms | Success / accept |
| `chime` | Bell-like additive tone, 1.2 s | CTA reveal |
| `mic` (loop) | Low-gain drone + noise | During live-translate scenes |

Rules:

- **Default muted.** A hint pill ("← Click to enable sound") nudges the user. Never autoplay.
- ≤ 1 prominent cue per 500 ms. No chord-stacking.
- Master gain 0.55. Cue gains 0.14–0.30.
- Reset fired-cues cache on every loop back to t=0 so sounds replay.

---

## 9. Video / Demo Export Spec

**This design system is built around a 27-second looping product video.** Treat this as the canonical structure when generating marketing assets.

### 9.1 Canvas

- **Preview:** 1200 × 750 @ 60 fps
- **Stage base:** `canvas.bold` (`#0a0a0a`) or `canvas.cinematic` (`#050508`) — see §2.9.1
- **Every scene layers the full background recipe from §2.9.2** — base fill, radial gradient, two orbs, vignette. Never render a scene on flat `canvas.bold` alone.
- **Progress ribbon:** 3 px tall, top of stage, `gradient.progress` fill, left → right

### 9.2 Scene timeline — 27 s total, loops

| # | Range | Scene | Purpose | Background |
|---|---|---|---|---|
| 0 | 0.0 – 3.0 s | **Hook** | 10 language phrases fly in, collapse to center, logo snap + tagline | Full §2.9.2 recipe · vignette ramps 0.2 → 0.9 during collapse |
| 1 | 3.0 – 6.5 s | **Sign In** | Email + password typewriter, Google Sign-In button | `WinChrome` over stage base — orbs visible through window shadow |
| 2 | 6.5 – 12.0 s | **Translate ES→EN** | Live Spanish → English, two sentences | `WinChrome` — stage base shows around window |
| 3 | 12.0 – 16.0 s | **Multi-language** | Japanese then Hindi → English, 20+ languages claim | same as Scene 2 |
| 4 | 16.0 – 19.8 s | **History** | Scrolling captions with row highlight cycling | same as Scene 2 |
| 5 | 19.8 – 23.5 s | **Usage** | Quota ring 0 → 24%, stat bars | same as Scene 2 |
| 6 | 23.5 – 27.0 s | **CTA** | Logo scale-in, three feature chips, GitHub URL in mono | §2.9.3 pulsing teal orb on `bg.deep → bg.deepest` radial |

### 9.3 Scene template

Every scene has:
1. **Entry** — first 0.4 s · opacity 0 → 1 · `easeOutCubic`
2. **Exit** — last 0.35 s · opacity 1 → 0 · `easeInCubic`
3. **Scene marker** — bottom-left · JetBrains Mono chip: `## / 06 · SCENE NAME` · 10 px · teal on `rgba(10,10,10,0.8)` · `teal40` border · `backdrop-filter: blur(8px)`
4. **1–2 callouts max** — each 1.5–2.5 s on-screen, never overlapping

### 9.4 Hook scene phrase set (locked — don't swap)

| Text | Lang | Position | Color | Delay |
|---|---|---|---|---|
| Bonjour | FR | 180, 130 | `#6366F1` | 0.10 |
| こんにちは | JA | 780, 160 | `#EC4899` | 0.20 |
| 你好 | ZH | 480, 100 | `#F59E0B` | 0.28 |
| Hola | ES | 130, 360 | `#10B981` | 0.36 |
| Guten Tag | DE | 820, 380 | `#3B82F6` | 0.44 |
| नमस्ते | HI | 540, 480 | `#8B5CF6` | 0.54 |
| Привет | RU | 220, 560 | `#EF4444` | 0.62 |
| مرحبا | AR | 900, 560 | `#FFAB40` | 0.70 |
| Olá | PT | 420, 280 | `#2DD4BF` | 0.80 |
| 안녕하세요 | KO | 740, 260 | `#818CF8` | 0.88 |

Each phrase: 36 px · 700 · `textShadow: 0 0 24px ${color}66` · enter `easeOutBack` scale + `easeOutCubic` translateY. At 1.7 s all phrases collapse toward (600, 375) with `easeInCubic`, scale → 0, opacity → 0. Camera zooms 1.0 → 1.15. At 2.0 s the logo scales in from 0 (`easeOutBack`, 450 ms) followed 250 ms later by tagline slide-up 14 → 0 px.

### 9.5 CTA scene chips (locked order)

`FREE ON WINDOWS` (teal) · `20+ LANGUAGES` (`usage.asrAccent` / lighter indigo) · `OFFLINE MODE` (amber).

### 9.6 GitHub URL presentation

JetBrains Mono · 14 px · teal · padding `10 × 20` · bg `teal × 0.1` · border `teal × 0.4` · radius 10. Never shorten, never add `https://`.

### 9.7 Real product facts (use these exact numbers — no inflation)

| Claim | Value |
|---|---|
| Supported source languages | **20+** |
| Translation engines available | **8** (Google, Google API, MyMemory, Riva NMT, Llama 3.1, Deepgram, Riva ASR, online-ASR) |
| Whisper local model sizes | **5** (tiny, base, small, medium, large) |
| Transcription models | **5+** (Google Online, Riva ASR, Whisper local, Deepgram, Parakeet/Canary via Riva) |
| Desktop target | Windows 10 / 11 |
| Free tier | Yes — 40 K chars/day, 750 K chars/month |
| Offline mode | Yes (Whisper + Riva local models) |

### 9.8 Export targets

| Format | Size | Frame rate | Use |
|---|---|---|---|
| MP4 (H.264) | 1920 × 1080 | 60 fps | LinkedIn, YouTube, Twitter |
| MP4 (H.264) | 1080 × 1080 | 30 fps | Instagram feed, LinkedIn square |
| GIF | 600 × 375 | 20 fps · ≤ 8 MB | Email / chat fallback |
| WebM (VP9) | 1200 × 750 | 60 fps | Web embed |
| Poster PNG | 1920 × 1080 | — | Thumbnail — capture at **t=2.2 s** (logo reveal frame) |

---

## 10. Writing Rules

- **Verbs, not adjectives.** "Translates as you speak" > "Incredible real-time translation power"
- **Numbers, not claims.** "20+ languages", "8 engines", "every 5 seconds" > "many" / "fast" / "soon"
- **Show the UI, don't describe it.** Callouts label what the frame already shows.
- **One idea per frame.** Callouts ≤ 8 words; split if it needs two lines.
- Title case for screen names (History, Usage Analytics); sentence case elsewhere.
- Oxford comma: yes. Em-dashes: yes. **Emojis in UI: never** — only country flags in language selectors.

---

## 11. Implementation Notes

- **Runtime source of truth:** `lib/core/theme/app_theme.dart`. Every color/spacing/radius/text style this file lists is declared there as a `const`. If a value diverges, **app_theme.dart wins** and this file needs updating.
- **Demo source:** `C:\Users\marsh\.claude\projects\f--AI-Models-Projects-omni-bridge\design_export\` — the HTML/JSX bundle the video exports from.
- **When porting a demo component into Flutter:** preserve color, typography, easing, and duration — the demo was built from the real theme.
- **When generating new marketing assets:** read this file first, then reference `scenes.jsx` for canonical motion examples.
- **Never import from design_export into Flutter.** It's a standalone bundle for video/marketing only.

---

---

## 12. Screen Templates

Layout skeletons for the four screens featured in the demo. Every screen sits **inside** a `WinChrome` (§7.1) and most have a `NavRail` (§7.2) on the left.

### 12.1 Login screen

```
┌─ WinChrome ───────────────────────────────────────────────────────────┐
│ linear-gradient(135°, bg.deep 0%, #0a1520 60%, bg.deep 100%)          │
│ ambient blob: 500×500 · translationTeal × 0.15 · blur 40 · top-left   │
│ ambient blob: 500×500 · asrIndigo × 0.21 · blur 40 · bottom-right     │
│                                                                       │
│                    ┌─ Glass card (440 wide) ─────────────┐            │
│                    │  padding 36 · radius 14              │            │
│                    │  bg rgba(20,20,20,0.7) · blur 20px   │            │
│                    │  shadow 0 20px 60px rgba(0,0,0,0.5)  │            │
│                    │                                       │            │
│                    │  [Logo 52]  Omni Bridge (22/800)     │            │
│                    │            LIVE AI TRANSLATOR         │            │
│                    │            (10/700/+1.4em · teal)     │            │
│                    │                                       │            │
│                    │  Sign in to sync settings…            │            │
│                    │  (13 · text.muted · line-height 1.5) │            │
│                    │                                       │            │
│                    │  [ FormField — EMAIL    ]             │            │
│                    │  [ FormField — PASSWORD ]             │            │
│                    │                                       │            │
│                    │  [ Primary gradient CTA: Sign In ]    │            │
│                    │                                       │            │
│                    │  ──────── OR ────────                │            │
│                    │                                       │            │
│                    │  [ GoogleG ]  Continue with Google    │            │
│                    │  (bg.elevated · card.border · 42 h)   │            │
│                    │                                       │            │
│                    │           Continue as Guest →         │            │
│                    │           (11 · text.faint · centered)│            │
│                    └───────────────────────────────────────┘            │
└───────────────────────────────────────────────────────────────────────┘
```

Window mode: `onboarding` (400 × 600). No NavRail on this screen.

### 12.2 Translate / Captions screen

```
┌─ WinChrome ──────────────────────────────────────────────────────────────┐
│ bg: linear-gradient(180°, bg.medium 0%, bg.deepest 100%)                 │
│ ┌─ NavRail ─┐  ┌─ Header (44 h · border-bottom card.border · pad 0 20) ─┐│
│ │   Logo    │  │ [Chip PRO]  [Quota 2.4K/25K · mono teal]  [LangPicker] ││
│ │           │  │                    spacer  [● REC]  |  [MicBars] LIVE  ││
│ │  ▪ Live   │  └──────────────────────────────────────────────────────┘ │
│ │    Hist   │  ┌─ Captions area · padding 24 28 · gap 14 · bottom-align ┐│
│ │    Usage  │  │                                                         ││
│ │    Sett   │  │  (older CaptionPair — faded 0.4)                        ││
│ │    Acct   │  │                                                         ││
│ │           │  │  (previous CaptionPair — full opacity)                  ││
│ │    [M]    │  │                                                         ││
│ │           │  │  ┌─ LIVE CaptionPair — see §7.12 ─────────────────────┐ ││
│ │           │  │  │  gradient bg · teal40 border · LIVE chip            │ ││
│ │           │  │  │  ● SOURCE · ES                                      │ ││
│ │           │  │  │  Hola, bienvenidos…  |                              │ ││
│ │           │  │  │  ● TRANSLATION · EN                                 │ ││
│ │           │  │  │  Hello, welcome…  |                                 │ ││
│ │           │  │  └─────────────────────────────────────────────────────┘ ││
│ │           │  └─────────────────────────────────────────────────────────┘│
│ │           │  ┌─ Footer (32 h · bg.deepest · border-top · JetBrains) ──┐│
│ │           │  │ [StatusDot LLAMA 3.1 8B]  [RIVA ASR]  [WS CONNECTED]   ││
│ │           │  │                                   spacer   96ms latency ││
│ │           │  └────────────────────────────────────────────────────────┘│
│ └───────────┘                                                             │
└──────────────────────────────────────────────────────────────────────────┘
```

Window mode: `dashboard` (1140 × 720) for main view · `overlay` (480 × 240 min) for borderless caption-only mode.

### 12.3 History screen (two-column)

```
┌─ WinChrome ──────────────────────────────────────────────────────────────┐
│ bg: linear-gradient(180°, bg.medium → bg.deepest)                        │
│ ┌─ NavRail (history active) ─┐                                           │
│ │  ┌─ Header (56 h · border-bottom · pad 0 24 · gap 14) ──────────────┐  │
│ │  │ [history svg 18 teal]  Caption History (16/700)  [Chip PRO·30D]  │  │
│ │  │                                      spacer              [Search] │  │
│ │  └────────────────────────────────────────────────────────────────┘  │
│ │  ┌─ Two-column panel (1px vertical divider between) ────────────────┐  │
│ │  │  📝  Live Transcripts          |  🔁  5-Second Re-translations   │  │
│ │  │  Unlimited history             |  Cleaner, context-aware output  │  │
│ │  │  ──────                        |  ──────                         │  │
│ │  │                                 |                                │  │
│ │  │  Entry card (radius 8):         |  Entry card (radius 8):        │  │
│ │  │   [Chip lang ES→EN]    2:04 PM  |   [Chip REFINED amber]  2:04   │  │
│ │  │   src (12 · text.muted)         |   src (12 · text.muted)        │  │
│ │  │   target (13 · #fff · 500)      |   target (13 · #fff · 500)     │  │
│ │  │                                 |                                │  │
│ │  │  Highlighted entry:             |  (same shape)                  │  │
│ │  │   bg teal15 · border teal60     |                                │  │
│ │  │   translateX(4px) + shadow      |                                │  │
│ │  │   transition 300ms all          |                                │  │
│ │  └─────────────────────────────────────────────────────────────────┘  │
│ └───────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

Column headers use emoji — two of the very few UI emojis allowed (see §10). Entry card padding 12 · gap 8 between cards · scroll overflow via `.ob-scroll` (§styles.css).

### 12.4 Usage Analytics screen

```
┌─ WinChrome ──────────────────────────────────────────────────────────────┐
│ bg: linear-gradient(180°, bg.medium → bg.deepest) · overflow auto        │
│ ┌─ NavRail (usage active) ──┐                                            │
│ │  Padding 24 × 28                                                       │
│ │                                                                        │
│ │  Usage Analytics (22/800/-0.5)  [Chip PRO]          updated 3s ago     │
│ │                                                      (11 · text.faint) │
│ │                                                                        │
│ │  ┌─ Stats strip — padding 18 20 14 · radius 12 · gradient teal15 ─┐   │
│ │  │ Left accent bar: 4 wide · linear-gradient teal → teal30         │   │
│ │  │                                                                 │   │
│ │  │ [TierBadge PRO]  MONTHLY QUOTA          60K / 250K   resets 14d │   │
│ │  │                  ━━━━━━━━━━━━━━━ 24% (gradient teal · glow)    │   │
│ │  │                  [StatCell TODAY 3.2K] [MONTH 60K] [LIFETIME ∞] │   │
│ │  └────────────────────────────────────────────────────────────────┘   │
│ │                                                                        │
│ │  🎤  ASR ENGINES  ──────────────────                                   │
│ │  ┌──────────────┬──────────────┬──────────────┐                       │
│ │  │ EngineCard   │ EngineCard   │ EngineCard   │  grid cols 3, gap 10 │
│ │  │ Riva (sel)   │ Whisper      │ Google       │                       │
│ │  └──────────────┴──────────────┴──────────────┘                       │
│ │                                                                        │
│ │  🌐  TRANSLATION ENGINES  ──────                                       │
│ │  ┌──────────────┬──────────────┬──────────────┐                       │
│ │  │ Llama (sel)  │ Google Trans │ Riva NMT     │                       │
│ │  └──────────────┴──────────────┴──────────────┘                       │
│ └───────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

Window mode: `dashboard` (1140 × 720). The stats strip is always full-width. Engine cards are fixed 3-column grid — if more engines exist, they wrap to additional rows, never overflow horizontally.

### 12.5 Other screens (not in demo — defer to feature docs)

| Route | Source of truth |
|---|---|
| `/subscription` | `docs/04_features/16_monetization_plan.md` |
| `/billing` | `docs/04_features/25_billing_management.md` |
| `/settings-overlay` | `lib/features/settings/presentation/` + screenshots |
| `/admin` | `docs/04_features/15_admin_features.md` |
| `/support` | `docs/04_features/18_support_feature_guide.md` |
| `/about` | `lib/features/about/presentation/screens/about_screen.dart` |

When generating UI for these, apply the same palette/typography/motion rules — they're not re-specified here to avoid drift from the feature docs.

---

_Mirrors `AppColors` + `AppSpacing` + `AppShapes` + `AppTextStyles` + `UsageColors` in `lib/core/theme/app_theme.dart`. Last calibrated against theme on 2026-04-24._
