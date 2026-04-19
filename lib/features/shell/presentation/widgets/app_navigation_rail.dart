import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/widgets/omni_branding.dart';
import 'package:omni_bridge/core/widgets/omni_chip.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_bloc.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_event.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_state.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  AppNavigationRail — collapsible dashboard sidebar
// ═══════════════════════════════════════════════════════════════════════════════

/// Duration & curve used consistently across all rail animations.
const _kAnimDuration = Duration(milliseconds: 250);
const _kAnimCurve = Curves.easeInOutCubic;

class AppNavigationRail extends StatelessWidget {
  final String currentRoute;

  /// Index of the active settings sub-tab (0 = Translation, 1 = Display, 2 = I/O).
  final int? settingsTabIndex;

  /// Callback when a settings sub-tab is tapped while already on Settings.
  final ValueChanged<int>? onSettingsTabChanged;

  const AppNavigationRail({
    super.key,
    required this.currentRoute,
    this.settingsTabIndex,
    this.onSettingsTabChanged,
  });

  static const _settingsSubTabs = [
    (icon: Icons.translate_rounded, label: 'Translation'),
    (icon: Icons.palette_outlined, label: 'Display'),
    (icon: Icons.headphones_rounded, label: 'Input & Output'),
  ];

  static const _supportSubTabs = [
    (icon: Icons.forum_rounded, label: 'All Tickets'),
    (icon: Icons.bolt_rounded, label: 'Active'),
    (icon: Icons.hourglass_empty_rounded, label: 'Pending'),
    (icon: Icons.check_circle_rounded, label: 'Resolved'),
    (icon: Icons.inventory_2_rounded, label: 'Archive'),
  ];

