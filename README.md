# Respectful

Auto-silence your phone during prayer times. Simple, beautiful, reliable.

## Features

- **Auto-silence during prayer** — phone goes silent at prayer time, restores after
- **Local prayer calculation** — works fully offline using the Adhan library, supports 12 calculation methods
- **Per-prayer timing** — customize before/during/after silence for each prayer independently
- **Masjid mode** — one-tap total silence when you're at the mosque, with auto-timeout
- **Travel detection** — prayer times update automatically when you travel >10km
- **Total or Priority silence** — choose to block everything, or allow alarms and starred contacts
- **Activity log** — track every silence/restore event for confidence and debugging
- **OEM troubleshooting** — device-specific guides for Samsung, Xiaomi, Huawei, OnePlus

## How It Works

1. **Onboarding**: Grant location + DND permission, select calculation method
2. **Prayer times**: Calculated locally from your GPS coordinates
3. **Silence windows**: Computed per-prayer with configurable before/during/after buffers
4. **Exact alarms**: Android AlarmManager schedules silence/restore at precise times
5. **Safety restore**: Redundant alarm via `setAlarmClock()` prevents phone stuck silent
6. **Boot recovery**: Alarms reschedule automatically after device restart

## Tech Stack

- **Flutter** (Android-first)
- **Riverpod** for reactive state management
- **Adhan** library for offline prayer time calculation
- **Custom Kotlin platform channels** for volume/DND control
- **AlarmManager** with BroadcastReceivers for background scheduling

## Privacy

Respectful collects **zero data**. Everything stays on your device. No analytics, no tracking, no API calls. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md).

## Building

```bash
flutter pub get
flutter run
```

Requires Android 8.0+ (API 26).

## Architecture

```
lib/
  core/           — theme, colors
  models/         — prayer day, timing config, silence window, suppression state
  providers/      — Riverpod providers (settings, prayer times, auto-scheduling)
  screens/        — home, settings, activity, onboarding, troubleshooting
  services/       — prayer calculator, silence scheduler, volume controller, event log
  widgets/        — prayer card, countdown banner, masjid mode button

android/.../kotlin/
  VolumeControlService.kt   — AudioManager + DND control
  AlarmScheduler.kt         — Exact alarm scheduling
  AlarmReceiver.kt          — Silence/restore on alarm fire
  BootReceiver.kt           — Recovery after reboot
  TimezoneReceiver.kt       — Recalculation on timezone change
```
