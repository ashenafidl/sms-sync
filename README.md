# SMS Sync

SMS Sync is a Flutter app for Android that discovers a local sync server over mDNS and forwards SMS metadata over Wi-Fi. It supports background sync scheduling, Wi-Fi network whitelisting, location permission handling, and persistent status notifications.

## Features

- Background SMS sync using Android WorkManager
- Local mDNS discovery
- Wi-Fi SSID whitelist protection
- Manual sync and sync status display
- Persistent low-priority foreground notification while sync is active
- Custom sync service path and interval settings

## Architecture

- `lib/main.dart` — app entrypoint, launches `HomeScreen` with dark theme
- `lib/services/sync_service.dart` — app state manager, foreground sync control, settings persistence
- `lib/services/background_sync_service.dart` — background task registration and sync runner
- `lib/services/notification_service.dart` — foreground sync notification handling
- `lib/services/wifi_whitelist_service.dart` — SSID whitelist persistence and validation
- `lib/ui/screens/home_screen.dart` — primary status/controls UI
- `lib/ui/screens/settings_screen.dart` — sync configuration and whitelist management
- `lib/theme/app_theme.dart` — app styling

## Requirements

- Android device or emulator with SMS and location permissions
- Wi-Fi access to the same local network as the sync server
- `READ_SMS`, `ACCESS_FINE_LOCATION`, and network permissions granted

## Getting Started

### Install dependencies

```bash
flutter pub get
```

### Run on Android

```bash
flutter run
```

### Build release APK

```bash
flutter build apk --release
```

## Configuration

The app stores the following settings in `SharedPreferences`:

- `sync_service_type` — mDNS service type (default `_sms-sync._tcp`)
- `sync_path` — HTTP path used when posting SMS sync data
- `sync_interval_minutes` — periodic sync interval in minutes

## Permission Notes

The app requests location permission to read the current Wi-Fi SSID. It also requires SMS permission to access message data and WorkManager support for background scheduling.

> The sync service uses WorkManager and foreground notifications to keep background sync active.

## Dependencies

- `flutter_local_notifications` — foreground notification support
- `http` — HTTP client for POST sync requests
- `multicast_dns` — local service discovery
- `network_info_plus` — current Wi-Fi SSID lookup
- `path_provider` — optional file system access support
- `permission_handler` — runtime permission requests
- `shared_preferences` — settings persistence
- `telephony` — SMS inbox access
- `workmanager` — periodic background task scheduling

## Notes

This project is intended for Android, where SMS access and WorkManager are available. It is not designed as a general-purpose cross-platform Flutter app.
