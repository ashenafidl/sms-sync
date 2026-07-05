import "package:flutter/material.dart";
import "package:sms_sync/services/sync_service.dart";
import "package:sms_sync/ui/settings_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sync = SyncService.instance;

  @override
  void initState() {
    super.initState();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_sync.isRunning) {
      await _sync.stop();
    } else {
      await _sync.start();
    }
  }

  Future<void> _syncNow() async {
    await _sync.syncNow();
  }

  void syncNow() => _syncNow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SMS Sync"),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder: (context) => const SettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _sync,
        builder: (context, _) {
          return Padding(
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
                          _sync.isRunning
                              ? Icons.sync_outlined
                              : Icons.sync_disabled_outlined,
                          key: ValueKey(_sync.isRunning),
                          size: 64,
                          color: _sync.isRunning
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sync.isRunning ? "Sync Running" : "Sync Stopped",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _sync.isRunning
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Error banner ──────────────────────────────────────────────
                if (_sync.error != null)
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
                                _sync.error!,
                                style: TextStyle(color: cs.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Sync instructions ────────────────────────────────────────
                Card(
                  margin: const EdgeInsets.all(0),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Discovered Servers:",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_sync.hasEndpoints)
                          ..._sync.discoveredEndpoints.map(
                            (ep) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    ep.stale
                                        ? Icons.cloud_off_rounded
                                        : Icons.cloud_done_rounded,
                                    size: 18,
                                    color: ep.stale ? cs.error : cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${ep.ipAddress}:${ep.port}",
                                      style: const TextStyle(
                                        fontFamily: "monospace",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Text(
                            "No servers discovered yet. "
                            "Start the sync to begin mDNS discovery.",
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
                    _sync.isRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outlined,
                  ),
                  label: Text(_sync.isRunning ? "Stop Sync" : "Start Sync"),
                  style: _sync.isRunning
                      ? FilledButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Manual sync button ───────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: _syncNow,
                  icon: Icon(Icons.sync, color: cs.primary),
                  label: Text("Sync Now", style: TextStyle(color: cs.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
