import "package:flutter/material.dart";

class StringSettingDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  const StringSettingDialog({
    super.key,
    required this.title,
    required this.initialValue,
  });

  @override
  State<StringSettingDialog> createState() => _StringSettingDialogState();
}

class _StringSettingDialogState extends State<StringSettingDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
