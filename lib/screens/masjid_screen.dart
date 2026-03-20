import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/theme.dart';
import '../models/saved_masjid.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';
import 'map_picker_screen.dart';

class MasjidScreen extends ConsumerWidget {
  const MasjidScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masjids = ref.watch(savedMasjidsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Masjids'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => _addCurrentLocation(context, ref),
            tooltip: 'Save current location',
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()),
              );
            },
            tooltip: 'Add from map',
          ),
        ],
      ),
      body: masjids.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, masjids),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No masjids saved',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you\'re at a masjid, tap the button below to save its location for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addCurrentLocation(context, ref),
              icon: const Icon(Icons.my_location),
              label: const Text('Save Current Location'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                );
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Pick from Map'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<SavedMasjid> masjids) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: masjids.length + 2, // +1 for bg location banner, +1 for add button
      itemBuilder: (context, index) {
        // Background location permission banner
        if (index == 0) {
          return FutureBuilder<bool>(
            future: ref.read(volumeControllerProvider).hasBackgroundLocationPermission(),
            builder: (context, snapshot) {
              final granted = snapshot.data ?? false;
              if (granted) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Grant "Allow all the time" location for auto-detection when you enter a masjid.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ph.Permission.locationAlways.request();
                        // Trigger rebuild
                        ref.invalidate(autoGeofenceProvider);
                      },
                      child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
          );
        }

        final masjidIndex = index - 1; // Offset for banner
        if (masjidIndex == masjids.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _addCurrentLocation(context, ref),
              icon: const Icon(Icons.add_location_alt, size: 18),
              label: const Text('Save Current Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          );
        }

        final masjid = masjids[masjidIndex];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Show options for this masjid
                _showMasjidOptions(context, ref, masjid);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mosque_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            masjid.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${masjid.latitude.toStringAsFixed(4)}, ${masjid.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.radar, size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addCurrentLocation(BuildContext context, WidgetRef ref) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!context.mounted) return;

      // Auto-detect address for pre-filling the name
      String suggestedName = 'Masjid ${ref.read(savedMasjidsProvider).length + 1}';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // Build a readable name from the address components
          final parts = <String>[
            if (p.name != null && p.name!.isNotEmpty) p.name!,
            if (p.street != null && p.street!.isNotEmpty && p.street != p.name) p.street!,
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
          ];
          if (parts.isNotEmpty) {
            suggestedName = parts.take(2).join(', ');
          }
        }
      } catch (_) {
        // Geocoding failed — use default name
      }

      if (!context.mounted) return;

      // Ask for name — pre-filled with auto-detected address
      final name = await _askMasjidName(context, suggestedName);
      if (name == null || name.isEmpty) return;

      final masjid = SavedMasjid(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
        savedAt: DateTime.now(),
      );

      await ref.read(savedMasjidsProvider.notifier).add(masjid);
      await ref.read(eventLogServiceProvider).log(
            EventType.info,
            'Saved masjid: $name (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
          );

      // If user is at this masjid right now (saving current location), silence immediately
      // Android geofences won't fire ENTER if already inside when registered
      final settings = ref.read(settingsProvider);
      if (settings.geofenceSilenceEnabled) {
        final locationService = ref.read(locationServiceProvider);
        final isNearby = !locationService.hasMovedSignificantly(
          storedLat: masjid.latitude,
          storedLng: masjid.longitude,
          currentLat: position.latitude,
          currentLng: position.longitude,
          thresholdKm: 0.2,
        );
        if (isNearby) {
          await ref.read(volumeControllerProvider).applySilenceForGeo();
          ref.invalidate(geoSilencedProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "$name" — phone silenced'),
                backgroundColor: AppColors.primary,
              ),
            );
            // Go back to home so user sees the dark skin
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$name"'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<String?> _askMasjidName(BuildContext context, [String? defaultName]) async {
    final controller = TextEditingController(text: defaultName);
    if (defaultName != null) {
      controller.selection = TextSelection(baseOffset: 0, extentOffset: defaultName.length);
    }
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this masjid'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Masjid Al-Noor',
            border: const OutlineInputBorder(),
            helperText: defaultName != null ? 'Auto-detected from location' : null,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMasjidOptions(BuildContext context, WidgetRef ref, SavedMasjid masjid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              masjid.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${masjid.latitude.toStringAsFixed(4)}, ${masjid.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.radar, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '200m geofence active',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(context);
                _renameMasjid(context, ref, masjid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(context);
                _deleteMasjid(context, ref, masjid);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameMasjid(BuildContext context, WidgetRef ref, SavedMasjid masjid) async {
    final controller = TextEditingController(text: masjid.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename masjid'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(savedMasjidsProvider.notifier).rename(masjid.id, newName);
    }
  }

  void _deleteMasjid(BuildContext context, WidgetRef ref, SavedMasjid masjid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete masjid?'),
        content: Text('Remove "${masjid.name}" from your saved locations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(savedMasjidsProvider.notifier).remove(masjid.id);

      // If no masjids left, clear geo silence (won't break active prayer)
      final remaining = ref.read(savedMasjidsProvider);
      if (remaining.isEmpty) {
        final controller = ref.read(volumeControllerProvider);
        await controller.clearGeoSilence();
        ref.invalidate(geoSilencedProvider);
      }
    }
  }
}
