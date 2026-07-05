import "dart:convert";

import "package:permission_handler/permission_handler.dart";
import "package:telephony/telephony.dart";

class SmsService {
  final Telephony telephony = Telephony.instance;

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<String> getMessagesJson() async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception("sms_permission_denied");
    }

    final messages = await telephony.getInboxSms();
    final list = messages
        .map(
          (m) => {
            "smsId": m.id,
            "address": m.address ?? m.serviceCenterAddress ?? "Unknown",
            "body": m.body ?? "",
            "date": m.date,
          },
        )
        .toList();
    return jsonEncode({"messages": list});
  }
}
