import "package:flutter/material.dart";
import "package:network_info_plus/network_info_plus.dart";
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

  @override
  void initState() {
    super.initState();

    _whitelistService.initialize();
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
        _syncService.updateSettings(interval: interval);
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
                    subtitle: _syncService.syncIntervalMinutes == 1
                        ? "1 minute"
                        : "${_syncService.syncIntervalMinutes} minutes",
                    onTap: () => _showStringSettingDialog(
                      SettingStringKey.syncInterval,
                      "Sync Interval",
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
            ],
          );
        },
      ),
    );
  }
}
