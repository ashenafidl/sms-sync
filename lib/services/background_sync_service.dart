import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart";
import "package:multicast_dns/multicast_dns.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:telephony/telephony.dart" hide NetworkType;
import "package:workmanager/workmanager.dart";

const String _kLastSyncStatusKey = "last_sync_status";
const Duration _kDiscoveryTimeout = Duration(seconds: 5);
const int _kMinWorkManagerIntervalMinutes = 15;

const String _kTaskPeriodic = "sms_sync_periodic";
const String _kTaskOneOff = "sms_sync_oneoff";

const Duration kForegroundPollInterval = Duration(seconds: 5);

@pragma("vm:entry-point")
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("WorkManager task triggered: $task");

    switch (task) {
      case _kTaskPeriodic:
      case _kTaskOneOff:
        await _runSync();
        break;
      default:
        debugPrint("Unknown task: $task");
    }

    return true;
  });
}

Future<void> _runSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final serviceType =
        prefs.getString("sync_service_type") ?? "_sms-sync._tcp";
    final syncPath = prefs.getString("sync_path") ?? "/";
    final whitelistEnabled = prefs.getBool("wifi_whitelist_enabled") ?? false;
    final allowedSsids =
        prefs.getStringList("wifi_whitelist_allowed") ?? <String>[];

    if (whitelistEnabled && allowedSsids.isEmpty) {
      debugPrint("No whitelisted Wi-Fi networks, skipping sync");
      await _writeStatus(
        prefs,
        "skipped",
        "No whitelisted networks configured",
      );
      return;
    }

    final endpoints = <_ResolvedEndpoint>[];
    await _discoverEndpoints(serviceType, endpoints);

    if (endpoints.isEmpty) {
      debugPrint("No servers found via mDNS for $serviceType");
      await _writeStatus(prefs, "no_server", "No server found on the network");
      return;
    }

    final smsPermission = await Permission.sms.request();
    if (!smsPermission.isGranted) {
      debugPrint("SMS permission not granted");
      await _writeStatus(
        prefs,
        "permission_denied",
        "SMS permission not granted",
      );
      return;
    }

    final telephony = Telephony.instance;
    final messages = await telephony.getInboxSms();
    final jsonPayload = jsonEncode({
      "messages": messages
          .map(
            (m) => {
              "smsId": m.id,
              "address": m.address ?? m.serviceCenterAddress ?? "Unknown",
              "body": m.body ?? "",
              "date": m.date,
            },
          )
          .toList(),
    });

    bool anySucceeded = false;
    String? lastError;

    for (final ep in endpoints) {
      try {
        final path = syncPath.startsWith("/") ? syncPath : "/$syncPath";
        final response = await post(
          Uri.parse("http://${ep.ipAddress}:${ep.port}$path"),
          headers: {"Content-Type": "application/json"},
          body: jsonPayload,
        );

        if (response.statusCode == 200) {
          debugPrint("Background sync OK: ${ep.ipAddress}:${ep.port}");
          anySucceeded = true;
        } else {
          lastError =
              "${ep.ipAddress}:${ep.port} returned ${response.statusCode}";
          debugPrint("Sync failed: $lastError");
        }
      } on SocketException catch (e) {
        lastError = "Connection refused at ${ep.ipAddress}:${ep.port}";
        debugPrint("Sync SocketException: $e");
      } catch (e) {
        lastError = "HTTP error: $e";
        debugPrint("Sync error: $e");
      }
    }

    if (anySucceeded) {
      await _writeStatus(prefs, "success", null);
    } else {
      await _writeStatus(prefs, "failed", lastError ?? "All endpoints failed");
    }
  } catch (e) {
    debugPrint("Background sync exception: $e");
    final prefs = await SharedPreferences.getInstance();
    await _writeStatus(prefs, "error", e.toString());
  }
}

Future<void> _writeStatus(
  SharedPreferences prefs,
  String result,
  String? error,
) async {
  final now = DateTime.now().toIso8601String();
  final map = <String, dynamic>{"timestamp": now, "result": result};
  if (error != null) {
    map["error"] = error;
  }
  final status = jsonEncode(map);
  await prefs.setString(_kLastSyncStatusKey, status);
}

