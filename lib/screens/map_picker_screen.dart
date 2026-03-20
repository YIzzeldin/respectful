import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_masjid.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';
import '../services/gps_retry_service.dart';

/// Map picker screen — tap to place a pin, save as a masjid location.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String? _addressLabel;
  bool _isLoading = false;
  bool _locationLoaded = false;
  List<SavedMasjid> _existingMasjids = [];

  @override
  void initState() {
    super.initState();
    _existingMasjids = ref.read(savedMasjidsProvider);
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final loc = await _getCurrentLocation();
    if (mounted && !_locationLoaded) {
      _locationLoaded = true;
      _mapController.move(loc, 16);
    }
  }

  Future<void> _onTap(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _addressLabel = null;
    });

    // Reverse geocode the tapped location
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.name != null && p.name!.isNotEmpty) p.name!,
          if (p.street != null && p.street!.isNotEmpty && p.street != p.name) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
        ];
        setState(() {
          _addressLabel = parts.isNotEmpty ? parts.take(2).join(', ') : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) return;

    setState(() => _isLoading = true);

    // Check for nearby duplicate
    final existing = ref.read(savedMasjidsProvider);
    final locationService = ref.read(locationServiceProvider);
    final nearbyMasjid = existing.cast<SavedMasjid?>().firstWhere(
      (m) => !locationService.hasMovedSignificantly(
        storedLat: m!.latitude,
        storedLng: m.longitude,
        currentLat: _selectedLocation!.latitude,
        currentLng: _selectedLocation!.longitude,
        thresholdKm: 0.2,
      ),
      orElse: () => null,
    );
    if (nearbyMasjid != null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).alreadySavedNearby(nearbyMasjid.name)),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final suggestedName = _addressLabel ??
        'Masjid ${ref.read(savedMasjidsProvider).length + 1}';

    final name = await _askName(suggestedName);
    if (name == null || name.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final masjid = SavedMasjid(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      savedAt: DateTime.now(),
    );

    await ref.read(savedMasjidsProvider.notifier).add(masjid);
    await ref.read(eventLogServiceProvider).log(
          EventType.info,
          'Saved masjid from map: $name',
        );

    // Only check if NOT already silenced
    final settings = ref.read(settingsProvider);
    final alreadySilenced = ref.read(geoSilencedProvider).valueOrNull ?? false;
    if (settings.geofenceSilenceEnabled && !alreadySilenced && mounted) {
      final position = await GpsRetryService.getPositionWithRetry(context: context);
      if (position != null) {
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
          if (mounted) {
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
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).saved(name)),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<String?> _askName(String defaultName) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: defaultName);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: defaultName.length);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.nameThisMasjid),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Masjid Al-Noor',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
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

  Future<LatLng> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Fallback to settings location or Makkah
      final settings = ref.read(settingsProvider);
      if (settings.hasLocation) {
        return LatLng(settings.latitude!, settings.longitude!);
      }
      return const LatLng(21.4225, 39.8262); // Makkah
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.addFromMap),
        backgroundColor: AppColors.background,
      ),
      body: FutureBuilder<LatLng>(
        future: _getCurrentLocation(),
        builder: (context, snapshot) {
          final center = snapshot.data ?? const LatLng(21.4225, 39.8262);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  onTap: (_, point) => _onTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.respectful.respectful',
                  ),
                  // Current location blue dot + existing masjid markers
                  MarkerLayer(
                    markers: [
                      // Blue dot for current location
                      if (snapshot.data != null)
                        Marker(
                          point: snapshot.data!,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ..._existingMasjids.map((m) => Marker(
                            point: LatLng(m.latitude, m.longitude),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.mosque_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          )),
                      // Selected new location
                      if (_selectedLocation != null)
                        Marker(
                          point: _selectedLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.error,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                  // Show 200m radius circle for selected location
                  if (_selectedLocation != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _selectedLocation!,
                          radius: 200,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderColor: AppColors.primary.withValues(alpha: 0.3),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                ],
              ),

              // Instruction banner at top
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedLocation == null
                              ? l.tapOnMap
                              : _addressLabel ?? l.locationSelected,
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedLocation == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: _selectedLocation == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save button at bottom
              if (_selectedLocation != null)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveLocation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isLoading ? l.saving : l.saveThisLocation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

              // My location FAB
              Positioned(
                bottom: _selectedLocation != null ? 90 : 24,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () async {
                    final loc = await _getCurrentLocation();
                    _mapController.move(loc, 16);
                  },
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.my_location, color: AppColors.primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
