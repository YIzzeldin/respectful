# iOS Extension Plan for Respectful

## Context

Respectful is an Android-only Flutter app that auto-silences phones during Islamic prayer times and when entering registered masjid locations. iOS does not expose any API to control ringer volume, silent mode, or Do Not Disturb — so the iOS version uses a **notification-based approach** instead of direct phone control.

## Core Design Principle

**Force a conscious decision.** The user cannot passively ignore their ringer at a masjid — they must either silence their phone or actively choose not to.

---

## Architecture Decisions

| Decision | Resolution |
|---|---|
| Silence strategy | Notification-based (iOS has no ringer/DND API) |
| Notification intensity | Detect silent switch position: **off → nag loop**, **on → gentle** |
| Prayer times | Single gentle notification per prayer, no nag |
| Masjid geofence | Nag every 2 min until acknowledged or EXIT |
| Background execution | Scheduled local notifications + `CLLocationManager` region monitoring |
| Code sharing | Single Flutter project — add `ios/` directory |
| Platform channel | Same `VolumeController` interface. Android silences phone; iOS fires notifications |
| Geofence limit | Hard cap at 20 masjids (iOS `CLLocationManager` limit) |
| App Store approach | Submit with Time Sensitive + silent switch detection; adapt if rejected |
| Onboarding | Two-stage location permission (When In Use → Always on first masjid save) |
| UI differences | `Platform.isIOS` inline checks; iOS-specific onboarding flow |

---

## Notification Behavior Matrix

