# Privacy Policy — Respectful

**Last updated:** March 2026

## What Respectful Does

Respectful is a prayer times app that automatically silences your phone during prayer times. It calculates prayer times locally on your device and manages your phone's Do Not Disturb settings.

## Data We Collect

**We do not collect, store, or transmit any personal data.**

### Location Data
- Your GPS coordinates are used **only** to calculate accurate prayer times for your area.
- Location data is stored **locally on your device only** — it is never sent to any server.
- Location is fetched once during setup and refreshed when you travel (>10km change detected).
- You can manually refresh your location at any time in Settings.

### Prayer Times
- Prayer times are calculated **entirely on your device** using the open-source Adhan library.
- No prayer time API calls are made. The app works fully offline.

### Phone State
- The app reads your phone's volume and Do Not Disturb state before silencing.
- This state is stored **locally on your device only** to restore your phone after prayer.
- No phone state data is ever transmitted externally.

### Event Log
- The app maintains a local activity log (last 200 events) for debugging purposes.
- This log is stored **on your device only** and is never transmitted.

## Permissions

| Permission | Why It's Needed |
|-----------|----------------|
| Location | Calculate prayer times for your area |
| Do Not Disturb Access | Automatically silence your phone during prayer |
| Exact Alarms | Schedule precise silence/restore at prayer times |
| Boot Completed | Reschedule alarms after device restart |

## Third-Party Services

Respectful does not use any third-party analytics, advertising, or tracking services.

## Data Sharing

We do not share any data with third parties. There is no data to share — everything stays on your device.

## Children's Privacy

Respectful does not knowingly collect information from children under 13.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be reflected in the "Last updated" date above.

## Contact

For questions about this privacy policy, please open an issue at:
https://github.com/YIzzeldin/respectful/issues
