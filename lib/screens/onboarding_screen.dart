import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Mosque illustration placeholder
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.mosque_rounded,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Respectful',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Auto-silence during prayer times',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),

          // Feature list
          _FeatureItem(
            icon: Icons.volume_off_rounded,
            title: 'Automatic silence during prayer',
            subtitle: 'Your phone goes silent when it\'s time to pray',
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.tune_rounded,
            title: 'Per-prayer customization',
            subtitle: 'Adjust timing and behavior for each prayer',
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.mosque_rounded,
            title: 'Masjid mode for total focus',
            subtitle: 'Complete silence when you\'re at the mosque',
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Get Started',
                    style: TextStyle(
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
            child: const Text(
              'Already have settings? Restore',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
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
              child: Text(_step == 3 ? 'Complete Setup' : 'Continue'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Location',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'We need your location to calculate accurate prayer times for your area.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
            label: Text(_locationGranted ? 'Location granted' : 'Grant location access'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Calculation Method',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the prayer time calculation method used in your region.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permissions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'These permissions are needed for auto-silence to work reliably.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        _PermissionTile(
          icon: Icons.do_not_disturb_on,
          title: 'Do Not Disturb Access',
          subtitle: 'Required to silence your phone automatically',
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
              const Expanded(
                child: Text(
                  'Total silence mode will block ALL sounds including calls and alarms during prayer.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            const SnackBar(content: Text('Please enable location services')),
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
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Please enable in settings.')),
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
          SnackBar(content: Text('Failed to get location: $e')),
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
              child: const Text('Grant'),
            )
          else
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
