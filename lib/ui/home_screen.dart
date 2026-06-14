import "package:flutter/material.dart";
import "package:sms_sync/services/server_service.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _server = ServerService();

  @override
  void initState() {
    super.initState();
    _server.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_server.isRunning) {
      await _server.stop();
    } else {
      await _server.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final running = _server.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text("SMS Sync")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: .max,
          children: [
            const Spacer(),

            // Status Indicator
            Center(
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      running
                          ? Icons.sync_outlined
                          : Icons.sync_disabled_outlined,
                      key: ValueKey(running),
                      size: 64,
                      color: running ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    running ? "Server Running" : "Server Stopped",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: running ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Error banner ──────────────────────────────────────────────
            if (_server.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _server.error!,
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const Spacer(),

            // ── Connection instructions ───────────────────────────────────
            Card(
              margin: const EdgeInsets.all(0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How to connect:",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _Step(
                      number: "1",
                      text: "Connect devices to the same Wi-Fi network",
                    ),
                    const _Step(
                      number: "2",
                      text: "Open a browser on the other device",
                    ),
                    const _Step(
                      number: "3",
                      text: "Enter the address shown below",
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      width: double.infinity,
                      child: Text(
                        running ? _server.address : "Start the server first",
                        style: const TextStyle(fontFamily: "monospace"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Start / Stop button ───────────────────────────────────────
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(
                running
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outlined,
              ),
              label: Text(running ? "Stop Server" : "Start Server"),
              style: running
                  ? FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
