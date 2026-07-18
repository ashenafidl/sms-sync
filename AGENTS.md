# Flutter SMS Sync Client - Agent Guide

## Quick Setup

- `flutter pub get` — install dependencies
- `flutter analyze` — linting (strict: see analysis_options.yaml)
- `flutter test` — unit tests (no test/ directory exists yet)

## Core Architecture

- **Entry point**: `lib/main.dart` — `MainApp` (MaterialApp, dark-only theme)
- **Services** (`lib/services/`):
  - `sync_service.dart` — singleton `SyncService` (extends `ChangeNotifier`); UI state holder, delegates sync to `BackgroundSyncService`, manages notification lifecycle
  - `background_sync_service.dart` — singleton `BackgroundSyncService`; wraps WorkManager for periodic/one-off background sync. Contains `callbackDispatcher()` (top-level) and shared sync runner (`_runSync`) that both foreground and background isolate invoke
  - `notification_service.dart` — singleton `NotificationService`; persistent low-importance notification while sync is active
  - `sms_service.dart` — reads SMS inbox via `telephony` package (foreground only; background uses telephony directly in `_runSync`)
  - `wifi_whitelist_service.dart` — singleton `WifiWhitelistService`; persists allowed SSIDs via `SharedPreferences`
  - `secret_generator.dart` — utility for random secret strings
- **UI** (`lib/ui/`):
  - `screens/home_screen.dart` — sync toggle, manual sync button, last-sync status display
  - `screens/settings_screen.dart` — service type, sync path, interval, Wi-Fi whitelist, battery optimization / background reliability
  - `widgets/` — reusable setting item, setting group, dialog widgets
- **Theme** (`lib/theme/app_theme.dart`)

## Background Sync — Key Details

- **WorkManager minimum interval**: Android enforces 15-minute minimum for periodic tasks. The UI clamps the configured interval to this minimum.
- **`callbackDispatcher()`** is a top-level `@pragma("vm:entry-point")` function in `background_sync_service.dart`. It re-initializes `SharedPreferences` and `telephony` in the background isolate — no shared state with the main isolate.
- **Two invocation paths** for sync:
  - `BackgroundSyncService.runSyncDirect()` — runs the shared sync runner in the foreground isolate (instant, for manual "Sync Now").
  - WorkManager periodic/one-off tasks — invoke `callbackDispatcher()` → `_runSync()` in a background isolate (may have scheduling delay).
- **Status persistence**: After each sync run, status (timestamp, result, error) is written to `SharedPreferences` under key `last_sync_status`. `SyncService` polls this while the home screen is visible to reflect background-triggered syncs in the UI.
- **Notification**: `NotificationService` shows a persistent (non-dismissible, low-importance) notification when sync is active. Wired into `SyncService.start()`/`stop()`.

## Sync Service — mDNS Discovery

Uses `multicast_dns` to discover local servers via mDNS (PTR → SRV → A/AAAA chain), then POSTs SMS JSON to each resolved endpoint.

- Connects via IP (not hostname) because `.local` hostnames can't be resolved by `dart:io`'s `HttpClient`.
- On `SocketException`, marks endpoint stale. If all endpoints stale, re-runs discovery automatically.
- Service type configurable via settings (default `_sms-sync._tcp`); stored in `SharedPreferences` under key `sync_service_type`.

## Android Manifest Permissions

- `RECEIVE_BOOT_COMPLETED` — allows WorkManager to re-register tasks after reboot
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — battery optimization exemption prompt
- Standard: `INTERNET`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `READ_SMS`, etc.

## Code Style

Enforced by `analysis_options.yaml` with strict mode. Notable rules:

- **Double quotes** everywhere (`prefer_double_quotes`)
- `prefer_final_locals`, `prefer_final_fields`
- `require_trailing_commas`
- `avoid_print` (use `debugPrint` instead)
- `strict-casts`, `strict-inference`, `strict-raw-types` enabled

## Dependencies

- `multicast_dns` — mDNS service discovery
- `http` — POST sync data to discovered endpoints
- `network_info_plus` — current SSID detection
- `telephony` (git: `danbeyene/Telephony`, pinned ref) — SMS inbox access
- `permission_handler` — location, SMS, and battery optimization permissions
- `shared_preferences` — persist settings, Wi-Fi whitelist, and last sync status
- `path_provider` — file system paths
- `workmanager` — Android/iOS background task scheduling (periodic sync)
- `flutter_local_notifications` — persistent notification while sync is active
