import "package:flutter/material.dart";
import "package:network_info_plus/network_info_plus.dart";
import "package:permission_handler/permission_handler.dart";
import "package:sms_sync/services/background_sync_service.dart";
import "package:sms_sync/services/sync_service.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";
import "package:sms_sync/ui/widgets/setting_group.dart";
import "package:sms_sync/ui/widgets/setting_item.dart";
import "package:sms_sync/ui/widgets/string_setting_dialog.dart";
import "package:sms_sync/ui/widgets/wifi_whitelist_dialog.dart";

enum SettingStringKey { serviceType, syncPath, syncInterval }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _syncService = SyncService.instance;
  final _whitelistService = WifiWhitelistService.instance;

  bool _batteryOptimizationGranted = false;

  @override
  void initState() {
    super.initState();
    _whitelistService.initialize();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() {
      _batteryOptimizationGranted = status.isGranted;
    });
  }

  Future<void> _showBatteryExplanationAndRequest() async {
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Battery Optimization"),
        content: const Text(
          "SMS Sync needs to run in the background to keep your messages "
          "backed up. Android's battery optimization may stop the sync "
          "service when the app is closed.\n\n"
          "Granting this exemption lets SMS Sync run reliably in the "
          "background. You can revoke it anytime in Android Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    final result = await Permission.ignoreBatteryOptimizations.request();
    if (!mounted) return;

    setState(() {
      _batteryOptimizationGranted = result.isGranted;
    });

    if (!result.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Battery optimization exemption not granted. "
            "Background sync may be unreliable.",
          ),
        ),
      );
    }
  }

  Future<void> _showWhitelistDialog() async {
    final ssid = await _getCurrentSsid();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => WhitelistDialog(
        service: _whitelistService,
        currentSsid: ssid ?? "Unknown",
      ),
    );
  }

  Future<String?> _getCurrentSsid() async {
    final networkInfo = NetworkInfo();
    return (await networkInfo.getWifiName())?.replaceAll('"', "");
  }

  Future<void> _showStringSettingDialog(
    SettingStringKey key,
    String title,
    String initialValue,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) =>
          StringSettingDialog(title: title, initialValue: initialValue),
    );

    if (value == null || value.isEmpty) return;

    switch (key) {
      case SettingStringKey.serviceType:
        _syncService.updateSettings(serviceType: value);
        break;
      case SettingStringKey.syncInterval:
        final interval = int.tryParse(value) ?? 60;
        final clamped = interval < BackgroundSyncService.minIntervalMinutes
            ? BackgroundSyncService.minIntervalMinutes
            : interval;
        _syncService.updateSettings(interval: clamped);
        break;
      case SettingStringKey.syncPath:
        _syncService.updateSettings(path: value);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListenableBuilder(
        listenable: Listenable.merge([_syncService, _whitelistService]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SettingGroup(
                title: "mDNS Service",
                children: [
                  SettingItem(
                    icon: Icons.link,
                    title: "Service URL",
                    subtitle: _syncService.serviceType,
                    onTap: () => _showStringSettingDialog(
                      SettingStringKey.serviceType,
                      "Service URL",
                      _syncService.serviceType,
                    ),
                  ),
                  SettingItem(
                    icon: Icons.link,
                    title: "Service Path",
                    subtitle: _syncService.syncPath,
                    onTap: () => _showStringSettingDialog(
                      SettingStringKey.syncPath,
                      "Service Path",
                      _syncService.syncPath,
                    ),
                  ),
                  SettingItem(
                    icon: Icons.timer,
                    title: "Sync Interval",
                    subtitle:
                        "${_syncService.syncIntervalMinutes} minutes "
                        "(min ${BackgroundSyncService.minIntervalMinutes})",
                    onTap: () => _showStringSettingDialog(
                      SettingStringKey.syncInterval,
                      "Sync Interval (min ${BackgroundSyncService.minIntervalMinutes})",
                      _syncService.syncIntervalMinutes.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingGroup(
                title: "WiFi",
                children: [
                  SettingItem(
                    icon: Icons.wifi_lock,
                    title: "Run on specific wifi networks",
                    subtitle: "Only run sync on selected wifi networks.",
                    trailing: Checkbox(
                      value: _whitelistService.enabled,
                      onChanged: (value) =>
                          _whitelistService.setEnabled(value ?? false),
                    ),
                    onTap: () => _whitelistService.setEnabled(
                      !_whitelistService.enabled,
                    ),
                  ),
                  SettingItem(
                    icon: Icons.wifi,
                    title: "Select WiFi networks",
                    subtitle:
                        "Choose which Wi-Fi networks are allowed to run sync.",
                    onTap: _showWhitelistDialog,
                    enabled: _whitelistService.enabled,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingGroup(
                title: "Background Reliability",
                children: [
                  SettingItem(
                    icon: Icons.battery_saver,
                    title: "Battery Optimization",
                    subtitle: _batteryOptimizationGranted
                        ? "Exempted — sync runs reliably in background"
                        : "Not exempted — sync may be stopped by system",
                    trailing: Icon(
                      _batteryOptimizationGranted
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: _batteryOptimizationGranted
                          ? Colors.green
                          : Colors.orange,
                    ),
                    onTap: _batteryOptimizationGranted
                        ? null
                        : _showBatteryExplanationAndRequest,
                  ),
                  const SettingItem(
                    icon: Icons.restart_alt,
                    title: "Start on Boot",
                    subtitle: "Sync restarts automatically after device reboot",
                    trailing: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    onTap: null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
