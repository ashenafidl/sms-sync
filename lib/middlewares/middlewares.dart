import "package:shelf/shelf.dart";

Map<String, String> _corsHeaders() => {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Middleware corsMiddleware() {
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

Middleware authMiddleware(String? secret) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Let /ping and OPTIONS preflight through without a secret
      if (request.url.path == "ping" || request.method == "OPTIONS") {
        return innerHandler(request);
      }

      final provided = request.headers["x-sync-secret"];

      if (provided == null || provided != secret) {
        return Response(
          401,
          body: '{"error":"unauthorized"}',
          headers: {"Content-Type": "application/json"},
        );
      }

      return innerHandler(request);
    };
  };
}
