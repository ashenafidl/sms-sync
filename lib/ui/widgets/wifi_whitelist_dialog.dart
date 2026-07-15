import "package:flutter/material.dart";
import "package:sms_sync/services/wifi_whitelist_service.dart";

class WhitelistDialog extends StatefulWidget {
  final WifiWhitelistService service;
  final String currentSsid;

  const WhitelistDialog({
    super.key,
    required this.service,
    required this.currentSsid,
  });

  @override
  State<WhitelistDialog> createState() => WhitelistDialogState();
}

class WhitelistDialogState extends State<WhitelistDialog> {
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
