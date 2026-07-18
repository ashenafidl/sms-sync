import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:network_info_plus/network_info_plus.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:sms_sync/services/background_sync_service.dart";
import "package:sms_sync/services/notification_service.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isRunning = false;
  String _serviceType = "_sms-sync._tcp";
  String _syncPath = "/";
  int _syncIntervalMinutes = 60;

  bool get isRunning => _isRunning;
  String get serviceType => _serviceType;
  String get syncPath => _syncPath;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  String? get error => _error;
  String? get lastSyncResult => _lastSyncResult;
  String? get lastSyncTimestamp => _lastSyncTimestamp;
  String? get lastSyncError => _lastSyncError;

  final WifiWhitelistService _whitelistService = WifiWhitelistService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final BackgroundSyncService _bgService = BackgroundSyncService.instance;
  String? _error;
  String? _currentSsid;
  String? _lastSyncResult;
  String? _lastSyncTimestamp;
  String? _lastSyncError;
  String? _lastSyncStatusRaw;
  Timer? _statusPollTimer;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serviceType = prefs.getString("sync_service_type") ?? "_sms-sync._tcp";
    _syncPath = prefs.getString("sync_path") ?? "/";
    _syncIntervalMinutes = prefs.getInt("sync_interval_minutes") ?? 60;
    _readLastSyncStatus(prefs);
    notifyListeners();
  }

  void _readLastSyncStatus(SharedPreferences prefs) {
    final raw = prefs.getString("last_sync_status");
    if (raw == null || raw == _lastSyncStatusRaw) return;

    _lastSyncStatusRaw = raw;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _lastSyncResult = map["result"] as String?;
      _lastSyncTimestamp = map["timestamp"] as String?;
      _lastSyncError = map["error"] as String?;
    } catch (_) {
      _lastSyncResult = null;
      _lastSyncTimestamp = null;
      _lastSyncError = null;
    }
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(kForegroundPollInterval, (_) async {
      final prefs = await SharedPreferences.getInstance();
      final before = _lastSyncStatusRaw;
      _readLastSyncStatus(prefs);
      if (_lastSyncStatusRaw != before) {
        notifyListeners();
      }
    });
  }

  void _stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  Future<void> updateSettings({
    String? serviceType,
    String? path,
    int? interval,
  }) async {
    if (serviceType != null) {
      _serviceType = serviceType;
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
      await prefs.setInt("sync_interval_minutes", _syncIntervalMinutes);
    }

    notifyListeners();

    if (_isRunning) {
      await _bgService.registerPeriodicSync(
        intervalMinutes: _syncIntervalMinutes,
      );
    }
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

      await _bgService.initialize();
      await _bgService.registerPeriodicSync(
        intervalMinutes: _syncIntervalMinutes,
      );

      await _notificationService.initialize();
      await _notificationService.showSyncActive();

      _isRunning = true;
      _error = null;
      notifyListeners();
      _startStatusPolling();
    } catch (e) {
      _error = e.toString();
      await stop();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _stopStatusPolling();
    await _bgService.cancelSync();
    await _notificationService.cancelSyncNotification();
    _isRunning = false;
    _error = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_currentSsid == null ||
        !_whitelistService.isNetworkAllowed(_currentSsid!)) {
      debugPrint("Network not allowed, skipping manual sync");
      return;
    }

    await _bgService.runSyncDirect();

    final prefs = await SharedPreferences.getInstance();
    _readLastSyncStatus(prefs);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
