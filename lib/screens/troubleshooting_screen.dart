import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

/// OEM-specific troubleshooting guidance for background service reliability.
class TroubleshootingScreen extends ConsumerWidget {
  const TroubleshootingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dndPerm = ref.watch(dndPermissionProvider);
    final alarmPerm = ref.watch(exactAlarmPermissionProvider);
    final manufacturer = _getManufacturer();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Troubleshooting')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Permission status
          _SectionTitle('Permission Status'),
          const SizedBox(height: 8),
          _PermissionTile(
            icon: Icons.do_not_disturb_on,
            title: 'DND Access',
            granted: dndPerm.valueOrNull ?? false,
            onFix: () async {
              final controller = ref.read(volumeControllerProvider);
              await controller.openDndSettings();
            },
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            icon: Icons.alarm,
            title: 'Exact Alarms',
            granted: alarmPerm.valueOrNull ?? false,
            onFix: () async {
              final controller = ref.read(volumeControllerProvider);
              await controller.openExactAlarmSettings();
            },
          ),
          const SizedBox(height: 24),

          // Battery optimization
          _SectionTitle('Battery Optimization'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For reliable auto-silence, disable battery optimization for Respectful.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Opens battery optimization settings
                      // Note: exact path varies by OEM
                    },
                    icon: const Icon(Icons.battery_saver, size: 18),
                    label: const Text('Open Battery Settings'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OEM-specific guidance
          _SectionTitle('Device-Specific Guide'),
          const SizedBox(height: 8),
          _OemGuide(manufacturer: manufacturer),
          const SizedBox(height: 24),

          // Common issues
          _SectionTitle('Common Issues'),
          const SizedBox(height: 8),
          _FaqTile(
            question: 'Phone doesn\'t silence at prayer time',
            answer: '1. Check that DND Access permission is granted\n'
                '2. Check that Exact Alarms permission is granted\n'
                '3. Disable battery optimization for Respectful\n'
                '4. Make sure Auto-Silence is enabled in Settings',
          ),
          const SizedBox(height: 8),
          _FaqTile(
            question: 'Phone stays silent after prayer',
            answer: 'This can happen if the app was force-stopped during a silence window. '
                'Open the app — it will detect the stale state and restore automatically. '
                'If the issue persists, toggle Auto-Silence off and on in Settings.',
          ),
          const SizedBox(height: 8),
          _FaqTile(
            question: 'Prayer times seem wrong',
            answer: '1. Check your calculation method in Settings\n'
                '2. Tap "Update Location Now" in Settings to refresh your GPS\n'
                '3. Make sure location services are enabled',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getManufacturer() {
    try {
      // Android only — get device manufacturer
      if (Platform.isAndroid) {
        // We can't easily get manufacturer without a plugin,
        // so we'll show generic guidance with OEM-specific tips
        return 'generic';
      }
    } catch (_) {}
    return 'generic';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool granted;
  final VoidCallback onFix;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.granted,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: granted ? AppColors.success : AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          if (granted)
            const Text('Granted', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500))
          else
            TextButton(onPressed: onFix, child: const Text('Fix')),
        ],
      ),
    );
  }
}

class _OemGuide extends StatelessWidget {
  final String manufacturer;
  const _OemGuide({required this.manufacturer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Some phone manufacturers aggressively kill background apps. '
            'Follow the steps for your device brand:',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _OemStep(brand: 'Samsung', steps: 'Settings > Apps > Respectful > Battery > Unrestricted'),
          _OemStep(brand: 'Xiaomi / MIUI', steps: 'Settings > Apps > Manage apps > Respectful > Autostart: ON, Battery saver: No restrictions'),
          _OemStep(brand: 'Huawei / EMUI', steps: 'Settings > Apps > Respectful > Battery > Launch: Manual, all toggles ON'),
          _OemStep(brand: 'OnePlus', steps: 'Settings > Apps > Respectful > Battery > Don\'t optimize'),
          _OemStep(brand: 'Pixel / Stock', steps: 'Settings > Apps > Respectful > Battery > Unrestricted'),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'For more details, visit dontkillmyapp.com',
                  style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OemStep extends StatelessWidget {
  final String brand;
  final String steps;

  const _OemStep({required this.brand, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(brand, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(steps, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.answer,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
