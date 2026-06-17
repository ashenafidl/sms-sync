import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as shelf_io;
import "package:shelf_router/shelf_router.dart";
import "package:shelf_static/shelf_static.dart";
import "package:sms_sync/middlewares/middlewares.dart";
import "package:sms_sync/services/secret_generator.dart";
import "package:sms_sync/services/sms_service.dart";

const int kServerPort = 8765;
const String kServiceName = "_smssync._tcp";

class ServerService extends ChangeNotifier {
  HttpServer? _server;

  bool _isRunning = false;
  String? _localIp;
  String? _error;
  String? _secret;
  String? _webRootPath;

  bool get isRunning => _isRunning;
  String? get localIp => _localIp;
  String? get error => _error;
  String? get secret => _secret;
  String get address => "http://$_localIp:$kServerPort";

  // ── Build the shelf router ──────────────────────────────────────────────────

  Handler _buildHandler() {
    final router = Router();
    final sms = SmsService();

    router.get("/messages", (Request req) async {
      try {
        final json = await sms.getMessagesJson();
        return Response.ok(json, headers: {"Content-Type": "application/json"});
      } catch (e) {
        return Response.internalServerError(
          body: '{"error":"${e.toString()}"}',
          headers: {"Content-Type": "application/json"},
        );
      }
    });

    // /ping - health check endpoint
    router.get(
      "/ping",
      (Request req) => Response.ok(
        '{"status":"ok","service":"sms-sync"}',
        headers: {"Content-Type": "application/json"},
      ),
    );

    // 404 fallback
    router.all("/<ignored|.*>", (Request request) {
      return Response.notFound(
        '{"error":"not found"}',
        headers: {"Content-Type": "application/json"},
      );
    });

    final staticHandler = createStaticHandler(
      _webRootPath!,
      defaultDocument: "index.html",
      listDirectories: false,
    );

    final cascade = Cascade().add(router.call).add(staticHandler);

    return const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsMiddleware())
        .addMiddleware(authMiddleware(_secret))
        .addHandler(cascade.handler);
  }

  Future<String> _prepareWebRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final webDir = Directory("${docsDir.path}/web");
    if (!await webDir.exists()) {
      await webDir.create(recursive: true);
    }

    final indexFile = File("${webDir.path}/index.html");
    final htmlBytes = await rootBundle.load("assets/web/index.html");
    await indexFile.writeAsBytes(htmlBytes.buffer.asUint8List());

    final cssFile = File("${webDir.path}/index.css");
    final cssBytes = await rootBundle.load("assets/web/index.css");
    await cssFile.writeAsBytes(cssBytes.buffer.asUint8List());

    return webDir.path;
  }

  // ── Start ───────────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) return;
    _error = null;

    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _error =
            "Location permission is required to read the Wi-Fi address. Please grant it in Settings.";
        notifyListeners();
        return;
      }

      _localIp = await _getLocalIp();

      if (_localIp == null) throw Exception("Could not get local IP address");

      _secret = kDebugMode ? "00000000" : generateSecret();
      _webRootPath = await _prepareWebRoot();

      _server = await shelf_io.serve(
        _buildHandler(),
        InternetAddress.anyIPv4,
        kServerPort,
      );
      debugPrint("Server started on $_localIp:$kServerPort");

      _isRunning = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      await stop(); // clean up partial state
      notifyListeners();
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prefer wlan (WiFi) interface
      for (final interface in interfaces) {
        final isWifi =
            interface.name.startsWith("wlan") ||
            interface.name.startsWith("en") ||
            interface.name.startsWith("ap"); // hotspot interface

        if (isWifi) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }

      // Fallback: return first non-loopback IPv4 address found
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }

      return null;
    } catch (e) {
      debugPrint("Failed to get local IP: $e");
      return null;
    }
  }

  // ── Stop ────────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
