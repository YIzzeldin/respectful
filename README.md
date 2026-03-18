# Respectful

Prayer times auto-silent Android app — automatically silences your phone during prayer times with smart masjid detection.

## Features (planned)
- Auto-silence during prayer times using INTERRUPTION_FILTER_NONE
- Local prayer time calculation via adhan_dart
- Per-prayer timing configuration
- Manual masjid mode with temporary override
- Smart restore to previous phone state

## Tech Stack
- Flutter (Android-first)
- Riverpod for state management
- Custom Kotlin platform channels for volume/DND control
- Exact alarms via AlarmManager