  @override
  Widget build(BuildContext context) {
    final isOnSettings = currentRoute == AppRouter.settingsOverlay;

    return BlocBuilder<AppShellBloc, AppShellState>(
      buildWhen: (prev, curr) =>
          prev.isSidebarExpanded != curr.isSidebarExpanded,
      builder: (context, state) {
        final isExpanded = state.isSidebarExpanded;

        return AnimatedContainer(
          duration: _kAnimDuration,
          curve: _kAnimCurve,
          width: isExpanded
              ? AppSpacing.navRailWidth
              : AppSpacing.navRailWidthCollapsed,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppColors.bgDeepest,
            border: Border(right: BorderSide(color: AppColors.cardBorder)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: isExpanded
                  ? AppSpacing.navRailWidth
                  : AppSpacing.navRailWidthCollapsed,
              child: Column(
                children: [
                  // ── Branding ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isExpanded ? AppSpacing.md : AppSpacing.sm,
                      AppSpacing.lg,
                      isExpanded ? AppSpacing.md : AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: isExpanded
                        ? OmniBranding(
                            subtitle: 'Dashboard',
                            fallbackIcon: Icons.dashboard_rounded,
                            logoSize: 36,
                            subtitleAsChip: true,
                            subtitleChipColor: AppColors.accentCyan,
                          )
                        : Center(
                            child: Image.asset(
                              'assets/app/icons/icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.cyan(0.1),
                                  borderRadius: AppShapes.sm,
                                ),
                                child: Icon(
                                  Icons.dashboard_rounded,
                                  color: AppColors.accentCyan,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Section label ──
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: AppSpacing.xs,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _sectionLabel('NAVIGATION'),
                      ),
                    ),

                  // ── Main nav ──
                  Expanded(
                    child: _buildNavLinks(context, isOnSettings, isExpanded),
                  ),
                  _divider(),
                  const SizedBox(height: AppSpacing.xs),

                  // ── Toggle Button ──
                  _NavTile(
                    icon: isExpanded
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                    label: 'Collapse',
                    isExpanded: isExpanded,
                    tooltip: isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
                    onTap: () {
                      context.read<AppShellBloc>().add(
                        const AppShellToggleSidebarEvent(),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xs),
                  _buildUserProfile(context, isExpanded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.white(0.05),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelTiny.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.textDisabled.withValues(alpha: 0.5),
      ),
    );
  }

  // ── Nav links ─────────────────────────────────────────────────────────────

  Widget _buildNavLinks(
    BuildContext context,
    bool isOnSettings,
    bool sidebarExpanded,
  ) {
    return BlocBuilder<AppShellBloc, AppShellState>(
      buildWhen: (prev, curr) =>
          prev.isSettingsExpanded != curr.isSettingsExpanded ||
          prev.isSupportExpanded != curr.isSupportExpanded ||
          prev.isAdmin != curr.isAdmin,
      builder: (context, state) {
        // Sub-menus only show when the sidebar itself is expanded.
        final isSettingsExpanded = state.isSettingsExpanded && sidebarExpanded;
        final isSupportExpanded = state.isSupportExpanded && sidebarExpanded;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Settings ──
              _NavTile(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isActive: isOnSettings,
                isExpanded: sidebarExpanded,
                tooltip: 'Settings',
                trailing: sidebarExpanded
                    ? _chevron(isSettingsExpanded, isOnSettings)
                    : null,
                onTap: () {
                  if (!sidebarExpanded) {
                    context.read<AppShellBloc>().add(
                      const AppShellToggleSidebarEvent(isExpanded: true),
                    );
                  }
                  context.read<AppShellBloc>().add(
                    const AppShellToggleSettingsExpanded(),
                  );
                },
              ),

              _ExpandableSubMenu(
                isExpanded: isSettingsExpanded,
                children: List.generate(_settingsSubTabs.length, (i) {
                  final tab = _settingsSubTabs[i];
                  return _NavSubTile(
                    icon: tab.icon,
                    label: tab.label,
                    isActive: isOnSettings && settingsTabIndex == i,
                    onTap: () {
                      if (isOnSettings) {
                        onSettingsTabChanged?.call(i);
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRouter.settingsOverlay,
                          arguments: i,
                        );
                      }
                    },
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.xs),

              // ── Subscription ──
              _NavTile(
                icon: Icons.workspace_premium_rounded,
                label: 'Subscription',
                isActive: currentRoute == AppRouter.subscription,
                isExpanded: sidebarExpanded,
                tooltip: 'Subscription',
                onTap: () => _navigate(context, AppRouter.subscription),
              ),

              // ── Billing ──
              _NavTile(
                icon: Icons.receipt_long_rounded,
                label: 'Billing',
                isActive: currentRoute == AppRouter.billing,
                isExpanded: sidebarExpanded,
                tooltip: 'Billing',
                onTap: () => _navigate(context, AppRouter.billing),
              ),

              // ── Usage ──
              _NavTile(
                icon: Icons.insights_rounded,
                label: 'Usage Analytics',
                isActive: currentRoute == AppRouter.usage,
                isExpanded: sidebarExpanded,
                tooltip: 'Usage Analytics',
                onTap: () => _navigate(context, AppRouter.usage),
              ),

              // ── Account ──
              _NavTile(
                icon: Icons.manage_accounts_rounded,
                label: 'Account',
                isActive: currentRoute == AppRouter.account,
                isExpanded: sidebarExpanded,
                tooltip: 'Account',
                onTap: () => _navigate(context, AppRouter.account),
              ),

              // ── Support ──
              _NavTile(
                icon: Icons.forum_rounded,
                label: 'Support',
                isActive: currentRoute == AppRouter.support,
                isExpanded: sidebarExpanded,
                tooltip: 'Support',
                trailing: sidebarExpanded
                    ? _chevron(
                        isSupportExpanded,
                        currentRoute == AppRouter.support,
                      )
                    : null,
                onTap: () {
                  if (!sidebarExpanded) {
                    context.read<AppShellBloc>().add(
                      const AppShellToggleSidebarEvent(isExpanded: true),
                    );
                  }
                  context.read<AppShellBloc>().add(
                    const AppShellToggleSupportExpanded(),
                  );
                },
              ),

              _ExpandableSubMenu(
                isExpanded: isSupportExpanded,
                children: List.generate(_supportSubTabs.length, (i) {
                  final tab = _supportSubTabs[i];
                  return _NavSubTile(
                    icon: tab.icon,
                    label: tab.label,
                    isActive: currentRoute == AppRouter.support && i == 0,
                    onTap: () {
                      if (currentRoute != AppRouter.support) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRouter.support,
                        );
                      }
                    },
                  );
                }),
              ),

              // ── About ──
              _NavTile(
                icon: Icons.info_outline_rounded,
                label: 'About',
                isActive: currentRoute == AppRouter.about,
                isExpanded: sidebarExpanded,
                tooltip: 'About',
                onTap: () => _navigate(context, AppRouter.about),
              ),

              // ── Admin (only visible to admins) ──
              if (state.isAdmin) ...[
                const SizedBox(height: AppSpacing.xs),
                _NavTile(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin',
                  isActive: currentRoute == AppRouter.admin,
                  isExpanded: sidebarExpanded,
                  tooltip: 'Admin Panel',
                  accentColor: Colors.amberAccent,
                  onTap: () => _navigate(context, AppRouter.admin),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chevron(bool isOpen, bool isActive) {
    return AnimatedRotation(
      turns: isOpen ? 0.25 : 0,
      duration: _kAnimDuration,
      curve: Curves.easeOutCubic,
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: isActive ? AppColors.cyan(0.8) : AppColors.textFaint,
      ),
    );
  }

  void _navigate(BuildContext context, String routeName) {
    if (currentRoute != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  // ── User profile ──────────────────────────────────────────────────────────

  Widget _buildUserProfile(BuildContext context, bool isExpanded) {
    return BlocBuilder<AppShellBloc, AppShellState>(
      buildWhen: (prev, curr) =>
          prev.currentUser != curr.currentUser ||
          prev.currentSubscriptionStatus != curr.currentSubscriptionStatus,
      builder: (context, state) {
        final user = state.currentUser;
        if (user == null) return const SizedBox.shrink();

        final name = user.displayName ?? user.email?.split('@').first ?? 'You';
        final email = user.email ?? '';
        final photoUrl = user.photoURL;
        final initials = name.isNotEmpty
            ? name
                  .trim()
                  .split(' ')
                  .map((w) => w.isNotEmpty ? w[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase()
            : '?';

        final status = state.currentSubscriptionStatus;
        final planTier = status?.tier;
        final chipColor = (planTier?.toLowerCase() == 'trial')
            ? Colors.amberAccent
            : AppColors.accentCyan;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: _HoverContainer(
            onTap: () => _navigate(context, AppRouter.account),
            builder: (isHovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? AppSpacing.sm + 2 : AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.white(isHovered ? 0.06 : 0.03),
                borderRadius: AppShapes.md,
                border: Border.all(
                  color: AppColors.white(isHovered ? 0.1 : 0.05),
                ),
              ),
              child: Row(
                children: [
                  // ── Avatar ──
                  _UserAvatar(
                    photoUrl: photoUrl,
                    initials: initials,
                    chipColor: chipColor,
                  ),

                  // ── Details (only when expanded) ──
                  if (isExpanded) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (planTier != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                OmniChip(
                                  label: planTier.toUpperCase(),
                                  color: chipColor,
                                  fontSize: 7,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: AppTextStyles.labelTiny.copyWith(
                                color: AppColors.textDisabled,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: AppColors.white(isHovered ? 0.4 : 0.15),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _UserAvatar
// ═══════════════════════════════════════════════════════════════════════════════

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final Color chipColor;

  const _UserAvatar({
    required this.photoUrl,
    required this.initials,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            chipColor.withValues(alpha: 0.25),
            chipColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _AvatarInitials(initials: initials, color: chipColor),
              )
            : _AvatarInitials(initials: initials, color: chipColor),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _AvatarInitials
// ═══════════════════════════════════════════════════════════════════════════════

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final Color color;
  const _AvatarInitials({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.label.copyWith(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _HoverContainer — hover-aware tappable wrapper
// ═══════════════════════════════════════════════════════════════════════════════

class _HoverContainer extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  final VoidCallback? onTap;
  const _HoverContainer({required this.builder, this.onTap});

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(_hovered),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _ExpandableSubMenu
// ═══════════════════════════════════════════════════════════════════════════════

class _ExpandableSubMenu extends StatelessWidget {
  final bool isExpanded;
  final List<Widget> children;

  const _ExpandableSubMenu({required this.isExpanded, required this.children});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _kAnimDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm + 4,
                top: 2,
                bottom: AppSpacing.xs,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _NavTile — top-level nav item built with a simple Row layout
// ═══════════════════════════════════════════════════════════════════════════════

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? tooltip;
  /// Override the cyan accent with a custom color (e.g. amberAccent for admin).
  final Color? accentColor;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isExpanded = true,
    this.trailing,
    this.tooltip,
    this.accentColor,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final highlighted = active || _hovered;
    final accent = widget.accentColor ?? AppColors.accentCyan;
    final accentFaint = accent.withValues(alpha: 0.08);
    final accentBorder = accent.withValues(alpha: 0.12);

    // The core tile content
    Widget tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 1.5,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? AppSpacing.sm : 0,
              vertical: AppSpacing.sm - 1,
            ),
            decoration: BoxDecoration(
              color: active
                  ? accentFaint
                  : (_hovered ? AppColors.white(0.04) : AppColors.transparent),
              borderRadius: AppShapes.md,
              border: Border.all(
                color: active ? accentBorder : AppColors.transparent,
              ),
            ),
            child: Row(
              children: [
                // ── Accent bar ──
                AnimatedContainer(
                  duration: _kAnimDuration,
                  width: active ? 3 : 0,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.9),
                        accent.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (active) const SizedBox(width: 4),

                // ── Icon ──
                Expanded(
                  child: Row(
                    children: [
                      // Center the icon in collapsed mode
                      if (!widget.isExpanded) const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: active
                              ? accent.withValues(alpha: 0.12)
                              : (_hovered
                                    ? AppColors.white(0.06)
                                    : AppColors.white(0.03)),
                          borderRadius: AppShapes.sm,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 15,
                          color: active
                              ? accent
                              : (highlighted
                                    ? AppColors.textSecondary
                                    : AppColors.textDisabled),
                        ),
                      ),
                      if (!widget.isExpanded) const Spacer(),

                      // ── Label & Trailing (only when expanded) ──
                      if (widget.isExpanded) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12.5,
                              color: active
                                  ? accent
                                  : (highlighted
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted),
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.trailing != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          widget.trailing!,
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Tooltip when collapsed
    if (!widget.isExpanded && widget.tooltip != null) {
      tile = Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        verticalOffset: 0,
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppShapes.sm,
          border: Border.all(color: AppColors.white(0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black_(0.5),
              blurRadius: 8,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        textStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        child: tile,
      );
    }

    return tile;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _NavSubTile — indented sub-item with vertical indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _NavSubTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavSubTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_NavSubTile> createState() => _NavSubTileState();
}

class _NavSubTileState extends State<_NavSubTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final highlighted = active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.sm - 1,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.teal(0.07)
                : (_hovered ? AppColors.white(0.03) : AppColors.transparent),
            borderRadius: AppShapes.sm,
          ),
          child: Row(
            children: [
              // Vertical indicator pip
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2,
                height: active ? 16 : 12,
                margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accentTeal
                      : (highlighted
                            ? AppColors.white(0.15)
                            : AppColors.white(0.06)),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Icon(
                widget.icon,
                size: 13,
                color: active
                    ? AppColors.accentTeal
                    : (highlighted
                          ? AppColors.textMuted
                          : AppColors.textDisabled),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: active
                        ? AppColors.accentTeal
                        : (highlighted
                              ? AppColors.textSecondary
                              : AppColors.textDisabled),
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
