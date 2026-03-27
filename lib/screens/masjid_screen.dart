import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_masjid.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';
import 'map_picker_screen.dart';

class MasjidScreen extends ConsumerWidget {
  const MasjidScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final masjids = ref.watch(savedMasjidsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.myMasjids),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => _addCurrentLocation(context, ref),
            tooltip: l.saveCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()),
              );
            },
            tooltip: l.addFromMap,
          ),
        ],
      ),
      body: masjids.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, masjids),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              l.noMasjidsSaved,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.noMasjidsDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addCurrentLocation(context, ref),
              icon: const Icon(Icons.my_location),
              label: Text(l.saveCurrentLocation),
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
              label: Text(l.pickFromMap),
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
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).grantBgLocation,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ph.Permission.locationAlways.request();
                        // Trigger rebuild
                        ref.invalidate(autoGeofenceProvider);
                      },
                      child: Text(AppLocalizations.of(context).grant, style: const TextStyle(fontWeight: FontWeight.w600)),
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
              label: Text(AppLocalizations.of(context).saveCurrentLocation),
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
      final settings = ref.read(settingsProvider);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).pleaseEnableLocation)),
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

      // Check if there's already a saved masjid within the configured radius.
      final existing = ref.read(savedMasjidsProvider);
      final locationService = ref.read(locationServiceProvider);
      final nearbyMasjid = existing.cast<SavedMasjid?>().firstWhere(
        (m) => !locationService.hasMovedSignificantly(
          storedLat: m!.latitude,
          storedLng: m.longitude,
          currentLat: position.latitude,
          currentLng: position.longitude,
          thresholdKm: settings.masjidRadiusKm,
        ),
        orElse: () => null,
      );
      if (nearbyMasjid != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).alreadySavedNearby(nearbyMasjid.name)),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

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
            EventType.masjidAdded,
            'Saved masjid: $name (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
          );

      // Save current location = we ARE here. No GPS check needed.
      // Silence immediately and attach this masjid ID to the active set.
      final alreadySilenced = await ref.read(volumeControllerProvider).isGeoSilenced();
      if (settings.geofenceSilenceEnabled && !alreadySilenced) {
        await ref.read(volumeControllerProvider).applySilenceForGeo(masjidId: masjid.id);
        final _ = await ref.refresh(geoSilencedProvider.future);

        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).phoneSilencedSaved(name)),
                backgroundColor: AppColors.primary,
              ),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).saved(name)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToGetLocation('$e'))),
        );
      }
    }
  }

  Future<String?> _askMasjidName(BuildContext context, [String? defaultName]) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: defaultName);
    if (defaultName != null) {
      controller.selection = TextSelection(baseOffset: 0, extentOffset: defaultName.length);
    }
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.nameThisMasjid),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Masjid Al-Noor',
            border: const OutlineInputBorder(),
            helperText: defaultName != null ? l.autoDetectedFromLocation : null,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  void _showMasjidOptions(BuildContext context, WidgetRef ref, SavedMasjid masjid) {
    final settings = ref.read(settingsProvider);
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
                  AppLocalizations.of(context)
                      .geofenceActiveWithRadius(settings.masjidRadiusMeters),
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(AppLocalizations.of(context).rename),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(context);
                _renameMasjid(context, ref, masjid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: Text(AppLocalizations.of(context).delete, style: const TextStyle(color: AppColors.error)),
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

  /// Retries GPS until successful, then compares against remaining masjids.
  /// Shows the user feedback on each retry.

  void _renameMasjid(BuildContext context, WidgetRef ref, SavedMasjid masjid) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: masjid.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.renameMasjid),
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
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(savedMasjidsProvider.notifier).rename(masjid.id, newName);
    }
  }

  void _deleteMasjid(BuildContext context, WidgetRef ref, SavedMasjid masjid) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteMasjid),
        content: Text(l.deleteMasjidConfirm(masjid.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final controller = ref.read(volumeControllerProvider);
      final eventLog = ref.read(eventLogServiceProvider);

      // Remove from saved list first
      await ref.read(savedMasjidsProvider.notifier).remove(masjid.id);

      // Ask native to clear geo silence for this specific masjid.
      // Native checks if this masjid was in the active set:
      //   - "not_silenced": phone wasn't geo-silenced → no action
      //   - "not_at_deleted": silenced but by a different masjid → no change
      //   - "still_at_other": was at deleted but also at another → stay silent
      //   - "restored": was at deleted, no others → phone restored
      final result = await controller.clearGeoSilenceForMasjid(masjid.id);

      await eventLog.log(
        result == 'restored' ? EventType.restored : EventType.masjidDeleted,
        'Deleted masjid: ${masjid.name} ($result)',
      );

      // Force UI refresh
      final _ = await ref.refresh(geoSilencedProvider.future);
      ref.invalidate(activeMasjidGeofencesProvider);
    }
  }
}
