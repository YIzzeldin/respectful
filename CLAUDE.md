# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get                          # Install dependencies
flutter run                              # Debug on connected device
flutter build apk --release              # Release APK
flutter test                             # Run all tests
flutter test test/silence_window_calculator_test.dart  # Single test file
flutter analyze                          # Lint check
dart format lib/ test/                   # Format code
```

Install APK preserving user data (overlay install):
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## What This App Does

Respectful auto-silences Android phones during prayer times and when at a mosque. Fully offline, zero data collection. Android-only (no iOS).

## Architecture Overview

**Flutter (Dart)** handles UI, state management, and business logic. **Kotlin** handles native Android operations (DND control, alarms, geofencing). They communicate via a single MethodChannel (`com.respectful/volume_control`) defined in `MainActivity.kt`.

### State Management: Riverpod

All app state lives in `lib/providers/app_providers.dart`. Key provider chain:

```
settingsProvider (user config)
    → todayPrayerTimesProvider (calculated via adhan library)
    → silenceWindowsProvider (time ranges to silence)
    → autoScheduleProvider (schedules native alarms)

savedMasjidsProvider → autoGeofenceProvider (registers native geofences)

currentMinuteProvider (10s tick) → geoSilencedProvider (polls native geo_silenced flag)
```

Invisible watchers in `SilenceEngineWatcher` widget keep `autoScheduleProvider`, `autoGeofenceProvider`, `gpsCalibrationProvider`, and `geoExitRecoveryProvider` alive.

### Dual Silence State Model

The app tracks two independent silence flags in native SharedPreferences (`respectful_prefs`):
- `is_silenced` — prayer-time based (set by `AlarmReceiver`)
- `geo_silenced` — geofence based (set by `GeofenceReceiver`)

**Phone only restores when BOTH are false.** This allows prayer silence and geo silence to overlap without conflicts.

### Silence Entry/Exit Paths

**Entry paths (3):**
1. Native `AlarmReceiver` fires at prayer time (scheduled via `AlarmManager`)
2. Native `GeofenceReceiver` fires on ENTER/DWELL transition
3. GPS calibration detects missed geofence entry (`gpsCalibrationProvider`)

**Exit paths (4):**
1. Native `AlarmReceiver` fires at prayer end (+ safety alarm 5min later)
2. Native `GeofenceReceiver` fires on EXIT transition
3. Fast exit recovery loop (45s interval via `geoExitRecoveryProvider`) — runs only while geo-silenced, clears stuck silence after 2 consecutive outside-checks
4. Optional `GeoExitTrackingService` — foreground service with 20s GPS polling for even faster exit detection (opt-in via settings)

### Native Kotlin Components

All in `android/app/src/main/kotlin/com/respectful/respectful/`:

- **AlarmReceiver** — Manifest-registered BroadcastReceiver. Fires even if app is killed. Captures phone state before silencing, restores after.
- **GeofenceReceiver** — Handles geofence transitions. Tracks which masjid triggered silence via `active_masjid_geofences` StringSet.
- **GeofenceManager** — Registers circular geofences with configurable radius (default 150m), 30s dwell delay, and 30s notification responsiveness.
- **GeoExitTrackingService** — Optional foreground service for fast exit detection (20s GPS polling while geo-silenced). Coordinated by `GeoExitTrackingCoordinator` which syncs service state from every geo state change point.
- **BootReceiver** — On reboot: restores stale silence, re-registers geofences, re-schedules alarms.
- **VolumeControlService** — Controls DND + ringer mode. Two levels: total silence vs priority-only.
- **AlarmScheduler** — Exact alarms via `setExactAndAllowWhileIdle()`. Uses `setAlarmClock()` as redundancy for restore alarms.

### Key Design Decisions

- **`commit()` not `apply()`** for all native SharedPreferences writes — BroadcastReceivers may die immediately after `onReceive()`.
- **Alarm IDs encode date + prayer index** (`1000 + day*10 + prayer.index`) to avoid collisions between today and tomorrow's Fajr.
- **Hashing to skip redundant rescheduling** — `autoScheduleProvider` hashes silence windows and only reschedules if they actually changed.
- **Tomorrow's Fajr always scheduled** — Ensures overnight transition works (Isha at 9PM → Fajr at 5AM).
- **Jumuah substitution** — On Fridays, Dhuhr config is replaced with Jumuah config (longer silence window).
- **Geofence initial trigger = 0** — Prevents phantom ENTER events during re-registration.
- **GPS recovery is split into two loops** — slow configurable-interval `gpsCalibrationProvider` for missed ENTER repair, fast 45s `geoExitRecoveryProvider` for stuck EXIT repair. Thresholds defined in `GeofenceRecoveryPolicy` with buffer = max(20m, 10% of radius).
- **`GeoExitTrackingCoordinator.sync()`** called from every native code path that changes `geo_silenced` — ensures the foreground tracking service starts/stops consistently.

## Localization

Manual implementation in `lib/l10n/app_localizations.dart`. English + Arabic. No ARB file generation — strings are directly coded with `isArabic` checks.

## Testing

Tests in `test/`. Covers silence window calculation, location service (Haversine), app settings, and geofence recovery policy thresholds. No native Kotlin tests. No integration/E2E tests.
