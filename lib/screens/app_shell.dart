import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import 'activity_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ActivityScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isGeoSilenced = ref.watch(geoSilencedProvider).valueOrNull ?? false;
    final activeWindow = ref.watch(activeSilenceWindowProvider);
    final settings = ref.watch(settingsProvider);
    final isSilenced = (settings.timeBasedSilenceEnabled && activeWindow != null) || isGeoSilenced;

    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        isSilenced: isSilenced,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isSilenced;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.isSilenced,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isSilenced
                  ? const Color(0xFF1C1C19).withValues(alpha: 0.6)
                  : AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isSilenced
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.surfaceVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isSilenced ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: l.home,
                  isActive: currentIndex == 0,
                  isSilenced: isSilenced,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: l.activityTab,
                  isActive: currentIndex == 1,
                  isSilenced: isSilenced,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: l.settingsTab,
                  isActive: currentIndex == 2,
                  isSilenced: isSilenced,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isSilenced;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isSilenced,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isSilenced
        ? const Color(0xFF2E7D5B)
        : AppColors.primary;
    final inactiveColor = isSilenced
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isActive ? Colors.white : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
