import "package:flutter_local_notifications/flutter_local_notifications.dart";

const int kSyncNotificationId = 77001;
const String kSyncChannelId = "sms_sync_active";
const String kSyncChannelName = "SMS Sync Active";
const String kSyncChannelDesc = "Persistent notification while sync is running";

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      "@mipmap/ic_launcher",
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          kSyncChannelId,
          kSyncChannelName,
          description: kSyncChannelDesc,
          importance: Importance.low,
          enableVibration: false,
          playSound: false,
        ),
      );
      await android.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<void> showSyncActive() async {
    await _plugin.show(
      id: kSyncNotificationId,
      title: "SMS Sync active",
      body: "Periodically syncing SMS messages in background.",
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kSyncChannelId,
          kSyncChannelName,
          channelDescription: kSyncChannelDesc,
          ongoing: true,
          importance: Importance.low,
          priority: Priority.low,
          icon: "@mipmap/ic_launcher",
        ),
      ),
    );
  }

  Future<void> cancelSyncNotification() async {
    await _plugin.cancel(id: kSyncNotificationId);
  }
}
