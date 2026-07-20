import "dart:async";

import "package:flutter/foundation.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:telephony/telephony.dart" hide NetworkType;

class SmsWhitelistService extends ChangeNotifier {
  static final SmsWhitelistService instance = SmsWhitelistService._();

  SmsWhitelistService._();

  static const _allowedKey = "sms_whitelist_allowed";
  static const _statusKey = "sms_whitelist_enabled";
  static const _knownSendersKey = "sms_whitelist_known_senders";

  bool _enabled = false;
  List<String> _allowed = [];
  List<String> _knownSenders = [];
  bool _initialized = false;
  Timer? _fetchTimer;

  bool get enabled => _enabled;
  List<String> get allowed => List.unmodifiable(_allowed);
  List<String> get knownSenders => List.unmodifiable(_knownSenders);
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_statusKey) ?? _enabled;
    _allowed = prefs.getStringList(_allowedKey) ?? _allowed;
    _knownSenders = prefs.getStringList(_knownSendersKey) ?? _knownSenders;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusKey, value);
    if (value) {
      await fetchKnownSenders();
      _startPeriodicFetch();
    } else {
      _fetchTimer?.cancel();
    }
    notifyListeners();
  }

  Future<void> fetchKnownSenders() async {
    try {
      final permission = await Permission.sms.request();
      if (!permission.isGranted) {
        debugPrint("SMS permission not granted for fetching senders");
        return;
      }

      final telephony = Telephony.instance;
      final messages = await telephony.getInboxSms();

      final senders = <String>{};
      for (final m in messages) {
        final address = m.address ?? m.serviceCenterAddress;
        if (address != null && address.isNotEmpty) {
          senders.add(address);
        }
      }

      final sorted = senders.toList()..sort();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_knownSendersKey, sorted);

      if (!mounted) return;
      _knownSenders = sorted;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to fetch known SMS senders: $e");
    }
  }

  void _startPeriodicFetch() {
    _fetchTimer?.cancel();
    _fetchTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      fetchKnownSenders();
    });
  }

  Future<void> add(String address) async {
    if (!_allowed.contains(address)) {
      _allowed.add(address);
      await _saveAllowed();
      notifyListeners();
    }
  }

  Future<void> remove(String address) async {
    _allowed.remove(address);
    await _saveAllowed();
    notifyListeners();
  }

  Future<void> _saveAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedKey, _allowed);
  }

  bool isAllowed(String address) => _allowed.contains(address);

  bool get mounted => _initialized;

  @override
  void dispose() {
    _fetchTimer?.cancel();
    super.dispose();
  }
}