| Trigger | Silent switch ON (muted) | Silent switch OFF (ringer active) |
|---|---|---|
| **Prayer time** | No notification (already silent) | Single gentle notification: "Dhuhr in 5 minutes — your ringer is on" |
| **Masjid geofence ENTER** | Gentle notification: "You're at Al-Noor Masjid" | **Time Sensitive nag loop**: "Your ringer is on at Al-Noor Masjid" with [I've Silenced] button. Repeats every 2 min. |
| **Masjid geofence EXIT** | Nothing | Cancel all pending nag notifications |

### Nag Loop Details
- On geofence ENTER with ringer active: schedule 3–4 Time Sensitive notifications, 2 minutes apart
- Each notification has one action button: **[I've Silenced]**
- Tapping "I've Silenced" cancels remaining scheduled notifications
- Swiping away without tapping → next notification fires in 2 minutes
- All cancelled automatically on geofence EXIT
- Budget: ~4 nag notifications per masjid visit, well within iOS 64-notification limit

---

## Implementation Phases

### Phase 1: iOS Project Setup
- Run `flutter create --platforms=ios .` to generate `ios/` directory
- Configure `Info.plist`:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `UIBackgroundModes`: `location`
  - Time Sensitive notification entitlement
- Set minimum deployment target (iOS 15+ for Time Sensitive notifications)
- Configure signing, bundle ID (`com.respectful.respectful`)

### Phase 2: Swift Platform Channel Handler
Create `ios/Runner/RespectfulPlugin.swift` implementing the same method channel (`com.respectful.respectful/volume`) with iOS-specific behavior:

| Method call from Dart | Android (Kotlin) | iOS (Swift) |
|---|---|---|
| `applySilence` | Sets ringer mode + DND | Checks silent switch → fires gentle or nag notification |
| `restoreState` | Restores volume/ringer/DND | Cancels pending nag notifications |
| `captureCurrentState` | Reads ringer/volume/DND | Reads silent switch state |
| `hasDndPermission` | Checks DND policy access | Returns notification authorization status |
| `checkSilentSwitch` | N/A (not needed) | Returns silent switch position (new iOS-only method) |

### Phase 3: Silent Switch Detection
Implement silent switch detection in Swift:
- Use `AVAudioSession` to detect mute state
- Listen for system volume change notifications via `CFNotificationCenter`
- Expose via platform channel as `checkSilentSwitch() → bool`
- **Fallback if Apple rejects**: Remove detection, always send persistent notification at masjid entry

### Phase 4: Notification System
Implement in Swift using `UNUserNotificationCenter`:

#### Prayer Time Notifications
- Dart pre-calculates all prayer times (already does this via `PrayerCalculator`)
- Schedule 5 local notifications per day with prayer-specific offsets
- Reschedule daily (triggered by app open or background region event)
- Content: "Dhuhr in 5 minutes — your ringer is on"
- Category: regular (not Time Sensitive)
- Only scheduled if silent switch is OFF at scheduling time; re-evaluated on each reschedule

#### Masjid Geofence Notifications
- Triggered by `CLLocationManager` region entry callback
- If silent switch OFF: schedule 3–4 Time Sensitive notifications, 2 min apart
- If silent switch ON: single gentle notification
- Notification action: "I've Silenced" → cancels remaining pending
- All cancelled on region EXIT

### Phase 5: Geofence Management (iOS)
Implement in Swift using `CLLocationManager`:
- `CLCircularRegion` for each saved masjid (200m radius, matching Android)
- Register on masjid save, remove on masjid delete
- Hard cap enforcement: reject save if 20 regions already registered
- Handle `didEnterRegion` → check silent switch → fire appropriate notification
- Handle `didExitRegion` → cancel nag notifications
- Re-register all geofences on app launch (iOS can purge them)

### Phase 6: iOS Onboarding Flow
New `onboarding_ios.dart` (or conditional sections in existing onboarding):

**Step 1: Notification Permission**
- Request `UNUserNotificationCenter` authorization (alert, sound, badge)
- Explain: "Respectful will remind you to silence your phone during prayer times and at masjids"

**Step 2: Location Permission (When In Use)**
- Request `CLLocationManager.requestWhenInUseAuthorization()`
- Explain: "Used to detect when you arrive at a saved masjid"

**Step 3 (deferred to first masjid save): Always Location**
- Show explanation screen: "To detect masjid arrival when the app is closed, Respectful needs 'Always' location access"
- Request `requestAlwaysAuthorization()`
- Handle the case where user selects "Keep When In Use" — masjid geofencing won't work, show warning

### Phase 7: UI Platform Adjustments
Inline `Platform.isIOS` checks in existing screens:

- **Settings screen**: Hide "Silence Level" toggle (total vs. priority) — not applicable on iOS
- **Masjid screen**: Show "X/20 masjids" counter on iOS
- **Troubleshooting screen**: Hide OEM-specific guides, replace with iOS-specific tips (e.g., "Make sure 'Always' location is enabled in Settings > Respectful")
- **Home screen**: Adjust silence status indicator — on iOS, show "Reminder active" instead of "Phone silenced"
- **Onboarding**: Route to iOS flow on `Platform.isIOS`

### Phase 8: App Store Submission Prep
- **Fallback builds**: Prepare feature flags to disable Time Sensitive and silent switch detection if Apple rejects
- **Privacy**: Update privacy nutrition labels (location: "App Functionality", notifications)
- **App Store description**: Emphasize notification-based reminders, not auto-silence
- **Screenshots**: iOS-specific (onboarding, notification examples)
- **Review notes**: Explain Time Sensitive justification (social etiquette in places of worship)

---

## Files to Create (iOS Native)

```
ios/
├── Runner/
│   ├── AppDelegate.swift          (modify: register notification categories, location delegate)
│   ├── RespectfulPlugin.swift     (new: platform channel handler)
│   ├── NotificationManager.swift  (new: schedule/cancel local notifications)
│   ├── SilentSwitchDetector.swift (new: AVAudioSession-based mute detection)
│   └── GeofenceHandler.swift      (new: CLLocationManager region monitoring)
```

## Files to Modify (Dart)

```
lib/
├── screens/
│   ├── onboarding_screen.dart     (add iOS permission flow)
│   ├── settings_screen.dart       (hide silence level on iOS)
│   ├── masjid_screen.dart         (add 20-cap indicator on iOS)
│   ├── troubleshooting_screen.dart (iOS-specific tips)
│   └── home_screen.dart           (adjust status text on iOS)
├── services/
│   └── volume_controller.dart     (add checkSilentSwitch method)
└── main.dart                      (no changes expected)
```

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Apple rejects Time Sensitive entitlement | Medium | Nag notifications downgraded to regular (won't break Focus) | Fallback to regular notifications — nag loop still works |
| Apple rejects silent switch detection | Low | Can't distinguish gentle vs. persistent | Always send persistent notification at masjid — slightly annoying for diligent users |
| User denies "Always" location | Medium | Geofencing won't work | Show clear warning; masjid feature disabled, prayer notifications still work |
| iOS throttles rapid local notifications | Low | Nag loop delayed | 2-min interval is conservative; Apple throttles sub-minute bursts |
| User hits 20-masjid limit | Low | Can't add more | Clear UI message; suggest removing unused masjids |

---

## Out of Scope
- Apple Watch companion app
- iOS Shortcuts integration
- Guided Focus automation setup (revisit if notification approach proves insufficient)
- Widget / Live Activity for prayer times (future enhancement)
