import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

class WifiWhitelistService extends ChangeNotifier {
  static final WifiWhitelistService instance = WifiWhitelistService._();

  WifiWhitelistService._();

  static const _key = "wifi_whitelist";
  static const _allowedKey = "wifi_whitelist_allowed";
  static const _statusKey = "wifi_whitelist_enabled";

  bool _enabled = false;
  List<String> _ssids = [];
  List<String> _allowed = [];
  bool _initialized = false;

  bool get enabled => _enabled;
  List<String> get ssids => List.unmodifiable(_ssids);
  bool get initialized => _initialized;

  bool isAllowed(String ssid) => _allowed.contains(ssid);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_statusKey) ?? false;
    _ssids = prefs.getStringList(_key) ?? [];
    _allowed = prefs.getStringList(_allowedKey) ?? _ssids;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusKey, value);
    notifyListeners();
  }

  Future<void> add(String ssid) async {
    if (!_ssids.contains(ssid)) _ssids.add(ssid);
    if (!_allowed.contains(ssid)) _allowed.add(ssid);
    await _persist();
    notifyListeners();
  }

  Future<void> disallow(String ssid) async {
    _allowed.remove(ssid);
    await _persist();
    notifyListeners();
  }

  bool isNetworkAllowed(String ssid) {
    if (!_enabled) return true;
    return _allowed.contains(ssid);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ssids);
    await prefs.setStringList(_allowedKey, _allowed);
  }
}
