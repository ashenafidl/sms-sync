import "package:flutter/material.dart";
import "package:network_info_plus/network_info_plus.dart";
import "package:sms_sync/services/sync_service.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _syncService = SyncService.instance;
  final _whitelistService = WifiWhitelistService.instance;
  late TextEditingController _serviceTypeController;
  late TextEditingController _pathController;
  late TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _serviceTypeController = TextEditingController(
      text: _syncService.serviceType,
    );
    _pathController = TextEditingController(text: _syncService.syncPath);
    _intervalController = TextEditingController(
      text: _syncService.syncIntervalMinutes.toString(),
    );
    _whitelistService.initialize();
  }

  @override
  void dispose() {
    _serviceTypeController.dispose();
    _pathController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final newServiceType = _serviceTypeController.text.trim();
    final newPath = _pathController.text.trim();
    final newInterval = int.tryParse(_intervalController.text) ?? 60;

    _syncService.updateSettings(
      serviceType: newServiceType.isNotEmpty ? newServiceType : null,
      path: newPath.isNotEmpty ? newPath : null,
      interval: newInterval,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListenableBuilder(
        listenable: _syncService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "mDNS Service Type",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serviceTypeController,
                        decoration: const InputDecoration(
                          hintText: "e.g. _expense-sync._tcp",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _saveSettings(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Sync Path",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pathController,
                        decoration: const InputDecoration(
                          hintText: "e.g. /api/sms/sync",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _saveSettings(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Sync Interval (minutes)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: "E.g., 60 (1 hour)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _saveSettings(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text("Run on specific wifi networks"),
                subtitle: const Text(
                  "Only run sync on selected wifi networks.",
                ),
                trailing: Checkbox(
                  value: _whitelistService.enabled,
                  onChanged: (value) =>
                      _whitelistService.setEnabled(value ?? false),
                ),
                onTap: () =>
                    _whitelistService.setEnabled(!_whitelistService.enabled),
              ),
              if (_whitelistService.enabled)
                ListTile(
                  title: const Text("Select WiFi networks"),
                  subtitle: const Text(
                    "Choose which Wi-Fi networks are allowed to run sync.",
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showWhitelistDialog,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showWhitelistDialog() async {
    final ssid = await _getCurrentSsid();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _WhitelistDialog(
        service: _whitelistService,
        currentSsid: ssid ?? "Unknown",
      ),
    );
  }

  Future<String?> _getCurrentSsid() async {
    final networkInfo = NetworkInfo();
    return (await networkInfo.getWifiName())?.replaceAll('"', "");
  }
}

class _WhitelistDialog extends StatefulWidget {
  final WifiWhitelistService service;
  final String currentSsid;

  const _WhitelistDialog({required this.service, required this.currentSsid});

  @override
  State<_WhitelistDialog> createState() => _WhitelistDialogState();
}

class _WhitelistDialogState extends State<_WhitelistDialog> {
  late Set<String> _ssids;

  @override
  void initState() {
    super.initState();
    _ssids = {widget.currentSsid, ...widget.service.ssids};
  }

  List<String> get _sorted {
    final current = widget.currentSsid;
    return [current, ..._ssids.where((e) => e != current)];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("WiFi Networks"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: _sorted.map((ssid) {
            final checked = widget.service.isAllowed(ssid);
            return CheckboxListTile(
              contentPadding: const EdgeInsets.all(0),
              value: checked,
              title: Text(ssid.replaceAll('"', "")),
              subtitle: ssid == widget.currentSsid
                  ? const Text("Current network")
                  : null,
              onChanged: (value) {
                if (value == true) {
                  widget.service.add(ssid);
                } else {
                  widget.service.disallow(ssid);
                }
                _ssids.add(ssid);
                setState(() {});
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
