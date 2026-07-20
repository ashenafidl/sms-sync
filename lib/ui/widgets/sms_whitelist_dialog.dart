import "package:flutter/material.dart";
import "package:sms_sync/services/sms_whitelist_service.dart";

class SmsWhitelistDialog extends StatefulWidget {
  final SmsWhitelistService service;

  const SmsWhitelistDialog({super.key, required this.service});

  @override
  State<SmsWhitelistDialog> createState() => _SmsWhitelistDialogState();
}

class _SmsWhitelistDialogState extends State<SmsWhitelistDialog> {
  late Future<void> _fetchFuture;

  @override
  void initState() {
    super.initState();
    _fetchFuture = widget.service.fetchKnownSenders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Sender Addresses"),
      content: FutureBuilder(
        future: _fetchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: double.maxFinite,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (widget.service.knownSenders.isEmpty) {
            return const SizedBox(
              width: double.maxFinite,
              height: 150,
              child: Center(child: Text("No SMS messages found in inbox")),
            );
          }
          return SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView(
              children: widget.service.knownSenders.map((address) {
                final checked = widget.service.isAllowed(address);
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.all(0),
                  value: checked,
                  title: Text(address),
                  onChanged: (value) {
                    if (value == true) {
                      widget.service.add(address);
                    } else {
                      widget.service.remove(address);
                    }
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
