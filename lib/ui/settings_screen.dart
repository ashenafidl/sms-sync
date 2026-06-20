import "package:flutter/material.dart";
import "package:network_info_plus/network_info_plus.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _whitelistService = WifiWhitelistService.instance;
  String? _currentSsid;

  @override
  void initState() {
    super.initState();
    _whitelistService.initialize();
    _loadCurrentSsid();
  }

  Future<void> _loadCurrentSsid() async {
    final ssid = (await NetworkInfo().getWifiName())?.replaceAll('"', "");
    if (mounted) setState(() => _currentSsid = ssid);
  }

  void showWhitelistDialog() {
    if (_currentSsid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected to a Wi-Fi network")),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _WhitelistDialog(
        service: _whitelistService,
        currentSsid: _currentSsid!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListenableBuilder(
        listenable: _whitelistService,
        builder: (context, _) {
          final enabled = _whitelistService.enabled;
          return Column(
            children: [
              ListTile(
                onTap: () => _whitelistService.setEnabled(!enabled),
                title: const Text("Run on specific wifi networks"),
                subtitle: Text(
                  "Only run on selected wifi networks.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: cs.outline),
                ),
                trailing: Checkbox(
                  value: enabled,
                  onChanged: (value) =>
                      _whitelistService.setEnabled(value ?? false),
                ),
              ),
              ListTile(
                onTap: showWhitelistDialog,
                title: const Text("Select WiFi networks"),
                subtitle: Text(
                  "Choose which Wi-Fi networks are allowed to run the sync server.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: cs.outline),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: enabled,
              ),
            ],
          );
        },
      ),
    );
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
