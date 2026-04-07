# Removed Code Snippets

Preserved here for reference in case features are re-introduced.

---

## Overlay Header — Popup Menu (removed 2026-04-07)

**Was in:** `lib/features/translation/presentation/screens/components/translation_header.dart`

**Replaced with:** A direct `IconButton` that navigates straight to `/settings-overlay`.

The popup contained icon-button shortcuts to all major screens (Config, Subscription, Usage, Account, Support, About). These are now reachable via the nav rail inside the settings/dashboard shell.

```dart
// Settings menu with orange badge dot when update is available
ValueListenableBuilder<bool>(
  valueListenable: UpdateNotifier.instance,
  builder: (context, hasUpdate, _) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.settings,
            size: 14,
            color: Colors.pinkAccent,
          ),
          tooltip: 'Menu',
          offset: const Offset(0, 32),
          position: PopupMenuPosition.under,
          color: const Color(0xFF1E1E1E),
          elevation: 12,
          constraints: const BoxConstraints(),
          menuPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Colors.white10),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Config icon
                      Tooltip(
                        message: 'Configuration',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings-overlay');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Icon(Icons.handyman, size: 18, color: Colors.tealAccent),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                      // Subscription icon
                      Tooltip(
                        message: 'Subscription & Quota',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/subscription');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.lightBlueAccent),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                      // Usage icon
                      Tooltip(
                        message: 'Usage Statistics',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/usage');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Icon(Icons.bar_chart_rounded, size: 18, color: Colors.orangeAccent),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                      // Account icon
                      Tooltip(
                        message: 'Account',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/account');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Icon(Icons.manage_accounts_rounded, size: 18, color: Colors.purpleAccent),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                      // Support icon
                      Tooltip(
                        message: 'Support & Feedback',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/support');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Icon(Icons.help_outline_rounded, size: 18, color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                      // About icon — shows update dot if available
                      Tooltip(
                        message: hasUpdate ? 'About — Update Available!' : 'About',
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/about');
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Icon(Icons.info_outline_rounded, size: 18, color: Colors.amberAccent),
                              ),
                              if (hasUpdate)
                                Positioned(
                                  right: 4,
                                  top: 6,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Colors.orangeAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Orange badge dot on the settings gear itself
        if (hasUpdate)
          Positioned(
            right: 6,
            top: 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF121212), width: 1),
              ),
            ),
          ),
      ],
    );
  },
),
```
