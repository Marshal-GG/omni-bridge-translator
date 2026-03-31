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
//  AppNavigationRail — dashboard sidebar
// ═══════════════════════════════════════════════════════════════════════════════

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

    return Container(
      width: AppSpacing.navRailWidth,
      decoration: BoxDecoration(
        color: AppColors.bgDeepest,
        border: Border(right: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Branding ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Transform.scale(
              scale: 1,
              child: OmniBranding(
                subtitle: 'Dashboard',
                fallbackIcon: Icons.dashboard_rounded,
                logoSize: 36,
                subtitleAsChip: true,
                subtitleChipColor: AppColors.accentCyan,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _divider(),
          const SizedBox(height: AppSpacing.sm),
          _sectionLabel('NAVIGATION'),
          const SizedBox(height: AppSpacing.xs),
          _buildNavLinks(context, isOnSettings),
          const Spacer(),
          _divider(),
          const SizedBox(height: AppSpacing.sm),
          _buildUserProfile(context),
        ],
      ),
    );
  }

  // ── Gradient divider ──────────────────────────────────────────────────────

  static Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.transparent,
              AppColors.white(0.06),
              AppColors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  static Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelTiny.copyWith(
          color: AppColors.textFaint,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  // ── Nav links ─────────────────────────────────────────────────────────────

  Widget _buildNavLinks(BuildContext context, bool isOnSettings) {
    return BlocBuilder<AppShellBloc, AppShellState>(
      buildWhen: (previous, current) =>
          previous.isSettingsExpanded != current.isSettingsExpanded ||
          previous.isSupportExpanded != current.isSupportExpanded,
      builder: (context, state) {
        final isSettingsExpanded = state.isSettingsExpanded;
        final isSupportExpanded = state.isSupportExpanded;

        return Column(
          children: [
            _NavTile(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isActive: isOnSettings,
              trailing: AnimatedRotation(
                turns: isSettingsExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isOnSettings ? AppColors.cyan(0.8) : AppColors.textFaint,
                ),
              ),
              onTap: () {
                context.read<AppShellBloc>().add(const AppShellToggleSettingsExpanded());
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

            _NavTile(
              icon: Icons.workspace_premium_rounded,
              label: 'Subscription',
              isActive: currentRoute == AppRouter.subscription,
              onTap: () => _navigate(context, AppRouter.subscription),
            ),
            _NavTile(
              icon: Icons.insights_rounded,
              label: 'Usage Analytics',
              isActive: currentRoute == AppRouter.usage,
              onTap: () => _navigate(context, AppRouter.usage),
            ),
            _NavTile(
              icon: Icons.forum_rounded,
              label: 'Support',
              isActive: currentRoute == AppRouter.support,
              trailing: AnimatedRotation(
                turns: isSupportExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: currentRoute == AppRouter.support
                      ? AppColors.cyan(0.8)
                      : AppColors.textFaint,
                ),
              ),
              onTap: () {
                context.read<AppShellBloc>().add(const AppShellToggleSupportExpanded());
              },
            ),

            _ExpandableSubMenu(
              isExpanded: isSupportExpanded,
              children: List.generate(_supportSubTabs.length, (i) {
                final tab = _supportSubTabs[i];
                return _NavSubTile(
                  icon: tab.icon,
                  label: tab.label,
                  isActive: currentRoute == AppRouter.support && i == 0, // Mock highlighting 'All Tickets' as default
                  onTap: () {
                    if (currentRoute != AppRouter.support) {
                      Navigator.pushReplacementNamed(context, AppRouter.support);
                    }
                  },
                );
              }),
            ),
            _NavTile(
              icon: Icons.info_outline_rounded,
              label: 'About',
              isActive: currentRoute == AppRouter.about,
              onTap: () => _navigate(context, AppRouter.about),
            ),
          ],
        );
      },
    );
  }

  void _navigate(BuildContext context, String routeName) {
    if (currentRoute != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  // ── User profile ──────────────────────────────────────────────────────────

  Widget _buildUserProfile(BuildContext context) {
    return BlocBuilder<AppShellBloc, AppShellState>(
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
            AppSpacing.sm + 4,
            AppSpacing.sm,
            AppSpacing.sm + 4,
            AppSpacing.md,
          ),
          child: _HoverContainer(
            onTap: () => Navigator.pushNamed(context, AppRouter.account),
            builder: (isHovered) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
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
                  // Avatar
                  Container(
                    width: 34,
                    height: 34,
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
                      border: Border.all(
                        color: chipColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _AvatarInitials(
                                initials: initials,
                                color: chipColor,
                              ),
                            )
                          : _AvatarInitials(
                              initials: initials,
                              color: chipColor,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
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
                                style: AppTextStyles.label,
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
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTextStyles.labelTiny.copyWith(
                              color: AppColors.textDisabled,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 16,
                    color: AppColors.white(isHovered ? 0.4 : 0.15),
                  ),
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
      duration: const Duration(milliseconds: 250),
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
//  _NavTile — top-level nav item
// ═══════════════════════════════════════════════════════════════════════════════

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.trailing,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: 1.5,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.cyan(0.08)
                  : (_hovered ? AppColors.white(0.04) : AppColors.transparent),
              borderRadius: AppShapes.md,
              border: Border.all(
                color: active ? AppColors.cyan(0.12) : AppColors.transparent,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppShapes.md,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // ── Accent bar ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 3 : 0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.cyan(0.9), AppColors.teal(0.4)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            // Icon with tinted bg
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.cyan(0.12)
                                    : (_hovered
                                          ? AppColors.white(0.06)
                                          : AppColors.white(0.03)),
                                borderRadius: AppShapes.sm,
                              ),
                              child: Icon(
                                widget.icon,
                                size: 15,
                                color: active
                                    ? AppColors.accentCyan
                                    : (highlighted
                                          ? AppColors.textSecondary
                                          : AppColors.textDisabled),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(
                              child: Text(
                                widget.label,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12.5,
                                  color: active
                                      ? AppColors.accentCyan
                                      : (highlighted
                                            ? AppColors.textSecondary
                                            : AppColors.textMuted),
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (widget.trailing != null) widget.trailing!,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
