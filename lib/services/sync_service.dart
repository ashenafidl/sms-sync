import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:http/http.dart";
import "package:multicast_dns/multicast_dns.dart";
import "package:network_info_plus/network_info_plus.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:sms_sync/services/sms_service.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";

const Duration kDiscoveryTimeout = Duration(seconds: 5);

class ResolvedEndpoint {
  final String hostname;
  final int port;
  final String ipAddress;
  bool stale;

  ResolvedEndpoint({
    required this.hostname,
    required this.port,
    required this.ipAddress,
    this.stale = false,
  });
}

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  Timer? _syncTimer;
  bool _isRunning = false;
  String _serviceType = "_sms-sync._tcp";
  String _syncPath = "/";
  int _syncIntervalMinutes = 60;

  final List<ResolvedEndpoint> _endpoints = [];

  bool get isRunning => _isRunning;
  String get serviceType => _serviceType;
  String get syncPath => _syncPath;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  String? get error => _error;
  List<ResolvedEndpoint> get discoveredEndpoints =>
      List.unmodifiable(_endpoints);
  bool get hasEndpoints => _endpoints.isNotEmpty;

  final WifiWhitelistService _whitelistService = WifiWhitelistService.instance;
  String? _error;
  String? _currentSsid;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serviceType = prefs.getString("sync_service_type") ?? "_sms-sync._tcp";
    _syncPath = prefs.getString("sync_path") ?? "/";
    _syncIntervalMinutes = prefs.getInt("sync_interval_minutes") ?? 60;
    notifyListeners();
  }

  Future<void> updateSettings({
    String? serviceType,
    String? path,
    int? interval,
  }) async {
    if (serviceType != null) {
      _serviceType = serviceType;
      _endpoints.clear();
    }
    if (path != null) {
      _syncPath = path.isEmpty ? "/" : path;
    }
    if (interval != null) {
      _syncIntervalMinutes = interval;
    }

    final prefs = await SharedPreferences.getInstance();
    if (serviceType != null) {
      await prefs.setString("sync_service_type", serviceType);
    }
    if (path != null) {
      await prefs.setString("sync_path", _syncPath);
    }
    if (interval != null) {
      await prefs.setInt("sync_interval_minutes", interval);
    }

    notifyListeners();
    _startTimer();
  }

  /// Full mDNS resolution chain: PTR → SRV → A/AAAA.
  ///
  /// Populates [_endpoints] with each discovered instance's IP address
  /// and port, caching the result so subsequent sync calls don't re-query.
  Future<void> discoverTargets() async {
    _endpoints.clear();
    _error = null;

    try {
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

      final MDnsClient mdns = MDnsClient(rawDatagramSocketFactory: factory);
      await mdns.start();

      final ptrStream = mdns.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer("$_serviceType.local"),
      );

      final completer = Completer<void>();
      int pendingResolutions = 0;

      void tryComplete() {
        if (pendingResolutions <= 0 && !completer.isCompleted) {
          completer.complete();
        }
      }

      final ptrSub = ptrStream.listen((ptr) {
        // ptr.domainName is the instance name, e.g. "Expense Sync Server._expense-sync._tcp.local"
        final instanceName = ptr.domainName;
        pendingResolutions++;

        mdns
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(instanceName),
            )
            .listen((srv) {
              // srv.target is the hostname (e.g. "myhost.local")
              // srv.port is the service port
              final hostname = srv.target;
              final port = srv.port;
              pendingResolutions++;

              mdns
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(hostname),
                  )
                  .listen((a) {
                    final ip = a.address.address;
                    _endpoints.add(
                      ResolvedEndpoint(
                        hostname: hostname,
                        port: port,
                        ipAddress: ip,
                      ),
                    );
                  })
                  .onDone(() {
                    pendingResolutions--;
                    tryComplete();
                  });

              // Also try IPv6 as fallback
              mdns
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv6(hostname),
                  )
                  .listen((aaaa) {
                    final ip = aaaa.address.address;
                    // Avoid duplicates if the host already has an IPv4 entry
                    if (!_endpoints.any(
                      (e) => e.hostname == hostname && e.ipAddress == ip,
                    )) {
                      _endpoints.add(
                        ResolvedEndpoint(
                          hostname: hostname,
                          port: port,
                          ipAddress: ip,
                        ),
                      );
                    }
                  })
                  .onDone(() {
                    pendingResolutions--;
                    tryComplete();
                  });
            })
            .onDone(() {
              pendingResolutions--;
              tryComplete();
            });
      });

      // Timeout so we don't wait forever if responses are sparse.
      await Future.any([
        completer.future,
        Future<void>.delayed(kDiscoveryTimeout),
      ]);

      await ptrSub.cancel();
      mdns.stop();

      if (_endpoints.isEmpty) {
        _error =
            "mDNS discovery found no server advertising $_serviceType on the current network.";
        debugPrint(_error);
      } else {
        _error = null;
        debugPrint(
          "mDNS discovery resolved ${_endpoints.length} endpoint(s): "
          "${_endpoints.map((e) => "${e.ipAddress}:${e.port}").join(", ")}",
        );
      }

      notifyListeners();
    } catch (e) {
      _error = "mDNS discovery failed: $e";
      debugPrint(_error);
      notifyListeners();
    }
  }

  /// Send SMS data to the discovered endpoints.
  ///
  /// Uses cached IP addresses. If a cached endpoint fails (stale IP),
  /// it's marked stale. If all cached endpoints are stale, discovery is
  /// re-run automatically.
  Future<void> syncNow() async {
    if (_currentSsid == null ||
        !_whitelistService.isNetworkAllowed(_currentSsid!)) {
      debugPrint("Network not allowed, skipping sync");
      return;
    }

    final sms = SmsService();
    String messages;
    try {
      messages = await sms.getMessagesJson();
    } catch (e) {
      _error = "Failed to read SMS messages: $e";
      debugPrint(_error);
      notifyListeners();
      return;
    }

    // If all cached endpoints are stale, re-discover.
    if (_endpoints.isNotEmpty && _endpoints.every((e) => e.stale)) {
      debugPrint("All endpoints are stale, re-running mDNS discovery");
      await discoverTargets();
      if (_endpoints.isEmpty) return;
    }

    bool anySucceeded = false;

    for (final ep in _endpoints) {
      if (ep.stale) continue;

      try {
        final path = _syncPath.startsWith("/") ? _syncPath : "/$_syncPath";
        final response = await post(
          Uri.parse("http://${ep.ipAddress}:${ep.port}$path"),
          headers: {"Content-Type": "application/json"},
          body: messages,
        );

        if (response.statusCode == 200) {
          debugPrint("Sync successful to ${ep.ipAddress}:${ep.port}");
          anySucceeded = true;
          ep.stale = false;
        } else {
          debugPrint(
            "Server at ${ep.ipAddress}:${ep.port} responded with "
            "status ${response.statusCode}: ${response.body}",
          );
        }
      } on SocketException {
        ep.stale = true;
        debugPrint(
          "Connection refused at cached IP ${ep.ipAddress}:${ep.port} "
          "(hostname: ${ep.hostname}) — marking stale",
        );
      } catch (e) {
        debugPrint("HTTP request to ${ep.ipAddress}:${ep.port} failed: $e");
      }
    }

    if (!anySucceeded && _endpoints.isEmpty) {
      _error =
          "mDNS discovery found no server for $_serviceType on the current network. "
          "Make sure the server is running and advertising itself.";
    } else if (!anySucceeded && _endpoints.isNotEmpty) {
      _error =
          "Found ${_endpoints.length} server(s) via mDNS but all HTTP requests failed. "
          "Check that the server is accepting connections and the correct port is used.";
    }

    notifyListeners();
  }

  void _startTimer() {
    _syncTimer?.cancel();
    if (_syncIntervalMinutes > 0) {
      _syncTimer = Timer.periodic(
        Duration(minutes: _syncIntervalMinutes),
        (_) => syncNow(),
      );
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (_isRunning) return;

    try {
      await loadSettings();

      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _error =
            "Location permission is required to read the Wi-Fi address. "
            "Please grant it in Settings.";
        notifyListeners();
        return;
      }

      await _whitelistService.initialize();
      _currentSsid = (await NetworkInfo().getWifiName())?.replaceAll('"', "");

      if (_currentSsid == null) {
        _error = "not_on_wifi";
        notifyListeners();
        return;
      }

      if (!_whitelistService.isNetworkAllowed(_currentSsid!)) {
        _error = "network_not_allowed: $_currentSsid";
        notifyListeners();
        return;
      }

      await discoverTargets();

      _isRunning = true;
      notifyListeners();
      _startTimer();
    } catch (e) {
      _error = e.toString();
      await stop();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
