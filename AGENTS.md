# Flutter SMS Sync Client - Agent Guide

## Quick Setup

- `flutter pub get` - Install project dependencies

## Core Architecture

- **Entry point**: `lib/main.dart` - Bootstrap + MaterialApp setup
- **Services**: `lib/services/` - Sync, SMS, Wi-Fi whitelist
- **UI**: `lib/ui/` - Home screen (sync control) + Settings screen

## Sync Service (`lib/services/sync_service.dart`)

Uses `multicast_dns` to discover local servers and POST SMS data to them.

### mDNS Resolution Chain (PTR → SRV → A/AAAA)

- **Query PTR** records for the service type (`_sms-sync._tcp.local.`)
- For each PTR result, **query SRV** to get the hostname + port
- For each SRV result, **query A/AAAA** to resolve the hostname to an IP
- Store as `ResolvedEndpoint(hostname, port, ipAddress, stale)` — the HTTP client
  connects via IP, not hostname, because `.local` hostnames can't be resolved
  by the system DNS resolver used by `dart:io`'s `HttpClient`.

### Failure handling

- **`stale` flag**: On `SocketException`, mark the endpoint stale. If all
  endpoints go stale, re-run discovery on the next sync attempt.
- **Distinct errors**: "no server on the network" vs "found server(s) but HTTP
  failed" produce different error messages exposed via `error` getter.

### Service Type

Defined in `kServiceType` constant. Change this to match your server's
registered service type (e.g., `_expense-sync._tcp`).

## Wi-Fi Whitelist (`lib/services/wifi_whitelist_service.dart`)

- Uses `SharedPreferences` to persist allowed SSIDs
- Sync only runs on whitelisted networks
- When disabled, sync runs on any Wi-Fi

## Development Flow

1. `flutter analyze` — linting
2. `flutter test` — unit tests

## Dependencies

- `multicast_dns` — mDNS service discovery
- `http` — POST sync data to discovered endpoints
- `network_info_plus` — current SSID detection
- `telephony` (git: `danbeyene/Telephony`) — SMS inbox access
- `permission_handler` — location + SMS permissions
