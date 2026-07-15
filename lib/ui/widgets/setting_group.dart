import "package:flutter/material.dart";
import "package:sms_sync/ui/widgets/setting_item.dart";

class SettingGroup extends StatelessWidget {
  final String title;
  final List<SettingItem> children;

  const SettingGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(title),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: .5,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).dividerColor.withAlpha(25),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
