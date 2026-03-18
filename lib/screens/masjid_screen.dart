import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/theme.dart';
import '../models/saved_masjid.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';

class MasjidScreen extends ConsumerWidget {
  const MasjidScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masjids = ref.watch(savedMasjidsProvider);
    final masjidMode = ref.watch(masjidModeProvider);

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
        ],
      ),
      body: masjids.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, masjids, masjidMode),
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
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<SavedMasjid> masjids, MasjidModeState masjidMode) {
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
                // Activate masjid mode for this location
                ref.read(masjidModeProvider.notifier).activate();
                Navigator.pop(context);
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textTertiary),
                      onSelected: (action) {
                        if (action == 'rename') {
                          _renameMasjid(context, ref, masjid);
                        } else if (action == 'delete') {
                          _deleteMasjid(context, ref, masjid);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
            EventType.masjidModeOn,
            'Saved masjid: $name (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
          );

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
    }
  }
}
