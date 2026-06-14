import "dart:io";

import "package:flutter/material.dart" hide Router;
import "package:permission_handler/permission_handler.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as shelf_io;
import "package:shelf_router/shelf_router.dart";

const int kServerPort = 8765;
const String kServiceName = "_smssync._tcp";

class ServerService extends ChangeNotifier {
  HttpServer? _server;

  bool _isRunning = false;
  String? _localIp;
  String? _error;

  bool get isRunning => _isRunning;
  String? get localIp => _localIp;
  String? get error => _error;
  String get address => "http://$_localIp:$kServerPort";

  // ── Build the shelf router ──────────────────────────────────────────────────

  Handler _buildHandler() {
    final router = Router();

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

    return const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);
  }

  // ── CORS middleware (permissive for LAN use) ────────────────────────────────

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == "OPTIONS") {
          return Response.ok("", headers: _corsHeaders());
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Map<String, String> _corsHeaders() => {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };

  // ── Start ───────────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) return;
    _error = null;

    try {
      // 1. Request location permission (required for WiFi info on Android 8+)
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _error =
            "Location permission is required to read the Wi-Fi address. Please grant it in Settings.";
        notifyListeners();
        return;
      }

      // 2. Get the local IP
      _localIp = await _getLocalIp();

      if (_localIp == null) throw Exception("Could not get local IP address");

      // 3. Start HTTP server bound to all interfaces
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