class _ResolvedEndpoint {
  final String hostname;
  final int port;
  final String ipAddress;

  _ResolvedEndpoint({
    required this.hostname,
    required this.port,
    required this.ipAddress,
  });
}

Future<void> _discoverEndpoints(
  String serviceType,
  List<_ResolvedEndpoint> out,
) async {
  Future<RawDatagramSocket> factory(
    dynamic host,
    int port, {
    bool reuseAddress = true,
    bool reusePort = false,
    int ttl = 1,
  }) {
    return RawDatagramSocket.bind(
      host,
      port,
      reuseAddress: true,
      reusePort: false,
      ttl: ttl,
    );
  }

  final mdns = MDnsClient(rawDatagramSocketFactory: factory);
  await mdns.start();

  final ptrStream = mdns.lookup<PtrResourceRecord>(
    ResourceRecordQuery.serverPointer("$serviceType.local"),
  );

  final completer = Completer<void>();
  int pending = 0;

  void tryComplete() {
    if (pending <= 0 && !completer.isCompleted) {
      completer.complete();
    }
  }

  final ptrSub = ptrStream.listen((ptr) {
    final instanceName = ptr.domainName;
    pending++;

    mdns
        .lookup<SrvResourceRecord>(ResourceRecordQuery.service(instanceName))
        .listen((srv) {
          final hostname = srv.target;
          final port = srv.port;
          pending++;

          mdns
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(hostname),
              )
              .listen((a) {
                final ip = a.address.address;
                out.add(
                  _ResolvedEndpoint(
                    hostname: hostname,
                    port: port,
                    ipAddress: ip,
                  ),
                );
              })
              .onDone(() {
                pending--;
                tryComplete();
              });

          mdns
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv6(hostname),
              )
              .listen((aaaa) {
                final ip = aaaa.address.address;
                if (!out.any(
                  (e) => e.hostname == hostname && e.ipAddress == ip,
                )) {
                  out.add(
                    _ResolvedEndpoint(
                      hostname: hostname,
                      port: port,
                      ipAddress: ip,
                    ),
                  );
                }
              })
              .onDone(() {
                pending--;
                tryComplete();
              });
        })
        .onDone(() {
          pending--;
          tryComplete();
        });
  });

  await Future.any([
    completer.future,
    Future<void>.delayed(_kDiscoveryTimeout),
  ]);

  await ptrSub.cancel();
  mdns.stop();
}

class BackgroundSyncService {
  static final BackgroundSyncService instance = BackgroundSyncService._();
  BackgroundSyncService._();

  final Workmanager _workmanager = Workmanager();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _workmanager.initialize(callbackDispatcher);
    _initialized = true;
  }

  Future<void> registerPeriodicSync({required int intervalMinutes}) async {
    final clamped = intervalMinutes < _kMinWorkManagerIntervalMinutes
        ? _kMinWorkManagerIntervalMinutes
        : intervalMinutes;

    await _workmanager.registerPeriodicTask(
      _kTaskPeriodic,
      _kTaskPeriodic,
      frequency: Duration(minutes: clamped),
      constraints: Constraints(networkType: NetworkType.unmetered),
    );

    debugPrint(
      "Registered periodic sync every $clamped minutes "
      "(requested: $intervalMinutes, min: $_kMinWorkManagerIntervalMinutes)",
    );
  }

  Future<void> cancelSync() async {
    await _workmanager.cancelAll();
    debugPrint("Cancelled all WorkManager tasks");
  }

  Future<void> runOneOffSync() async {
    await _workmanager.registerOneOffTask(
      _kTaskOneOff,
      _kTaskOneOff,
      constraints: Constraints(networkType: NetworkType.unmetered),
    );
  }

  /// Run sync directly in the current isolate (no WorkManager scheduling).
  /// Use for manual "Sync Now" when instant feedback is needed.
  Future<void> runSyncDirect() async {
    await _runSync();
  }

  static int get minIntervalMinutes => _kMinWorkManagerIntervalMinutes;
}
