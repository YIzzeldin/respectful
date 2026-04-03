import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../services/volume_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  CalculationMethodType _selectedMethod = CalculationMethodType.muslimWorldLeague;
  bool _locationGranted = false;
  bool _dndGranted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _step == 0 ? _buildWelcome() : _buildSteps(),
      ),
    );
  }

  Widget _buildWelcome() {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/respectful_icon.png',
              width: 160,
              height: 160,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l.appName,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.appTagline,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),

          // Feature list — lead with masjid detection (main feature)
          _FeatureItem(
            icon: Icons.mosque_rounded,
            title: l.smartMasjidDetection,
            subtitle: l.smartMasjidDesc,
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.schedule_rounded,
            title: l.optionalTimeBased,
            subtitle: l.optionalTimeBasedDesc,
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.tune_rounded,
            title: l.fullyCustomizable,
            subtitle: l.fullyCustomizableDesc,
          ),
          const SizedBox(height: 40),

          // Get Started
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    l.getStarted,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onComplete,
            child: Text(
              l.alreadyHaveSettings,
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Progress
          Row(
            children: [
              _StepDot(active: _step >= 1),
              const SizedBox(width: 8),
              _StepDot(active: _step >= 2),
              const SizedBox(width: 8),
              _StepDot(active: _step >= 3),
            ],
          ),
          const SizedBox(height: 32),

          // Scrollable step content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step == 1) _buildLocationStep(),
                  if (_step == 2) _buildMethodStep(),
                  if (_step == 3) _buildPermissionStep(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Fixed button at bottom
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(_step == 3 ? AppLocalizations.of(context).completeSetup : AppLocalizations.of(context).continueText),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.yourLocation,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l.locationDesc,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _requestLocation,
            icon: Icon(
              _locationGranted ? Icons.check_circle : Icons.my_location,
              color: _locationGranted ? AppColors.success : AppColors.primary,
            ),
            label: Text(_locationGranted ? l.locationGranted : l.grantLocationAccess),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(
                color: _locationGranted ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodStep() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.calculationMethod,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l.chooseCalcMethod,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ...CalculationMethodType.values.map((method) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _selectedMethod == method
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedMethod = method),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMethod == method
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _selectedMethod == method
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            method.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedMethod == method
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildPermissionStep() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.permissions,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l.permissionsDesc,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        _PermissionTile(
          icon: Icons.do_not_disturb_on,
          title: l.dndAccess,
          subtitle: l.dndAccessDesc,
          granted: _dndGranted,
          onRequest: _requestDnd,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.totalSilenceWarning,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    if (_step == 1) return _locationGranted;
    if (_step == 2) return true;
    if (_step == 3) return true; // DND is recommended but not required
    return true;
  }

  Future<void> _nextStep() async {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      // Complete onboarding
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.setCalculationMethod(_selectedMethod);
      await notifier.completeOnboarding();
      widget.onComplete();
    }
  }

  Future<void> _requestLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).pleaseEnableLocation)),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).locationPermDenied)),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationPermPermanentlyDenied)),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await ref.read(settingsProvider.notifier).setLocation(
            position.latitude,
            position.longitude,
          );
      setState(() => _locationGranted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToGetLocation('$e'))),
        );
      }
    }
  }

  Future<void> _requestDnd() async {
    final controller = VolumeController();
    final hasDnd = await controller.hasDndPermission();
    if (!hasDnd) {
      await controller.openDndSettings();
    }
    // Re-check after returning from settings
    final granted = await controller.hasDndPermission();
    setState(() => _dndGranted = granted);
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;

  const _StepDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onRequest,
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
          Icon(icon, color: granted ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onRequest,
              child: Text(AppLocalizations.of(context).grant),
            )
          else
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
